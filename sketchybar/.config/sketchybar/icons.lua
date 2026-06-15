-- 图标字形定义
-- 主要使用 Apple SF Symbols，部分图标来自 Nerd Font / 标准 Unicode
-- 每个键代表一个图标用途，值是 Unicode 字形码点
local icons = {
	sf_symbols = {
		apple = "􀣺",
		cpu = "􀫥",

		battery = {
			_100 = "􀛨",
			_75 = "􀺸",
			_50 = "􀺶",
			_25 = "􀛩",
			_0 = "􀛪",
			charging = "􀢋",
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
