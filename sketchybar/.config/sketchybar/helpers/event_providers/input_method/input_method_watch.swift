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

let center = DistributedNotificationCenter.default()
let observer = center.addObserver(
    forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
    object: nil, queue: .main
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
