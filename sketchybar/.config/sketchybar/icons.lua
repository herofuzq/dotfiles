-- 图标字形定义
-- 主要使用 Apple SF Symbols，部分图标来自 Nerd Font / 标准 Unicode
-- 每个键代表一个图标用途，值是 Unicode 字形码点
local icons = {
	sf_symbols = {
		apple = "􀣺",
		cpu = "􀫥",

		battery = {
			_100 = "\u{f244}",
			_75 = "\u{f243}",
			_50 = "\u{f242}",
			_25 = "\u{f241}",
			_0 = "\u{f240}",
			charging = "\u{f0e7}",
		},
		clash = {
			tun = "",
		},
		wifi = "",
		network_down = "",
		network_up = "",
		input_method = {
			keyboard = "",
		},
	},
}

return icons.sf_symbols
