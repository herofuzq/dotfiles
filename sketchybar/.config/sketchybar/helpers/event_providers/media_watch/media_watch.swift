import Foundation

// 循环等待依赖就绪，避免 launchd 无限重启
func waitPath(_ name: String, candidates: [String]) -> String {
    while true {
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) { return p }
        fputs("media_watch: \(name) not found, retrying in 5s\n", stderr)
        sleep(5)
    }
}
let sketchybar = waitPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let mediaControl = waitPath("media-control", candidates: ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"])

var lastTitle = "", lastArtist = "", lastAlbum = "", lastPlaying = false

func applyUpdate(title: String, artist: String, album: String, playing: Bool) {
    let iconChar = playing ? "\u{f04c}" : "\u{f04b}"
    let display: String = {
        if title.isEmpty && artist.isEmpty && album.isEmpty { return "未播放" }
        var parts = [String]()
        if !title.isEmpty { parts.append(title) }
        if !artist.isEmpty { parts.append(artist) }
        if !album.isEmpty { parts.append(album) }
        return parts.joined(separator: " - ")
    }()
    let t1 = Process(); t1.launchPath = sketchybar; t1.arguments = ["--set", "widgets.media_label", "label=\(display)"]; t1.standardOutput = FileHandle.nullDevice; t1.standardError = FileHandle.nullDevice
    if (try? t1.run()) != nil { t1.waitUntilExit() }
    let t2 = Process(); t2.launchPath = sketchybar; t2.arguments = ["--set", "widgets.media_play_pause", "icon=\(iconChar)"]; t2.standardOutput = FileHandle.nullDevice; t2.standardError = FileHandle.nullDevice; try? t2.run() // don't wait, fire and forget
}

func updateState(title: String, artist: String, album: String, playing: Bool) {
    guard title != lastTitle || artist != lastArtist || album != lastAlbum || playing != lastPlaying else {
        return
    }
    lastTitle = title
    lastArtist = artist
    lastAlbum = album
    lastPlaying = playing
    applyUpdate(title: title, artist: artist, album: album, playing: playing)
}

func updateFromCurrentState() {
    let p = Process()
    p.launchPath = mediaControl
    p.arguments = ["get"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return }
    p.waitUntilExit()
    guard let data = try? out.fileHandleForReading.readToEnd(),
          let object = try? JSONSerialization.jsonObject(with: data) else { return }
    if object is NSNull {
        updateState(title: "", artist: "", album: "", playing: false)
        return
    }
    guard let json = object as? [String: Any] else { return }
    let title = json["title"] as? String ?? ""
    let artist = json["artist"] as? String ?? ""
    let album = json["album"] as? String ?? ""
    let playing = json["playing"] as? Bool ?? false
    updateState(title: title, artist: artist, album: album, playing: playing)
}

let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream", "--no-diff", "--no-artwork", "--debounce=100"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
try? task.run()

updateFromCurrentState()

var buffer = ""
pipe.fileHandleForReading.readabilityHandler = { handle in
    guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }
    buffer += chunk
    while let newline = buffer.firstIndex(of: "\n") {
        let line = String(buffer[...newline].dropLast())
        buffer.removeSubrange(buffer.startIndex...newline)
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payloadObject = json["payload"] else { continue }
        if payloadObject is NSNull {
            updateState(title: "", artist: "", album: "", playing: false)
            continue
        }
        guard let payload = payloadObject as? [String: Any] else { continue }
        let title = payload["title"] as? String ?? ""
        let artist = payload["artist"] as? String ?? ""
        let album = payload["album"] as? String ?? ""
        let playing = payload["playing"] as? Bool ?? false
        updateState(title: title, artist: artist, album: album, playing: playing)
    }
}

CFRunLoopRun()
