import Foundation

func findPath(_ name: String, candidates: [String]) -> String {
    for p in candidates where FileManager.default.isExecutableFile(atPath: p) { return p }
    fputs("error: \(name) not found\n", stderr)
    exit(1)
}
let sketchybar = findPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let mediaControl = findPath("media-control", candidates: ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"])

var lastTitle = "", lastArtist = "", lastPlaying = false

func applyUpdate(title: String, artist: String, payload: [String: Any]) {
    let album = payload["album"] as? String ?? ""
    let playing = payload["playing"] as? Bool ?? false
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
    let iconChar = playing ? "\u{f04c}" : "\u{f04b}"
    let t1 = Process(); t1.launchPath = sketchybar; t1.arguments = ["--set", "widgets.media_label", "label=\(label)"]; t1.standardOutput = FileHandle.nullDevice; t1.standardError = FileHandle.nullDevice; try? t1.run(); t1.waitUntilExit()
    let t2 = Process(); t2.launchPath = sketchybar; t2.arguments = ["--set", "widgets.media_play_pause", "icon=\(iconChar)"]; t2.standardOutput = FileHandle.nullDevice; t2.standardError = FileHandle.nullDevice; try? t2.run(); t2.waitUntilExit()
}

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
    let playing = json["playing"] as? Bool ?? false
    guard title != lastTitle || artist != lastArtist || playing != lastPlaying else { return }
    lastTitle = title; lastArtist = artist; lastPlaying = playing
    applyUpdate(title: title, artist: artist, payload: json)
}

let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
try? task.run()

updateIfChanged()

var buffer = ""
pipe.fileHandleForReading.readabilityHandler = { handle in
    guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }
    buffer += chunk
    while let newline = buffer.firstIndex(of: "\n") {
        let line = String(buffer[...newline].dropLast())
        buffer.removeSubrange(buffer.startIndex...newline)
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any] else { continue }
        let title = payload["title"] as? String ?? ""
        let artist = payload["artist"] as? String ?? ""
        guard !title.isEmpty || !artist.isEmpty else { continue }
        guard title != lastTitle || artist != lastArtist else { continue }
        lastTitle = title; lastArtist = artist
        applyUpdate(title: title, artist: artist, payload: payload)
    }
}

CFRunLoopRun()
