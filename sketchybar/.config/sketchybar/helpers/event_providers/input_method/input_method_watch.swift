import Foundation

/// Resolve sketchybar path dynamically — works on both Apple Silicon and Intel Macs.
func findSketchybar() -> String {
    let knownPaths = [
        "/opt/homebrew/bin/sketchybar",
        "/usr/local/bin/sketchybar",
    ]
    for path in knownPaths {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    let proc = Process()
    proc.launchPath = "/bin/sh"
    proc.arguments = ["-c", "which sketchybar"]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
    if let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                           encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !result.isEmpty {
        return result
    }

    return "/usr/local/bin/sketchybar"
}

let sketchybarPath = findSketchybar()

let center = DistributedNotificationCenter.default()

let observer = center.addObserver(
    forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
    object: nil,
    queue: .main
) { _ in
    let task = Process()
    task.launchPath = sketchybarPath
    task.arguments = ["--trigger", "input_method_change"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
}

let task = Process()
task.launchPath = sketchybarPath
task.arguments = ["--trigger", "input_method_change"]
task.standardOutput = FileHandle.nullDevice
task.standardError = FileHandle.nullDevice
try? task.run()

RunLoop.main.run()
