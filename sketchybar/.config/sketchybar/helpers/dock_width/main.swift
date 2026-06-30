import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

func readDockDefault(_ key: String) -> String? {
	let task = Process()
	task.launchPath = "/usr/bin/defaults"
	task.arguments = ["read", "com.apple.dock", key]
	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = FileHandle.nullDevice
	if (try? task.run()) != nil {
		task.waitUntilExit()
	}
	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

let autohide = readDockDefault("autohide") == "1"
let orientation = readDockDefault("orientation") ?? "bottom"

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

if autohide || orientation != "left" {
	print("55 \(autohide ? 1 : 0) 0")
} else if let info = getDockInfo() {
    // 格式: <width> <hidden> <x>
    print("\(info.width) 0 \(info.x)")
} else {
	print("55 0 0")
}
