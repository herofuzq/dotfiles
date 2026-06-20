import Darwin
import Foundation

struct AppUsage {
    let name: String
    let cpu: Double
}

struct SensorCache: Codable {
    let temperature: Double
    let fans: [Double]
    let timestamp: Double
}

guard CommandLine.arguments.count == 5 else {
    fputs("usage: sys_watch MACTOP SKETCHYBAR INTERVAL_MS CACHE_PATH\n", stderr)
    exit(2)
}

let mactop = CommandLine.arguments[1]
let sketchybar = CommandLine.arguments[2]
let interval = Double(CommandLine.arguments[3]) ?? 2000
let cachePath = CommandLine.arguments[4]
let queue = DispatchQueue(label: "com.fuzhuoqun.sys_watch")
var sensorTask: Process?
var processTask: Process?
var processTimer: DispatchSourceTimer?
var sensorTimer: DispatchSourceTimer?
var sensorBuffer = ""
var sensorReceived = false
var lastHeader = ""
var lastRows = Array(repeating: "", count: 10)

@Sendable func number(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue
}

@Sendable func appName(_ command: String) -> String {
    if command.hasPrefix("com.apple.WebKit.") {
        return "WebKit"
    }

    var name = command
    let suffixes = [
        " Helper (Renderer)", " Helper (GPU)", " Helper (Plugin)",
        " (Renderer)", " (Service)", " Helper",
    ]
    for suffix in suffixes where name.hasSuffix(suffix) {
        name.removeLast(suffix.count)
        break
    }
    return name.isEmpty ? command : name
}

@Sendable func topApps(from output: String) -> [AppUsage] {
    var totals = [String: Double]()
    for line in output.split(separator: "\n") {
        let fields = line.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\t" }
        )
        guard fields.count == 2,
              let cpu = Double(fields[0]), cpu > 0 else {
            continue
        }
        let name = appName(String(fields[1]))
        if name == "mactop" || name == "sys_watch" {
            continue
        }
        totals[name, default: 0] += cpu
    }

    let usages = totals.map { name, cpu in AppUsage(name: name, cpu: cpu) }
    let sorted = usages.sorted { lhs, rhs in
        lhs.cpu == rhs.cpu ? lhs.name < rhs.name : lhs.cpu > rhs.cpu
    }
    return Array(sorted.prefix(10))
}

@Sendable func runSketchybar(_ arguments: [String]) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: sketchybar)
    task.arguments = arguments
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    guard (try? task.run()) != nil else { return }
    task.waitUntilExit()
}

func setHeader(_ label: String) {
    guard label != lastHeader else { return }
    lastHeader = label
    runSketchybar(["--set", "widgets.sys.info", "label=\(label)"])
}

func header(for cache: SensorCache) -> String {
    let fanText = cache.fans.isEmpty
        ? "-- RPM"
        : cache.fans.map { String(format: "%.0f", $0) }.joined(separator: " / ") + " RPM"
    return String(format: "CPU %.1f°C    风扇 %@", cache.temperature, fanText)
}

func applyCachedSensors() {
    guard let data = FileManager.default.contents(atPath: cachePath),
          let cache = try? JSONDecoder().decode(SensorCache.self, from: data) else {
        return
    }
    setHeader(header(for: cache))
}

func applySensors(_ json: [String: Any]) -> Bool {
    let metrics = json["soc_metrics"] as? [String: Any]
    guard let temperature = number(metrics?["cpu_temp"]) else {
        return false
    }
    let fans = (json["fans"] as? [[String: Any]] ?? []).compactMap { number($0["rpm"]) }
    let cache = SensorCache(
        temperature: temperature,
        fans: fans,
        timestamp: Date().timeIntervalSince1970
    )
    if let data = try? JSONEncoder().encode(cache) {
        try? data.write(to: URL(fileURLWithPath: cachePath), options: .atomic)
    }
    setHeader(header(for: cache))
    return true
}

func setApps(_ apps: [AppUsage]) {
    var arguments = [String]()
    for index in 0..<10 {
        let label: String
        if index < apps.count {
            let app = apps[index]
            label = String(format: "%2d  %@    %.0f%%", index + 1, String(app.name.prefix(22)), app.cpu)
        } else if apps.isEmpty && index == 0 {
            label = "暂无进程数据"
        } else {
            label = " "
        }
        if label != lastRows[index] {
            lastRows[index] = label
            arguments += ["--set", "widgets.sys.process.\(index + 1)", "label=\(label)"]
        }
    }
    if !arguments.isEmpty {
        runSketchybar(arguments)
    }
}

func sampleApps() {
    guard processTask == nil else { return }
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["-Aceo", "pcpu=,comm="]
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    processTask = task
    task.terminationHandler = { _ in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        queue.async {
            processTask = nil
            setApps(topApps(from: output))
        }
    }
    do {
        try task.run()
    } catch {
        processTask = nil
        setApps([])
    }
}

func startSensorRefresh() {
    guard sensorTask == nil else { return }
    applyCachedSensors()

    sensorReceived = false
    sensorBuffer = ""
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: mactop)
    task.arguments = ["--headless", "--count", "0", "--interval", "1000"]
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    sensorTask = task
    task.terminationHandler = { _ in
        queue.async {
            sensorTask = nil
            if !sensorReceived {
                setHeader("请安装 mactop")
            }
        }
    }
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
        queue.async {
            sensorBuffer += chunk
            while let newline = sensorBuffer.firstIndex(of: "\n") {
                let line = String(sensorBuffer[..<newline])
                sensorBuffer.removeSubrange(sensorBuffer.startIndex...newline)
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      applySensors(json) else {
                    continue
                }
                sensorReceived = true
                pipe.fileHandleForReading.readabilityHandler = nil
                if task.isRunning { task.terminate() }
                break
            }
        }
    }
    do {
        try task.run()
    } catch {
        sensorTask = nil
        setHeader("请安装 mactop")
    }
}

func stop() {
    processTimer?.cancel()
    sensorTimer?.cancel()
    if processTask?.isRunning == true { processTask?.terminate() }
    if sensorTask?.isRunning == true { sensorTask?.terminate() }
    exit(0)
}

signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
let terminateSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
terminateSource.setEventHandler(handler: stop)
interruptSource.setEventHandler(handler: stop)
terminateSource.resume()
interruptSource.resume()

// 先显示缓存，再为本次 popup 强制刷新一帧传感器数据。
startSensorRefresh()
let appTimer = DispatchSource.makeTimerSource(queue: queue)
appTimer.schedule(deadline: .now(), repeating: .milliseconds(max(500, Int(interval))))
appTimer.setEventHandler(handler: sampleApps)
appTimer.resume()
processTimer = appTimer

let temperatureTimer = DispatchSource.makeTimerSource(queue: queue)
temperatureTimer.schedule(deadline: .now() + 30, repeating: 30)
temperatureTimer.setEventHandler(handler: startSensorRefresh)
temperatureTimer.resume()
sensorTimer = temperatureTimer

CFRunLoopRun()
