-- ========== 外观：配色方案 + 全局默认样式 ==========
-- 颜色格式：0xAARRGGBB（AA=透明度, RR=红, GG=绿, BB=蓝）
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local M = {}

-- 所有配色方案集合
M.colors = {
	-- 基础颜色（通用）
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

	bg1 = 0xFF1d1b2d,
	bg2 = 0xe0313436,
	bg3 = 0x80000000,
	bg4 = 0x33000000,

	accent = 0xFFb482c2,
	accent_bright = 0x00efc2fc,
	accent_tbright = 0x33efc2fc,

	spotify_green = 0xe040a02b,

	-- 以下为参考配色（当前未使用，保留以备换主题）
	rainbow = {
		orange = 0xffe75300,
		amber = 0xffe29600,
		green = 0xff569f65,
		blue = 0xff278789,
		gray = 0xff685c53,
		soot = 0xff3d3836,
	},
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
		base = 0xff1e1e2e,
		mantle = 0xff181825,
		crust = 0xff11111b,
	},
	macchiato = {
		rosewater = 0xfff4dbd6,
		flamingo = 0xfff0c6c6,
		pink = 0xfff5a97f,
		mauve = 0xffc6a0f6,
		red = 0xffed8796,
		maroon = 0xffee99a0,
		peach = 0xfff5a97f,
		yellow = 0xffeed49f,
		green = 0xffa6da95,
		teal = 0xff8bd5ca,
		sky = 0xff91d7e3,
		sapphire = 0xff7dc4e4,
		blue = 0xff8aadf4,
		lavender = 0xffb7bdf8,
		text = 0xffcad3f5,
		subtext1 = 0xffb8c0e0,
		subtext0 = 0xffa5adcb,
		overlay2 = 0xff939ab7,
		overlay1 = 0xff8087a2,
		overlay0 = 0xff6e738d,
		surface2 = 0xff5b6078,
		surface1 = 0xff494d64,
		surface0 = 0xff363a4f,
		base = 0xff24273a,
		mantle = 0xff1e2030,
		crust = 0xff181926,
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
		base = 0xffeff1f5,
		mantle = 0xffe6e9ef,
		crust = 0xffdce0e8,
	},

	tokyo_night = {
		-- 半透明背景层（用于毛玻璃效果）
		bg0 = 0x661a1b26,
		bg1 = 0x661d2230,
		bg2 = 0x33212736,
		bg3 = 0x33394260,
		accent = 0x33769ff0,
		sep = 0x33a3aed2,
		-- 纯色颜色
		rosewater = 0xfff5e0dc,
		flamingo = 0xfff2cdcd,
		pink = 0xfff5c2e7,
		mauve = 0xffbb9af7, -- 紫色（高亮色）
		red = 0xfff7768e,
		maroon = 0xffeba0ac,
		peach = 0xffff9e64,
		yellow = 0xffe0af68,
		green = 0xff9ece6a,
		teal = 0xff7dcfff,
		sky = 0xff89dceb,
		sapphire = 0xff74c7ec,
		blue = 0xff769ff0,
		lavender = 0xffb4befe,
		purple = 0xff9d84e3, -- 自定义深紫（Apple logo 边框用）
		input_border = 0xffaab4e5, -- 输入法边框色
		-- 文字/层次色
		text = 0xffe3e5e5,
		subtext1 = 0xffa0a9cb,
		subtext0 = 0xffa0a9cb,
		overlay2 = 0xff939ab7,
		overlay1 = 0xff8087a2,
		overlay0 = 0xff6e738d,
		surface2 = 0xff5b6078,
		surface1 = 0xff494d64,
		surface0 = 0xff363a4f,
		base = 0x661a1b26,
		mantle = 0x661d2230,
		crust = 0x66212736,
		white = 0xffe3e5e5,
		black = 0xff090c0c,
		bar_bg = 0xff1a1b26, -- 菜单栏背景
		bg2_opaque = 0xff212736,
		bg3_opaque = 0xff394260,
		sep_opaque = 0xffa3aed2, -- 分隔线/默认文字色
		accent_opaque = 0xff769ff0, -- 强调色
		deep_blue = 0xff51C0FF, -- 深蓝
		-- 工作区边框渐变（9色，紫→蓝→橙）
		ws_gradient = {
			0xffc9a6f0, -- purple
			0xffb0a4f0, -- blue-purple
			0xff92aaf0, -- blue
			0xff6eb6e8, -- light blue
			0xff50c4d4, -- teal
			0xffb0a860, -- olive gold
			0xffc8a048, -- amber
			0xffe09040, -- orange
			0xffe88838, -- deep orange
		},
		-- Apple logo 边框（比最左 workspace 紫更亮，luma ~205）
		apple_border = 0xffd8bff1,
		-- 右侧 item 边框渐变（8色，橙→暗灰，延续 workspace 渐变末端的橙）
		item_gradient = {
			0xffd88838, -- deep orange
			0xffc88040, -- amber
			0xffb87848, -- warm amber
			0xffa08850, -- olive gold
			0xff8e9070, -- warm muted
			0xff788078, -- warm gray
			0xff627068, -- dark warm gray
			0xff4e5858, -- dark gray
		},
	},

	catppuccin_mocha = {
		-- 半透明背景层（用于毛玻璃效果）
		bg0 = 0x661e1e2e,
		bg1 = 0x66181825,
		bg2 = 0x33313244,
		bg3 = 0x3345475a,
		accent = 0x33cba6f7,
		sep = 0x336c7086,
		-- 纯色颜色
		rosewater = 0xfff5e0dc,
		flamingo = 0xfff2cdcd,
		pink = 0xfff5c2e7,
		mauve = 0xffcba6f7, -- 紫色（高亮色）
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
		purple_1 = 0xffc8b0f0, -- 自定义紫色1（245°，插值填充lavender到mauve）
		purple_2 = 0xffc0a0f0, -- 自定义紫色2（255°，插值填充lavender到mauve）
		purple_light = 0xffd0b0f8, -- 自定义浅紫色（250°，lavender到purple_1过渡）
		purple_mid = 0xffc8a0f0, -- 自定义中紫色（262°，填充mauve前过渡）
		purple_warm = 0xffd090e0, -- 自定义暖紫色（275°，填充mauve后过渡）
		magenta = 0xffe080d0, -- 自定义品红色（300°，pink前过渡）
		rose_pink = 0xfff090d0, -- 自定义玫瑰粉（325°，rosewater前过渡）
		rose_deep = 0xfff070c0, -- 自定义深玫瑰（340°，rosewater后过渡）
		input_border = 0xffb4befe, -- 输入法边框色
		-- 文字/层次色
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
		bar_bg = 0xff1e1e2e, -- 菜单栏背景
		bg2_opaque = 0xff313244,
		bg3_opaque = 0xff45475a,
		sep_opaque = 0xffa3aed2, -- 分隔线/默认文字色
		accent_opaque = 0xffcba6f7, -- 强调色
		deep_blue = 0xff74c7ec, -- 深蓝
		ws_gradient = {
			0xfff2cdcd, -- flamingo（ws1）
			0xfff8c0b0, -- peach-warm（ws2）
			0xfff8d0a0, -- yellow-warm（ws3）
			0xffd0e8a0, -- green-warm（ws4）
			0xffa8e0d8, -- teal-light（ws5）
			0xff80d8d0, -- teal（ws6）
			0xff60d0e0, -- sky-light（ws7）
			0xff40c8e8, -- sky（ws8）
			0xff89dceb, -- sky（ws9）
		},
		-- Apple logo 边框（配合黄色图标的对比色）
		apple_border = 0xfff5c2e7, -- pink
		-- 右侧 item 边框渐变（8色，从 workspace 末端粉色过渡到深灰）
		item_gradient = {
			0xff40c8e8, -- sky（front_app）
			0xff50c0e0, -- sky-purple（input_method）
			0xff60b8d8, -- blue-purple（battery）
			0xffb4befe, -- lavender（wechat）
			0xffc8a8f0, -- purple-pink（dingtalk）
			0xffd0a8f8, -- pink-purple（clash）
			0xffd8a8f4, -- purple-rose（sys）
			0xffcba6f7, -- mauve（calendar）
		},
	},

	-- 工具函数：给颜色加透明度
	-- color: 原始 0xAARRGGBB 颜色值
	-- alpha: 0.0 ~ 1.0 的透明度
	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) * 0x1000000)
	end,
}

-- 设置当前活跃主题（切换主题只需要改这里）
M.colors.active = M.colors.catppuccin_mocha

-- 各组件的特定样式模板
M.styles = {
	-- 工作区条目的样式（在 items/spaces.lua 中使用）
	workspace = {
		background = {
			color = M.colors.active.bar_bg,
			drawing = true,
			corner_radius = 10,
			border_width = 2, -- 边框宽度，颜色由代码动态分配（彩虹渐变）
		},
		icon = {
			color = M.colors.active.sep_opaque, -- 非高亮的默认色
			highlight_color = M.colors.active.peach, -- 高亮（当前活跃）色
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Bold"],
				size = fonts.font.size,
			},
			padding_left = 10,
			padding_right = 2,
		},
		label = {
			color = M.colors.active.sep_opaque, -- 应用图标默认色
			highlight_color = M.colors.active.peach, -- 高亮色
			font = "sketchybar-app-font:Regular:14.0",
			padding_left = 2,
			padding_right = 10,
			y_offset = -1,
		},
		blur_radius = 10,
	},
}

-- ========== 全局默认属性（所有 noinherit item 会继承这些） ==========
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
