-- ========== 外观：Catppuccin 色板 + 语义化颜色 ==========
-- 切换主题：改 M.active → sketchybar --reload
local M = {}

-- ========== (1) 色板（纯色值，无 alpha）==========
local palette = {
	mocha = {
		rosewater = 0xfff5e0dc,
		flamingo = 0xfff2cdcd,
		pink = 0xfff5c2e7,
		mauve = 0xffcba6f7,
		red = 0xfff38ba8,
		maroon = 0xffeba0ac,
		peach = 0xfffab387,
		yellow = 0xfff9e2af,
		green = 0xffa6e3a1,
		teal = 0xff94e2d5,
		sky = 0xff89dceb,
		sapphire = 0xff74c7ec,
		blue = 0xff89b4fa,
		lavender = 0xffb4befe,
		text = 0xffcdd6f4,
		subtext1 = 0xffbac2de,
		subtext0 = 0xffa6adc8,
		overlay2 = 0xff9399b2,
		overlay1 = 0xff7f849c,
		overlay0 = 0xff6c7086,
		surface2 = 0xff585b70,
		surface1 = 0xff45475a,
		surface0 = 0xff313244,
		base = 0xff1e1e2e,
		mantle = 0xff181825,
		crust = 0xff11111b,
	},
	latte = {
		rosewater = 0xffdc8a78,
		flamingo = 0xffdd7878,
		pink = 0xffea76cb,
		mauve = 0xff8839ef,
		red = 0xffd20f39,
		maroon = 0xffe64553,
		peach = 0xfffe640b,
		yellow = 0xffdf8e1d,
		green = 0xff40a02b,
		teal = 0xff179299,
		sky = 0xff04a5e5,
		sapphire = 0xff209fb5,
		blue = 0xff1e66f5,
		lavender = 0xff7287fd,
		text = 0xff4c4f69,
		subtext1 = 0xff5c5f77,
		subtext0 = 0xff6c6f85,
		overlay2 = 0xff7c7f93,
		overlay1 = 0xff8c8fa1,
		overlay0 = 0xff9ca0b0,
		surface2 = 0xffacb0be,
		surface1 = 0xffbcc0cc,
		surface0 = 0xffccd0da,
		base = 0xffeff1f5,
		mantle = 0xffe6e9ef,
		crust = 0xffdce0e8,
	},
}

-- ========== (2) 工具函数（需在 build_colors 之前定义）==========
function M.with_alpha(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then
		return color
	end
	return (color & 0x00ffffff) | (math.floor(alpha * 255) * 0x1000000)
end

-- ========== (3) alpha 常量 ==========
local A = {
	bar_bg = 0.2, -- bar 本体透明度
	pill = 0.667, -- pill 背景 (0xaa/255)
	border = 0.2, -- 边框 / 高亮 (0x33/255)
}

-- ========== (4) 构建实际颜色表（含 alpha）==========
local function build_colors(P)
	return {
		pill_bg = M.with_alpha(P.surface0, A.pill), -- surface0 @ 0.667
		pill_fg = P.text,
		bar_bg = M.with_alpha(P.crust, A.bar_bg),
		dim = M.with_alpha(P.surface0, A.pill),
		border = M.with_alpha(P.overlay0, A.border),
		highlight = M.with_alpha(P.mauve, A.border),
		mauve = P.mauve,
		red = P.red,
		green = P.green,
		peach = P.peach,
		yellow = P.yellow,
		sapphire = P.sapphire,
		blue = P.blue,
		text = P.text,
		subtext1 = P.subtext1,
		surface1 = P.surface1,
		overlay0 = P.overlay0,
		overlay1 = P.overlay1,
		crust = P.crust,
	}
end

-- ========== (5) 切换 ==========
M.active = "mocha"
M.colors = build_colors(palette[M.active])

-- ========== (6) 样式 helpers ==========
-- 所有 widget 复用的标准样式，避免每个文件重抄。
-- 改全局圆角/边框/font size 时只改这里。
local fonts = require("fonts")

-- 标准 pill 背景（widget 和 bracket 都用）。
-- 用法: sbar.add("item", "widgets.battery", { background = appearance.pill_bg(), ... })
function M.pill_bg()
	return {
		color = M.colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = M.colors.border,
	}
end

-- 标准 popup 背景。统一 alpha 0.85 / 圆角 12 / 边框 2，
-- 避免各 widget 散落不同的 alpha/圆角值。
-- 用法: popup = { background = appearance.popup_bg(), ... }
function M.popup_bg()
	return {
		color = M.with_alpha(M.colors.pill_bg, 0.85),
		corner_radius = 12,
		border_width = 2,
		border_color = M.colors.border,
		shadow = { drawing = false },
	}
end

-- 标准 icon 字体（Bold），size 可选，默认用 fonts.font_icon.size。
-- 用法: icon = { ..., font = appearance.font_icon_bold() }
function M.font_icon_bold(size)
	return {
		family = fonts.font_icon.text,
		style = fonts.font_icon.style_map["Bold"],
		size = size or fonts.font_icon.size,
	}
end

-- 标准 label 字体（Bold），size 可选，默认用 fonts.font.size。
-- 用法: label = { ..., font = appearance.font_label_bold() }
function M.font_label_bold(size)
	return {
		family = fonts.font.text,
		style = fonts.font.style_map["Bold"],
		size = size or fonts.font.size,
	}
end

-- ========== (7) 全局默认样式 ==========
function M.install_defaults()
	local C = M.colors
	local settings = require("settings")
	local fonts = require("fonts")
	local sbar = require("sketchybar")

	sbar.default({
		background = {
			border_color = C.subtext1,
			border_width = 2,
			color = C.pill_bg,
			corner_radius = 9,
			height = settings.height - 4,
			image = {
				corner_radius = 0,
				border_color = C.text,
				border_width = 1,
			},
		},
		icon = {
			font = {
				family = fonts.font_icon.text,
				style = fonts.font_icon.style_map["Bold"],
				size = fonts.font_icon.size,
			},
			color = C.dim,
			highlight_color = C.highlight,
			padding_left = 0,
			padding_right = 0,
		},
		label = {
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Semibold"],
				size = fonts.font.size,
			},
			color = C.dim,
			padding_left = settings.default_padding,
			padding_right = settings.default_padding,
		},
		popup = {
			align = "center",
			background = {
				border_width = 0,
				corner_radius = 6,
				color = C.pill_bg,
				shadow = { drawing = true },
			},
			blur_radius = 50,
			y_offset = 2,
		},
		padding_left = 0,
		blur_radius = 0,
		padding_right = 0,
		scroll_texts = true,
		shadow = "off",
		updates = "on",
	})
end

return M
