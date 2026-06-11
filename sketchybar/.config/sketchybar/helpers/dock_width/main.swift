import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

// 检测 Dock 是否自动隐藏
let task = Process()
task.launchPath = "/usr/bin/defaults"
task.arguments = ["read", "com.apple.dock", "autohide"]
let pipe = Pipe()
task.standardOutput = pipe
task.launch()
task.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let autohide = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"

// 通过 Accessibility API 获取 Dock 实际渲染宽度
func getDockVisualWidth() -> Int? {
    guard let dockApp = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.dock"
    ).first else { return nil }

    let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

    var children: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children)
    guard err == .success,
          let childrenArray = children as? [AXUIElement],
          let firstChild = childrenArray.first else { return nil }

    var sizeValue: CFTypeRef?
    let sizeErr = AXUIElementCopyAttributeValue(firstChild, kAXSizeAttribute as CFString, &sizeValue)
    guard sizeErr == .success,
          let axValue = sizeValue as! AXValue? else { return nil }

    var size = CGSize.zero
    guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
    return Int(size.width)
}

let dockWidth = getDockVisualWidth() ?? Int(NSScreen.main!.visibleFrame.origin.x)

// 输出格式: "<宽度> <隐藏标志>"
// 宽度: Dock 实际渲染宽度 (AX API)，失败则 fallback 到 NSScreen
// 标志: 0 = Dock 可见, 1 = Dock 隐藏（触发 icon_pad = 15 fallback）
let hiddenFlag = autohide ? 1 : 0
print("\(dockWidth) \(hiddenFlag)")
