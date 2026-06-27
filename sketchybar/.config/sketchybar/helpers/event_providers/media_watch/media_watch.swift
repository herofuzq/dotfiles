import Foundation

struct MediaState {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
}

// 循环等待依赖就绪，避免 launchd 无限重启
func waitPath(_ name: String, candidates: [String]) -> String {
    while true {
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
            return p
        }
        fputs("media_watch: \(name) not found, retrying in 5s\n", stderr)
        sleep(5)
    }
}
let sketchybar = waitPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let mediaControl = waitPath("media-control", candidates: ["/opt/homebrew/bin/media-control", "/usr/local/bin/media-control"])

let stateQueue = DispatchQueue(label: "com.fuzhuoqun.media_watch.state")
var lastState = MediaState(title: "", artist: "", album: "", playing: false)

func runSketchybar(arguments: [String]) {
    let task = Process()
    task.launchPath = sketchybar
    task.arguments = arguments
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice

    guard (try? task.run()) != nil else { return }
    task.waitUntilExit()
}

func applyUpdate(_ state: MediaState) {
    runSketchybar(arguments: [
        "--trigger", "media_update",
        "TITLE=\(state.title)",
        "ARTIST=\(state.artist)",
        "ALBUM=\(state.album)",
        "PLAYING=\(state.playing ? "1" : "0")",
    ])
}

func mediaState(from object: Any) -> MediaState? {
    if object is NSNull {
        return MediaState(title: "", artist: "", album: "", playing: false)
    }
    guard let json = object as? [String: Any] else {
        return nil
    }
    return MediaState(
        title: json["title"] as? String ?? "",
        artist: json["artist"] as? String ?? "",
        album: json["album"] as? String ?? "",
        playing: json["playing"] as? Bool ?? false
    )
}

func updateState(_ state: MediaState) {
    guard state.title != lastState.title
            || state.artist != lastState.artist
            || state.album != lastState.album
            || state.playing != lastState.playing else {
        return
    }
    lastState = state
    applyUpdate(state)
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
          let object = try? JSONSerialization.jsonObject(with: data),
          let state = mediaState(from: object) else {
        return
    }
    updateState(state)
}

let task = Process()
task.launchPath = mediaControl
task.arguments = ["stream", "--no-diff", "--no-artwork", "--debounce=100"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
task.terminationHandler = { _ in exit(0) }
guard (try? task.run()) != nil else { exit(1) }

updateFromCurrentState()

var buffer = ""
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { exit(0) }
    stateQueue.async {
        buffer += chunk
        while let newline = buffer.firstIndex(of: "\n") {
            let line = String(buffer[...newline].dropLast())
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payloadObject = json["payload"],
                  let state = mediaState(from: payloadObject) else {
                continue
            }
            updateState(state)
        }
    }
}

CFRunLoopRun()
