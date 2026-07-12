import Foundation
import Darwin

// Bridge AeroSpace's event stream into SketchyBar triggers.
//
// Responsibilities stay deliberately small:
// - keep one long-lived `aerospace subscribe` process for dynamic events;
// - translate those events into SketchyBar custom triggers;
// - run a light fullscreen-state diff after events that may change fullscreen.
//
// Lua still owns all SketchyBar rendering. This daemon only provides timely
// signals, so UI state does not become split between Swift and Lua.
func waitPath(_ name: String, candidates: [String]) -> String {
    while true {
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        fputs("aerospace_watch: \(name) not found, retrying in 5s\n", stderr)
        sleep(5)
    }
}

let sketchybar = waitPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let aerospace = waitPath("aerospace", candidates: ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"])

// Keep event parsing, SketchyBar trigger execution, and fullscreen checks
// separate so slow work in one lane does not block the others.
let eventQueue = DispatchQueue(label: "com.fuzhuoqun.aerospace_watch.events")
let processQueue = DispatchQueue(label: "com.fuzhuoqun.aerospace_watch.sketchybar")
let fullscreenQueue = DispatchQueue(label: "com.fuzhuoqun.aerospace_watch.fullscreen")
var shouldRun = true
var fullscreenCheckScheduled = false
var fullscreenCheckInFlight = false
var fullscreenCheckPending = false
var fullscreenSnapshotInitialized = false
var lastFullscreenSignature = ""

struct CommandResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

func stringValue(_ value: Any?) -> String? {
    switch value {
    case let value as String:
        return value
    case let value as Int:
        return String(value)
    case let value as NSNumber:
        return value.stringValue
    default:
        return nil
    }
}

func runSketchybar(arguments: [String]) {
    processQueue.async {
        let task = Process()
        task.launchPath = sketchybar
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return }
        task.waitUntilExit()
    }
}

func trigger(_ event: String, fields: [String: String] = [:]) {
    var arguments = ["--trigger", event]
    for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
        arguments.append("\(key)=\(value)")
    }
    runSketchybar(arguments: arguments)
}

func triggerFullscreenRefresh() {
    // AeroSpace sometimes settles fullscreen state just after the focus event.
    // A tiny delay lets spaces.lua query the final state once instead of racing it.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
        trigger("aerospace_fullscreen_change", fields: ["SOURCE": "aerospace_watch"])
    }
}

// AeroSpace 0.21 exposes a public Unix-socket command protocol. Using it for
// tiny state checks avoids starting a fresh CLI process on every fullscreen diff.
// If the socket is unavailable or the protocol handshake fails, we fall back to
// the normal CLI path below.
func writeAll(fd: Int32, data: Data) -> Bool {
    data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return false }
        var written = 0
        while written < data.count {
            let result = Darwin.write(fd, base.advanced(by: written), data.count - written)
            if result < 0 && errno == EINTR {
                continue
            }
            if result <= 0 {
                return false
            }
            written += result
        }
        return true
    }
}

func readExact(fd: Int32, count: Int) -> Data? {
    var data = Data(count: count)
    var readCount = 0
    let ok = data.withUnsafeMutableBytes { rawBuffer -> Bool in
        guard let base = rawBuffer.baseAddress else { return false }
        while readCount < count {
            let result = Darwin.read(fd, base.advanced(by: readCount), count - readCount)
            if result < 0 && errno == EINTR {
                continue
            }
            if result <= 0 {
                return false
            }
            readCount += result
        }
        return true
    }
    return ok ? data : nil
}

func uint32Data(_ value: UInt32) -> Data {
    var littleEndianValue = value.littleEndian
    return Data(bytes: &littleEndianValue, count: MemoryLayout<UInt32>.size)
}

func uint32FromLittleEndianData(_ data: Data) -> UInt32? {
    guard data.count == MemoryLayout<UInt32>.size else { return nil }
    var value: UInt32 = 0
    for (offset, byte) in data.enumerated() {
        value |= UInt32(byte) << UInt32(offset * 8)
    }
    return value
}

func aerospaceSocketPath() -> String {
    "/tmp/bobko.aerospace-\(NSUserName()).sock"
}

func connectAeroSpaceSocket() -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let path = aerospaceSocketPath()
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

    let connected = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.connect(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard connected == 0 else {
        Darwin.close(fd)
        return nil
    }

    guard writeAll(fd: fd, data: uint32Data(1)),
          let serverVersionData = readExact(fd: fd, count: MemoryLayout<UInt32>.size),
          uint32FromLittleEndianData(serverVersionData) == 1 else {
        Darwin.close(fd)
        return nil
    }

    return fd
}

func runAeroSpaceSocketCommand(arguments: [String]) -> CommandResult? {
    guard let fd = connectAeroSpaceSocket() else { return nil }
    defer { Darwin.close(fd) }

    let request: [String: Any] = [
        "args": arguments,
        "stdin": "",
        "windowId": NSNull(),
        "workspace": NSNull(),
    ]
    guard let payload = try? JSONSerialization.data(withJSONObject: request),
          writeAll(fd: fd, data: uint32Data(UInt32(payload.count))),
          writeAll(fd: fd, data: payload),
          let lengthData = readExact(fd: fd, count: MemoryLayout<UInt32>.size),
          let length = uint32FromLittleEndianData(lengthData),
          let answerData = readExact(fd: fd, count: Int(length)),
          let answer = try? JSONSerialization.jsonObject(with: answerData) as? [String: Any] else {
        return nil
    }

    guard let stdout = answer["stdout"] as? String,
          let stderr = answer["stderr"] as? String else {
        return nil
    }

    let exitCode: Int32
    switch answer["exitCode"] {
    case let code as Int:
        exitCode = Int32(code)
    case let code as NSNumber:
        exitCode = code.int32Value
    default:
        return nil
    }

    return CommandResult(exitCode: exitCode, stdout: stdout, stderr: stderr)
}

func runAeroSpaceProcessCommand(arguments: [String]) -> CommandResult? {
    let task = Process()
    task.launchPath = aerospace
    task.arguments = arguments
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    task.standardOutput = stdoutPipe
    task.standardError = stderrPipe

    guard (try? task.run()) != nil else { return nil }
    task.waitUntilExit()

    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return CommandResult(exitCode: task.terminationStatus, stdout: stdout, stderr: stderr)
}

func runAeroSpaceCommand(arguments: [String]) -> CommandResult? {
    runAeroSpaceSocketCommand(arguments: arguments) ?? runAeroSpaceProcessCommand(arguments: arguments)
}

func boolValue(_ value: Any?) -> Bool {
    switch value {
    case let value as Bool:
        return value
    case let value as NSNumber:
        return value.boolValue
    case let value as String:
        return value == "true" || value == "1"
    default:
        return false
    }
}

func fullscreenSignature(from output: String) -> String? {
    guard let data = output.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return nil
    }

    var fullscreenWindowIds: [String] = []
    for window in json {
        guard boolValue(window["window-is-fullscreen"]),
              let windowId = stringValue(window["window-id"]) else {
            continue
        }
        fullscreenWindowIds.append(windowId)
    }
    return fullscreenWindowIds.sorted().joined(separator: "|")
}

func runFullscreenStateCheck() {
    // Store only the sorted fullscreen window ids. The actual workspace UI will
    // be rebuilt by spaces.lua after it receives `aerospace_fullscreen_change`.
    if fullscreenCheckInFlight {
        fullscreenCheckPending = true
        return
    }

    fullscreenCheckInFlight = true
    let arguments = [
        "list-windows",
        "--monitor",
        "all",
        "--format",
        "%{window-id}%{window-is-fullscreen}",
        "--json",
    ]
    if let result = runAeroSpaceCommand(arguments: arguments),
       result.exitCode == 0,
       let signature = fullscreenSignature(from: result.stdout) {
        if fullscreenSnapshotInitialized && signature != lastFullscreenSignature {
            triggerFullscreenRefresh()
        }
        lastFullscreenSignature = signature
        fullscreenSnapshotInitialized = true
    }

    fullscreenCheckInFlight = false
    if fullscreenCheckPending {
        fullscreenCheckPending = false
        runFullscreenStateCheck()
    }
}

func scheduleFullscreenStateCheck(delay: TimeInterval = 0.18) {
    fullscreenQueue.async {
        if fullscreenCheckScheduled {
            return
        }
        fullscreenCheckScheduled = true
        fullscreenQueue.asyncAfter(deadline: .now() + delay) {
            fullscreenCheckScheduled = false
            runFullscreenStateCheck()
        }
    }
}

func handleEvent(_ json: [String: Any]) {
    guard let event = json["_event"] as? String else { return }

    switch event {
    case "focused-workspace-changed":
        guard let workspace = stringValue(json["workspace"]) else { return }
        var fields = [
            "FOCUSED_WORKSPACE": workspace,
            "SOURCE": "aerospace_watch",
        ]
        if let prevWorkspace = stringValue(json["prevWorkspace"]) {
            fields["PREV_WORKSPACE"] = prevWorkspace
        }
        trigger("aerospace_workspace_change", fields: fields)
        scheduleFullscreenStateCheck()

    case "focus-changed":
        // Lua no longer subscribes to window_focus_change (bar only highlights
        // workspace segments). Still run fullscreen diff: focus can change FS state.
        scheduleFullscreenStateCheck()

    case "mode-changed":
        guard let mode = stringValue(json["mode"]) else { return }
        trigger("aerospace_mode_change", fields: [
            "AEROSPACE_MODE": mode,
            "SOURCE": "aerospace_watch",
        ])

    case "window-detected":
        var fields = [
            "WINDOW_EVENT": "created",
            "SOURCE": "aerospace_watch",
        ]
        if let windowId = stringValue(json["windowId"]) {
            fields["WINDOW_ID"] = windowId
        }
        if let workspace = stringValue(json["workspace"]) {
            fields["FOCUSED_WORKSPACE"] = workspace
        }
        if let appBundleId = stringValue(json["appBundleId"]) {
            fields["APP_BUNDLE_ID"] = appBundleId
        }
        if let appName = stringValue(json["appName"]) {
            fields["APP_NAME"] = appName
        }
        trigger("space_windows_change", fields: fields)
        scheduleFullscreenStateCheck(delay: 0.30)

    case "binding-triggered":
        scheduleFullscreenStateCheck()

    default:
        return
    }
}

func runSubscribeOnce() {
    let task = Process()
    task.launchPath = aerospace
    task.arguments = [
        "subscribe",
        "focused-workspace-changed",
        "focus-changed",
        "mode-changed",
        "window-detected",
        "binding-triggered",
    ]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice

    var buffer = ""
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
            return
        }
        eventQueue.async {
            buffer += chunk
            while let newline = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                handleEvent(json)
            }
        }
    }

    guard (try? task.run()) != nil else {
        sleep(2)
        return
    }
    task.waitUntilExit()
    pipe.fileHandleForReading.readabilityHandler = nil
}

signal(SIGTERM, SIG_IGN)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler {
    shouldRun = false
    exit(0)
}
sigtermSource.resume()

DispatchQueue.global().async {
    scheduleFullscreenStateCheck()
    while shouldRun {
        runSubscribeOnce()
        if shouldRun {
            sleep(2)
        }
    }
}

RunLoop.main.run()
