import Foundation

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

let eventQueue = DispatchQueue(label: "com.fuzhuoqun.aerospace_watch.events")
let processQueue = DispatchQueue(label: "com.fuzhuoqun.aerospace_watch.sketchybar")
var shouldRun = true

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
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
        trigger("aerospace_fullscreen_change", fields: ["SOURCE": "aerospace_watch"])
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

    case "focus-changed":
        guard let windowId = stringValue(json["windowId"]) else { return }
        var fields = [
            "FOCUSED_WINDOW_ID": windowId,
            "SOURCE": "aerospace_watch",
        ]
        if let workspace = stringValue(json["workspace"]) {
            fields["FOCUSED_WORKSPACE"] = workspace
        }
        trigger("window_focus_change", fields: fields)

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

    case "binding-triggered":
        if stringValue(json["binding"]) == "cmd-alt-ctrl-f" {
            triggerFullscreenRefresh()
        }

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
    while shouldRun {
        runSubscribeOnce()
        if shouldRun {
            sleep(2)
        }
    }
}

RunLoop.main.run()
