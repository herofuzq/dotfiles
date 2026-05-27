return {
	font = {
		text = "JetBrainsMono Nerd Font Mono",
		numbers = "JetBrainsMono Nerd Font Mono",
		size = 13.0,
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

	-- 以下为预留字体，当前未被引用，供后续风格调整使用

	font_gohu = {
		text = "GohuFont uni11 Nerd Font Propo",
		numbers = "GohuFont uni11 Nerd Font Propo",
		size = 14.0,
		style_map = {
			["Regular"] = "Regular",
		},
	},

	-- Add Heavy Data Nerd Font
	font_heavy = {
		text = "HeavyData Nerd Font",
		numbers = "HeavyData Nerd Font",
		size = 13.0,
		style_map = {
			["Regular"] = "Regular",
		},
	},

	-- Add FiraCode Nerd Font
	font_fira = {
		text = "FiraCode Nerd Font",
		numbers = "FiraCode Nerd Font",
		size = 13.0,
		style_map = {
			["Regular"] = "Regular",
			["Semibold"] = "Semibold",
			["Bold"] = "Bold",
			["Retina"] = "Retina",
			["Light"] = "Light",
		},
	},
}
