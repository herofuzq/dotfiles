import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

for screen in NSScreen.screens {
    let frame = screen.frame
    let visible = screen.visibleFrame
    let barHeight = frame.height - visible.height
    let scale = screen.backingScaleFactor
    let isMain = frame.origin.y == 0
    print("\(isMain ? 1 : 0) \(Int(barHeight)) \(Int(scale))x")
}
