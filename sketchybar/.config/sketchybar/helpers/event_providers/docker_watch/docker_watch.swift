import Foundation

// Bridge Docker container events into a lightweight SketchyBar trigger.
//
// This daemon does not own UI state or inspect container lists. It listens to
// Docker's event stream and tells services.lua to refresh once after
// container lifecycle changes. When Docker Desktop is unavailable it uses a
// bounded retry delay and only notifies SketchyBar on availability transitions.

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
var dockerAvailable = false

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

func updateDockerAvailability(_ available: Bool) {
    guard dockerAvailable != available else { return }
    dockerAvailable = available
    scheduleTrigger()
}

func dockerIsReady() -> Bool {
    let task = Process()
    task.launchPath = docker
    task.arguments = ["info", "--format", "{{.ServerVersion}}"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    guard (try? task.run()) != nil,
          waitForProcess(task, timeout: commandTimeout) else {
        return false
    }
    return task.terminationStatus == 0
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

    guard (try? task.run()) != nil else { return }
    task.waitUntilExit()
    pipe.fileHandleForReading.readabilityHandler = nil
}

signal(SIGTERM, SIG_IGN)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler {
    shouldRun = false
    exit(0)
}
sigtermSource.resume()

DispatchQueue.global().async {
    var retryDelay: UInt32 = 2
    while shouldRun {
        guard dockerIsReady() else {
            updateDockerAvailability(false)
            sleep(retryDelay)
            retryDelay = min(retryDelay * 2, 15)
            continue
        }

        retryDelay = 2
        updateDockerAvailability(true)
        runEventsOnce()
        if shouldRun {
            updateDockerAvailability(false)
            sleep(retryDelay)
            retryDelay = min(retryDelay * 2, 15)
        }
    }
}

RunLoop.main.run()
