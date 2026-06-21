import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// 拿主显示器所有支持的 display mode 中的最大 refresh rate。
// ProMotion 设备: 120(即使当前降到 60Hz,这里也返回 120)
// 外接 60Hz 显示器: 60
// 这保证动画帧数按显示器的"能力上限"算,而不是按当前动态档位算
// (动画过程中档位可能变化,会让动画时长不稳定)
var maxRate: Double = 60
if let modes = CGDisplayCopyAllDisplayModes(CGMainDisplayID(), nil) as? [CGDisplayMode] {
	for mode in modes {
		if mode.refreshRate > maxRate {
			maxRate = mode.refreshRate
		}
	}
}
print(Int(maxRate.rounded()))
