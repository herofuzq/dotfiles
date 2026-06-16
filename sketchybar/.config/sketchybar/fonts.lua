return {
	font = {
		text = "JetBrains Maple Mono",
		numbers = "JetBrains Maple Mono",
		size = 12.0,
		style_map = {
			["Regular"] = "Regular",
			["Semibold"] = "SemiBold",
			["Bold"] = "Bold",
		},
	},
	-- 图标字体：Nerd Font 字形 + macOS CoreText 回退渲染 SF Symbols（如 􀣺 等 Unicode 私有区字符）
	-- 若 SF Symbols 图标不显示，确认系统已安装 SF Pro / SF Symbols 字体
	font_icon = {
		text = "Hack Nerd Font",
		numbers = "Hack Nerd Font",
		size = 13.0,
		style_map = {
			["Regular"] = "Regular",
			["Semibold"] = "Semibold",
			["Bold"] = "Bold",
			["Heavy"] = "Heavy",
			["Black"] = "Black",
		},
	},
}
