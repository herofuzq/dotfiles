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

func firstExecutable(_ paths: [String]) -> String? {
    for path in paths where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }
    return nil
}

let fcitxRemotePath = firstExecutable([
    "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote",
    "/opt/homebrew/bin/fcitx5-remote",
    "/usr/local/bin/fcitx5-remote",
])

func currentInputSourceID() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
        return ""
    }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
}

func currentFcitxMode() -> String {
    guard let fcitxRemotePath else { return "" }
    let task = Process()
    task.launchPath = fcitxRemotePath
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

func triggerInputMethodChange() {
    let inputSourceID = currentInputSourceID()
    let isFcitx = inputSourceID == "org.fcitx.inputmethod.Fcitx5.zhHans"
    let task = Process()
    task.launchPath = sketchybarPath
    task.arguments = [
        "--trigger", "input_method_change",
        "IM_ID=\(inputSourceID)",
        "FCITX5_ACTIVE=\(isFcitx ? "1" : "0")",
        "FCITX5_MODE=\(isFcitx ? currentFcitxMode() : "")",
    ]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
}

let center = DistributedNotificationCenter.default()
let observer = center.addObserver(
    forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
    object: nil, queue: .main
) { _ in
    triggerInputMethodChange()
}

triggerInputMethodChange()

// Graceful shutdown on SIGTERM (launchd stop)
signal(SIGTERM, SIG_IGN)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler { exit(0) }
sigtermSource.resume()

RunLoop.main.run()
