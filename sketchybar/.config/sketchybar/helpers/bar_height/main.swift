import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

var best = 0
for screen in NSScreen.screens {
    let bar = screen.frame.height - screen.visibleFrame.height
    let safe = screen.safeAreaInsets.top
    let h = Int(safe > 0 ? safe : bar)
    if h > best { best = h }
}
print("\(best) \(best > 0 && NSScreen.main?.safeAreaInsets.top ?? 0 > 0 ? 1 : 0)")
