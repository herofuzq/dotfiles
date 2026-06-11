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
    let safeTop = screen.safeAreaInsets.top
    print("\(isMain ? 1 : 0) bar=\(Int(barHeight)) safe=\(Int(safeTop)) thick=\(Int(NSStatusBar.system.thickness)) scale=\(Int(scale))x")
}
