import Foundation

let center = DistributedNotificationCenter.default()

let observer = center.addObserver(
    forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
    object: nil,
    queue: .main
) { _ in
    let task = Process()
    task.launchPath = "/opt/homebrew/bin/sketchybar"
    task.arguments = ["--trigger", "input_method_change"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try? task.run()
}

let task = Process()
task.launchPath = "/opt/homebrew/bin/sketchybar"
task.arguments = ["--trigger", "input_method_change"]
task.standardOutput = FileHandle.nullDevice
task.standardError = FileHandle.nullDevice
try? task.run()

RunLoop.main.run()
