import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

let task = Process()
task.launchPath = "/usr/bin/defaults"
task.arguments = ["read", "com.apple.dock", "autohide"]
let pipe = Pipe()
task.standardOutput = pipe
task.standardError = FileHandle.nullDevice
if (try? task.run()) != nil {
	task.waitUntilExit()
}
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let autohide = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"

func getDockInfo() -> (width: Int, x: Int)? {
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
    AXUIElementCopyAttributeValue(firstChild, kAXSizeAttribute as CFString, &sizeValue)
    var posValue: CFTypeRef?
    AXUIElementCopyAttributeValue(firstChild, kAXPositionAttribute as CFString, &posValue)

	var size = CGSize.zero
	var pos = CGPoint.zero
	guard let sv = sizeValue,
	      CFGetTypeID(sv) == AXValueGetTypeID(),
	      AXValueGetValue((sv as! AXValue), .cgSize, &size) else { return nil }
	if let pv = posValue, CFGetTypeID(pv) == AXValueGetTypeID() {
		AXValueGetValue((pv as! AXValue), .cgPoint, &pos)
	}
	return (Int(size.width), Int(pos.x))
}

if let info = getDockInfo() {
    let hiddenFlag = autohide ? 1 : 0
    // 格式: <width> <hidden> <x>
    print("\(info.width) \(hiddenFlag) \(info.x)")
} else {
	let hiddenFlag = autohide ? 1 : 0
	print("55 \(hiddenFlag) 0")
}
