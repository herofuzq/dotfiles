import Carbon
import Foundation

/// 循环等待 sketchybar 就绪，避免 launchd 无限重启
func waitSketchybar() -> String {
    let knownPaths = ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"]
    while true {
        for p in knownPaths where FileManager.default.isExecutableFile(atPath: p) { return p }
        let proc = Process()
        proc.launchPath = "/bin/sh"
        proc.arguments = ["-c", "which sketchybar"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        if let result = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty {
            return result
        }
        fputs("input_method_watch: sketchybar not found, retrying in 5s\n", stderr)
        sleep(5)
    }
}
let sketchybarPath = waitSketchybar()
let fcitx5SourcePrefix = "org.fcitx.inputmethod.Fcitx5."
let fcitxPollInterval: TimeInterval = 0.5
let sourceFallbackInterval: TimeInterval = 5.0
var lastSignature = ""
var currentSourceID = ""

func firstExecutable(_ paths: [String]) -> String? {
    for path in paths where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }
    return nil
}

let curlPath = firstExecutable(["/usr/bin/curl", "/opt/homebrew/bin/curl", "/usr/local/bin/curl"])

struct BeastEndpoint {
    let communication: String
    let udsPath: String
    let tcpPort: String
}

func configValue(_ key: String, in contents: String) -> String? {
    for line in contents.split(separator: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if parts.count == 2 && parts[0] == key {
            return parts[1]
        }
    }
    return nil
}

func loadBeastEndpoint() -> BeastEndpoint {
    let configPath = NSHomeDirectory() + "/.config/fcitx5/conf/beast.conf"
    let contents = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
    return BeastEndpoint(
        communication: configValue("Communication", in: contents) ?? "UDS",
        udsPath: configValue("Path", in: contents) ?? "/tmp/fcitx5.sock",
        tcpPort: configValue("Port", in: contents) ?? "32489"
    )
}

let beastEndpoint = loadBeastEndpoint()

func currentInputSourceID() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
        return ""
    }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
}

func currentFcitxMode() -> String {
    guard let curlPath else { return "" }
    let task = Process()
    task.launchPath = curlPath
    if beastEndpoint.communication == "TCP" {
        task.arguments = ["-s", "-X", "POST", "http://127.0.0.1:\(beastEndpoint.tcpPort)/remote/"]
    } else {
        task.arguments = ["-s", "--unix-socket", beastEndpoint.udsPath, "-X", "POST", "http://fcitx/remote/"]
    }
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    guard (try? task.run()) != nil else { return "" }
    task.waitUntilExit()
    guard task.terminationStatus == 0,
          let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
        return ""
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func triggerInputMethodChange(inputSourceID: String) {
    let isFcitx = inputSourceID.hasPrefix(fcitx5SourcePrefix)
    let fcitxMode = isFcitx ? currentFcitxMode() : ""
    let signature = "\(inputSourceID)|\(fcitxMode)"
    guard signature != lastSignature else { return }
    lastSignature = signature

    let task = Process()
    task.launchPath = sketchybarPath
    task.arguments = [
        "--trigger", "input_method_change",
        "IM_ID=\(inputSourceID)",
        "FCITX5_ACTIVE=\(isFcitx ? "1" : "0")",
        "FCITX5_MODE=\(fcitxMode)",
    ]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
}

func refreshInputSource() {
    currentSourceID = currentInputSourceID()
    triggerInputMethodChange(inputSourceID: currentSourceID)
}

let center = DistributedNotificationCenter.default()
let observer = center.addObserver(
    forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
    object: nil, queue: .main
) { _ in
    refreshInputSource()
}

refreshInputSource()

Timer.scheduledTimer(withTimeInterval: fcitxPollInterval, repeats: true) { _ in
    guard currentSourceID.hasPrefix(fcitx5SourcePrefix) else { return }
    triggerInputMethodChange(inputSourceID: currentSourceID)
}

Timer.scheduledTimer(withTimeInterval: sourceFallbackInterval, repeats: true) { _ in
    refreshInputSource()
}

// Graceful shutdown on SIGTERM (launchd stop)
signal(SIGTERM, SIG_IGN)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler { exit(0) }
sigtermSource.resume()

RunLoop.main.run()
