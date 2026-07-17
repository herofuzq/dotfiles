import Cocoa
import Darwin

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Thread.sleep(forTimeInterval: 0.1)

// Carbon GetMBarHeight: 标准的菜单栏高度 (非刘海屏, 始终 30)
// 用来兜底——实测的 top 经常有 1pt 漂移, 不信它
typealias GetMBarHeightFn = @convention(c) () -> Int16
var mbarHeight: Int16 = 30  // 兜底, 拿不到就用 30
if let h = dlopen(nil, RTLD_NOW), let sym = dlsym(h, "GetMBarHeight") {
    mbarHeight = unsafeBitCast(sym, to: GetMBarHeightFn.self)()
    dlclose(h)
}

var best = 0
for screen in NSScreen.screens {
    // 顶部预留 = 屏幕物理顶 (frame.maxY) - 可见顶 (visibleFrame.maxY)
    // 注意: macOS 坐标 y 向上, frame.maxY 是物理顶部
    let top = screen.frame.maxY - screen.visibleFrame.maxY
    let safe = screen.safeAreaInsets.top

    var h: Int
    if safe > 0 {
        // 有刘海/灵动岛: safe area 已包含菜单栏 + 相机区域
        // notch 屏 +1pt 给 menubar 背景的视觉分隔
        h = Int(safe) + 1
    } else if top > 0 {
        // 无刘海, 菜单栏可见: 用 Carbon 标准值 (不信实测的 top, 有 1pt 漂移)
        h = Int(mbarHeight)
    } else {
        // 菜单栏隐藏 (无刘海屏): 返 0, 让 Lua 端用 cache / fallback
        h = 0
    }
    if h > best { best = h }
}

print(best)
