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

func updateIfChanged() {
    let p = Process()
    p.launchPath = mediaControl
    p.arguments = ["get"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    guard let data = try? out.fileHandleForReading.readToEnd(),
          let str = String(data: data, encoding: .utf8),
          let json = try? JSONSerialization.jsonObject(with: str.data(using: .utf8)!) as? [String: Any] else { return }
    let title = json["title"] as? String ?? ""
    let artist = json["artist"] as? String ?? ""
    let album = json["album"] as? String ?? ""
    lock.lock()
    let changed = title != lastTitle || artist != lastArtist
    if changed { lastTitle = title; lastArtist = artist }
    lock.unlock()
    guard changed else { return }
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
    let t = Process(); t.launchPath = sketchybar; t.arguments = ["--set", "widgets.media_label", "label=\(label)"]; t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice; try? t.run(); t.waitUntilExit()
    let e = Process(); e.launchPath = sketchybar; e.arguments = ["--trigger", "media_update"]; e.standardOutput = FileHandle.nullDevice; e.standardError = FileHandle.nullDevice; try? e.run(); e.waitUntilExit()
}

// Stream listener: trigger check on any change
let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
try? task.run()

// Initial check
updateIfChanged()

var buffer = ""
pipe.fileHandleForReading.readabilityHandler = { handle in
    guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }
    buffer += chunk
    while let newline = buffer.firstIndex(of: "\n") {
        buffer.removeSubrange(buffer.startIndex...newline)
        updateIfChanged()
    }
}

dispatchMain()
