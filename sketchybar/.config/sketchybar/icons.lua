-- 图标字形定义
-- 主要使用 Apple SF Symbols，部分图标来自 Nerd Font / 标准 Unicode
-- 每个键代表一个图标用途，值是 Unicode 字形码点
local icons = {
	sf_symbols = {
		apple = "􀣺",
		cpu = "\u{F4BC}",

		battery = {
			_100 = "\u{F0079}",
			_75 = "\u{F0081}",
			_50 = "\u{F007F}",
			_25 = "\u{F007C}",
			_0 = "\u{F007A}",
			charging = "\u{F0084}",
		},
		clash = {
			tun = "\u{F0582}",
		},
		wifi = "\u{F16BB}",
		network_down = "",
		network_up = "",
		input_method = {
			keyboard = "",
		},
	},
}

return icons.sf_symbols
