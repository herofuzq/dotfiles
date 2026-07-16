import Foundation

// Bridge Docker container events into a lightweight SketchyBar trigger.
//
// This daemon does not own UI state and does not query containers. It only
// listens to Docker's event stream and tells services.lua to refresh once after
// container lifecycle changes. If Docker Desktop is not running, `docker events`
// exits and the loop retries quietly.

func waitPath(_ name: String, candidates: [String]) -> String {
    while true {
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        fputs("docker_watch: \(name) not found, retrying in 5s\n", stderr)
        sleep(5)
    }
}

let docker = waitPath("docker", candidates: ["/opt/homebrew/bin/docker", "/usr/local/bin/docker"])
let sketchybar = waitPath("sketchybar", candidates: ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"])
let triggerQueue = DispatchQueue(label: "com.fuzhuoqun.docker_watch.trigger")
var triggerScheduled = false
var shouldRun = true
let commandTimeout: TimeInterval = 1.0

func waitForProcess(_ task: Process, timeout: TimeInterval) -> Bool {
    let finished = DispatchSemaphore(value: 0)
    task.terminationHandler = { _ in finished.signal() }
    guard finished.wait(timeout: .now() + timeout) == .timedOut else {
        task.terminationHandler = nil
        return true
    }
    if task.isRunning { task.terminate() }
    if finished.wait(timeout: .now() + 0.2) == .timedOut, task.isRunning {
        kill(task.processIdentifier, SIGKILL)
    }
    task.terminationHandler = nil
    return false
}

func runSketchybarTrigger() {
    let task = Process()
    task.launchPath = sketchybar
    task.arguments = ["--trigger", "services_change", "SOURCE=docker_watch"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    guard (try? task.run()) != nil else { return }
    _ = waitForProcess(task, timeout: commandTimeout)
}

func scheduleTrigger() {
    triggerQueue.async {
        if triggerScheduled {
            return
        }
        triggerScheduled = true
        triggerQueue.asyncAfter(deadline: .now() + 0.4) {
            triggerScheduled = false
            runSketchybarTrigger()
        }
    }
}

func runEventsOnce() {
    let task = Process()
    task.launchPath = docker
    task.arguments = [
        "events",
        "--filter", "type=container",
        "--filter", "event=create",
        "--filter", "event=start",
        "--filter", "event=stop",
        "--filter", "event=die",
        "--filter", "event=destroy",
        "--filter", "event=health_status",
        "--format", "{{.Type}} {{.Action}} {{.Actor.ID}}",
    ]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice

    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        scheduleTrigger()
    }

    guard (try? task.run()) != nil else {
        sleep(5)
        return
    }
    // 仅在有真实 container event 或 stream 结束时 refresh；不在 stream 刚启动时空刷一次
    task.waitUntilExit()
    pipe.fileHandleForReading.readabilityHandler = nil
    scheduleTrigger()
}

signal(SIGTERM, SIG_IGN)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler {
    shouldRun = false
    exit(0)
}
sigtermSource.resume()

DispatchQueue.global().async {
    while shouldRun {
        runEventsOnce()
        if shouldRun {
            sleep(5)
        }
    }
}

RunLoop.main.run()
