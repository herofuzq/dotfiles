import Foundation

func findPath(_ name: String, candidates: [String]) -> String {
    for p in candidates where FileManager.default.isExecutableFile(atPath: p) { return p }
    fputs("error: \(name) not found\n", stderr)
    exit(1)
}
let sketchybar = findPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let mediaControl = findPath("media-control", candidates: ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"])

var lastTitle = ""
var lastArtist = ""
let lock = NSLock()

func updateDisplay(title: String, artist: String, album: String, playing: Bool) {
    var display = ""
    if title.isEmpty && artist.isEmpty && album.isEmpty {
        display = "未播放"
    } else {
        var parts = [String]()
        if !title.isEmpty { parts.append(title) }
        if !artist.isEmpty { parts.append(artist) }
        if !album.isEmpty { parts.append(album) }
        display = parts.joined(separator: " - ")
    }
    let label = display.replacingOccurrences(of: "\"", with: "\\\"")
    let t = Process()
    t.launchPath = sketchybar
    t.arguments = ["--set", "widgets.media_label", "label=\(label)"]
    t.standardOutput = FileHandle.nullDevice
    t.standardError = FileHandle.nullDevice
    try? t.run()
    t.waitUntilExit()
    // Also trigger event for Lua to update play/pause icon
    let e = Process()
    e.launchPath = sketchybar
    e.arguments = ["--trigger", "media_update"]
    e.standardOutput = FileHandle.nullDevice
    e.standardError = FileHandle.nullDevice
    try? e.run()
    e.waitUntilExit()
}

func processLine(_ line: String) {
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let payload = json["payload"] as? [String: Any] else { return }
    let title = payload["title"] as? String ?? ""
    let artist = payload["artist"] as? String ?? ""
    let album = payload["album"] as? String ?? ""
    let playing = payload["playing"] as? Bool ?? false
    lock.lock()
    let changed = title != lastTitle || artist != lastArtist
    if changed {
        lastTitle = title
        lastArtist = artist
    }
    lock.unlock()
    if changed || playing {
        updateDisplay(title: title, artist: artist, album: album, playing: playing)
    }
}

let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
try? task.run()

// Initial: get now playing
let initProc = Process()
initProc.launchPath = mediaControl
initProc.arguments = ["get"]
let initPipe = Pipe()
initProc.standardOutput = initPipe
try? initProc.run()
initProc.waitUntilExit()
if let initData = try? initPipe.fileHandleForReading.readToEnd(),
   let initStr = String(data: initData, encoding: .utf8) {
    processLine(initStr)
}

var buffer = ""
pipe.fileHandleForReading.readabilityHandler = { handle in
    guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }
    buffer += chunk
    while let newline = buffer.firstIndex(of: "\n") {
        let line = String(buffer[..<newline])
        buffer.removeSubrange(buffer.startIndex...newline)
        processLine(line)
    }
}

task.waitUntilExit()
