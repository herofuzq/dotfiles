import Foundation

func findPath(_ name: String, candidates: [String]) -> String {
    for p in candidates where FileManager.default.isExecutableFile(atPath: p) { return p }
    fputs("error: \(name) not found\n", stderr)
    exit(1)
}
let sketchybar = findPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let mediaControl = findPath("media-control", candidates: ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"])

var lastTrigger = Date.distantPast

func trigger() {
    let now = Date()
    guard now.timeIntervalSince(lastTrigger) > 1.0 else { return }
    lastTrigger = now

    let t = Process()
    t.launchPath = sketchybar
    t.arguments = ["--trigger", "media_update"]
    t.standardOutput = FileHandle.nullDevice
    t.standardError = FileHandle.nullDevice
    try? t.run()
    t.waitUntilExit()
}

let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream", "--no-diff"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
try? task.run()

// Initial trigger after short delay
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { trigger() }

// Accumulate buffer, trigger on complete lines
var buffer = Data()
pipe.fileHandleForReading.readabilityHandler = { handle in
    let chunk = handle.availableData
    guard !chunk.isEmpty else { return }
    buffer.append(chunk)
    // Process complete lines
    while let newline = buffer.firstIndex(of: 10) {
        buffer.removeSubrange(0...newline)
        trigger()
    }
}

task.waitUntilExit()
