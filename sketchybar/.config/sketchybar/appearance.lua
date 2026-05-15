-- ========== 外观：配色方案 + 全局默认样式 ==========
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local M = {}

M.colors = {
	default = 0x80ffffff,
	black = 0xff181819,
	white = 0xffffffff,
	red = 0xfffc5d7c,
	red_bright = 0xe0f38ba8,
	green = 0xff9ed072,
	blue = 0xff76cce0,
	blue_bright = 0xe089b4fa,
	yellow = 0xffe7c664,
	orange = 0xfff39660,
	magenta = 0xffb39df3,
	grey = 0xff7f8490,
	transparent = 0x00000000,

	bar = {
		bg = 0xe0313436,
		border = 0xff2c2e34,
	},

	popup = {
		bg = 0xFF1d1b2d,
		border = 0xff7f8490,
	},

	accent = 0xFFb482c2,
	accent_bright = 0x00efc2fc,
	accent_tbright = 0x33efc2fc,

	catppuccin_mocha = {
		bg0 = 0x661e1e2e,
		bg1 = 0x66181825,
		bg2 = 0x33313244,
		bg3 = 0x3345475a,
		accent = 0x33cba6f7,
		sep = 0x336c7086,
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
		purple_1 = 0xffc8b0f0,
		purple_2 = 0xffc0a0f0,
		purple_light = 0xffd0b0f8,
		purple_mid = 0xffc8a0f0,
		purple_warm = 0xffd090e0,
		magenta = 0xffe080d0,
		rose_pink = 0xfff090d0,
		rose_deep = 0xfff070c0,
		input_border = 0xffb4befe,
		text = 0xffcdd6f4,
		subtext1 = 0xffbac2de,
		subtext0 = 0xffa6adc8,
		overlay2 = 0xff9399b2,
		overlay1 = 0xff7f849c,
		overlay0 = 0xff6c7086,
		surface2 = 0xff585b70,
		surface1 = 0xff45475a,
		surface0 = 0xff313244,
		base = 0x661e1e2e,
		mantle = 0x66181825,
		crust = 0x6611111b,
		white = 0xffcdd6f4,
		black = 0xff11111b,
		bar_bg = 0xff1e1e2e,
		green = 0xff9ed072,
		blue = 0xff76cce0,
		bg2_opaque = 0xff313244,
		bg3_opaque = 0xff45475a,
		sep_opaque = 0xffa3aed2,
		accent_opaque = 0xffcba6f7,
		deep_blue = 0xff74c7ec,
		ws_gradient = {
			0xfff2cdcd,
			0xfff8c0b0,
			0xfff8d0a0,
			0xffd0e8a0,
			0xffa8e0d8,
			0xff80d8d0,
			0xff60d0e0,
			0xff40c8e8,
			0xff89dceb,
		},
		apple_border = 0xfff5c2e7,
		item_gradient = {
			0xff40c8e8,
			0xff50c0e0,
			0xff60b8d8,
			0xffb4befe,
			0xffc8a8f0,
			0xffd0a8f8,
			0xffd8a8f4,
			0xffcba6f7,
		},
	},

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) * 0x1000000)
	end,
}

M.colors.active = M.colors.catppuccin_mocha

M.styles = {
	workspace = {
		background = {
			color = M.colors.active.bar_bg,
			drawing = true,
			corner_radius = 10,
			border_width = 2,
		},
		icon = {
			color = M.colors.active.sep_opaque,
			highlight_color = M.colors.active.peach,
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Bold"],
				size = fonts.font.size,
			},
			padding_left = 10,
			padding_right = 2,
		},
		label = {
			color = M.colors.active.sep_opaque,
			highlight_color = M.colors.active.peach,
			font = "sketchybar-app-font:Regular:14.0",
			padding_left = 2,
			padding_right = 10,
			y_offset = -1,
		},
		blur_radius = 10,
	},
}

sbar.default({
	background = {
		border_color = M.colors.active.bg3,
		border_width = 0,
		color = M.colors.active.bar_bg,
		corner_radius = 0,
		height = settings.height - 6,
		image = {
			corner_radius = 0,
			border_color = M.colors.active.text,
			border_width = 1,
		},
	},
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		color = M.colors.active.bg2_opaque,
		highlight_color = M.colors.active.accent,
		padding_left = 0,
		padding_right = 0,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Semibold"],
			size = fonts.font.size,
		},
		color = M.colors.active.bg2_opaque,
		padding_left = settings.paddings,
		padding_right = settings.paddings,
	},
	popup = {
		align = "center",
		background = {
			border_width = 0,
			corner_radius = 6,
			color = M.colors.active.bar_bg,
			shadow = { drawing = true },
		},
		blur_radius = 50,
		y_offset = 5,
	},
	padding_left = 0,
	blur_radius = 0,
	padding_right = 0,
	scroll_texts = true,
	updates = "on",
})

return M
