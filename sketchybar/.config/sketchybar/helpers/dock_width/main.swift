import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

let dockDefaults = UserDefaults.standard.persistentDomain(forName: "com.apple.dock") ?? [:]

func dockBool(_ key: String) -> Bool {
	if let value = dockDefaults[key] as? Bool { return value }
	if let value = dockDefaults[key] as? NSNumber { return value.boolValue }
	return false
}

let autohide = dockBool("autohide")
let orientation = dockDefaults["orientation"] as? String ?? "bottom"

func getDockWidth() -> Int? {
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
	var size = CGSize.zero
	guard let sv = sizeValue,
	      CFGetTypeID(sv) == AXValueGetTypeID(),
	      AXValueGetValue((sv as! AXValue), .cgSize, &size) else { return nil }
	return Int(size.width)
}

if autohide || orientation != "left" {
	print("55 \(autohide ? 1 : 0)")
} else if let width = getDockWidth() {
	print("\(width) 0")
} else {
	print("55 0")
}
