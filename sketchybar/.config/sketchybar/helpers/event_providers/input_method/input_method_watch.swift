import Carbon
import Darwin
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
let commandTimeout: TimeInterval = 1.0
let fcitxQueue = DispatchQueue(label: "com.fuzhuoqun.input_method_watch.fcitx")
var fcitxQueryInFlight = false
var fcitxQueryPending = false

func waitForProcess(_ task: Process, timeout: TimeInterval) -> Bool {
    let finished = DispatchSemaphore(value: 0)
    task.terminationHandler = { _ in finished.signal() }

    guard finished.wait(timeout: .now() + timeout) == .timedOut else {
        task.terminationHandler = nil
        return true
    }

    if task.isRunning {
        task.terminate()
    }
    if finished.wait(timeout: .now() + 0.2) == .timedOut,
       task.isRunning {
        kill(task.processIdentifier, SIGKILL)
    }
    task.terminationHandler = nil
    return false
}

func currentInputSourceID() -> String {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
        return ""
    }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
}

func configureSocketTimeout(_ fd: Int32) {
    var timeout = timeval(tv_sec: 0, tv_usec: 300_000)
    withUnsafePointer(to: &timeout) { pointer in
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, pointer, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, pointer, socklen_t(MemoryLayout<timeval>.size))
    }
}

func connectUnixSocket(path: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    configureSocketTimeout(fd)

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
    guard path.utf8.count < maxPathLength else {
        Darwin.close(fd)
        return nil
    }
    withUnsafeMutablePointer(to: &address.sun_path) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { pathPointer in
            path.withCString { cString in
                _ = strncpy(pathPointer, cString, maxPathLength - 1)
            }
        }
    }
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.connect(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard result == 0 else {
        Darwin.close(fd)
        return nil
    }
    return fd
}

func connectTCPSocket(port: String) -> Int32? {
    guard let parsedPort = UInt16(port) else { return nil }
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    configureSocketTimeout(fd)

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = parsedPort.bigEndian
    guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else {
        Darwin.close(fd)
        return nil
    }
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.connect(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        Darwin.close(fd)
        return nil
    }
    return fd
}

func writeAll(fd: Int32, data: Data) -> Bool {
    data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return false }
        var written = 0
        while written < data.count {
            let result = Darwin.write(fd, base.advanced(by: written), data.count - written)
            if result < 0 && errno == EINTR { continue }
            if result <= 0 { return false }
            written += result
        }
        return true
    }
}

func readResponse(fd: Int32) -> Data? {
    var result = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while result.count < 65_536 {
        let count = chunk.withUnsafeMutableBytes { buffer in
            Darwin.read(fd, buffer.baseAddress, buffer.count)
        }
        if count > 0 {
            result.append(contentsOf: chunk[0..<count])
        } else if count == 0 {
            return result
        } else if errno != EINTR {
            return nil
        }
    }
    return result
}

func currentFcitxMode() -> String {
    let fd = beastEndpoint.communication == "TCP"
        ? connectTCPSocket(port: beastEndpoint.tcpPort)
        : connectUnixSocket(path: beastEndpoint.udsPath)
    guard let fd else { return "" }
    defer { Darwin.close(fd) }

    let host = beastEndpoint.communication == "TCP" ? "127.0.0.1" : "fcitx"
    let request = "POST /remote/ HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
    guard writeAll(fd: fd, data: Data(request.utf8)),
          let response = readResponse(fd: fd),
          let output = String(data: response, encoding: .utf8),
          let bodyRange = output.range(of: "\r\n\r\n") else {
        return ""
    }
    return String(output[bodyRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
}

func publishInputMethodChange(inputSourceID: String, fcitxMode: String) {
    let isFcitx = inputSourceID.hasPrefix(fcitx5SourcePrefix)
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
    guard (try? task.run()) != nil else { return }
    // The watcher must not wait for SketchyBar; a slow reload should not delay
    // input-source notifications on the main run loop.
    DispatchQueue.global().async {
        _ = waitForProcess(task, timeout: commandTimeout)
    }
}

func refreshFcitxMode(inputSourceID: String) {
    fcitxQueue.async {
        if fcitxQueryInFlight {
            fcitxQueryPending = true
            return
        }
        fcitxQueryInFlight = true
        let mode = currentFcitxMode()
        let rerun = fcitxQueryPending
        fcitxQueryPending = false
        fcitxQueryInFlight = false
        DispatchQueue.main.async {
            guard currentSourceID == inputSourceID,
                  currentSourceID.hasPrefix(fcitx5SourcePrefix) else { return }
            publishInputMethodChange(inputSourceID: inputSourceID, fcitxMode: mode)
            if rerun {
                refreshFcitxMode(inputSourceID: inputSourceID)
            }
        }
    }
}

func refreshInputSource() {
    currentSourceID = currentInputSourceID()
    if currentSourceID.hasPrefix(fcitx5SourcePrefix) {
        refreshFcitxMode(inputSourceID: currentSourceID)
    } else {
        publishInputMethodChange(inputSourceID: currentSourceID, fcitxMode: "")
    }
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
    refreshFcitxMode(inputSourceID: currentSourceID)
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
