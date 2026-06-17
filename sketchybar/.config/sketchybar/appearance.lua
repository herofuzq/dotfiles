-- ========== 外观：Catppuccin 色板 + 语义化颜色 ==========
-- 切换主题：改 M.active → sketchybar --reload
local M = {}

-- ========== ① 色板（纯色值，无 alpha）==========
local palette = {
	mocha = {
		rosewater = 0xfff5e0dc, flamingo  = 0xfff2cdcd, pink     = 0xfff5c2e7,
		mauve     = 0xffcba6f7, red      = 0xfff38ba8, maroon   = 0xffeba0ac,
		peach     = 0xfffab387, yellow   = 0xfff9e2af, green    = 0xffa6e3a1,
		teal      = 0xff94e2d5, sky      = 0xff89dceb, sapphire = 0xff74c7ec,
		blue      = 0xff89b4fa, lavender = 0xffb4befe,
		text      = 0xffcdd6f4, subtext1 = 0xffbac2de, subtext0 = 0xffa6adc8,
		overlay2  = 0xff9399b2, overlay1 = 0xff7f849c, overlay0 = 0xff6c7086,
		surface2  = 0xff585b70, surface1 = 0xff45475a, surface0 = 0xff313244,
		base      = 0xff1e1e2e, mantle   = 0xff181825, crust    = 0xff11111b,
		-- 自定义 opaque 色值
		pill_bg     = 0xff363537,
		pill_fg     = 0xfff7f1ff,
		bar_bg      = 0xff181a22,
		bar_border  = 0xff3a3a45,
	},
	latte = {
		rosewater = 0xffdc8a78, flamingo  = 0xffdd7878, pink     = 0xffea76cb,
		mauve     = 0xff8839ef, red       = 0xffd20f39, maroon   = 0xffe64553,
		peach     = 0xfffe640b, yellow    = 0xffdf8e1d, green    = 0xff40a02b,
		teal      = 0xff179299, sky       = 0xff04a5e5, sapphire = 0xff209fb5,
		blue      = 0xff1e66f5, lavender  = 0xff7287fd,
		text      = 0xff4c4f69, subtext1  = 0xff5c5f77, subtext0 = 0xff6c6f85,
		overlay2  = 0xff7c7f93, overlay1  = 0xff8c8fa1, overlay0 = 0xff9ca0b0,
		surface2  = 0xffacb0be, surface1  = 0xffbcc0cc, surface0 = 0xffccd0da,
		base      = 0xffeff1f5, mantle    = 0xffe6e9ef, crust    = 0xffdce0e8,
		-- 自定义 opaque 色值（latte 适配，后续可调）
		pill_bg     = 0xffdce0e8,
		pill_fg     = 0xff4c4f69,
		bar_bg      = 0xffe3e3e3,
		bar_border  = 0xffbcc0cc,
	},
}

-- ========== ② 工具函数（需在 build_colors 之前定义）==========
function M.with_alpha(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then return color end
	return (color & 0x00ffffff) | (math.floor(alpha * 255) * 0x1000000)
end

-- ========== ③ alpha 常量 ==========
local A = {
	bar_bg  = 0.4,   -- bar 本体透明度
	pill    = 0.667, -- pill 背景 (0xaa/255)
	border  = 0.2,   -- 边框 / 高亮 (0x33/255)
}

-- ========== ④ 构建实际颜色表（含 alpha）==========
-- 输出值与原 colors.active.xxx 完全一致
local function build_colors(P)
	return {
		-- 背景/前景（含 alpha，与原 bar_bg/bg2_opaque/sep/accent 值完全相同）
		pill_bg   = M.with_alpha(P.pill_bg, A.pill),     -- 原 bar_bg: 0xaa363537
		pill_fg   = P.pill_fg,                            -- 原 sep_opaque: 0xfff7f1ff
		bar_bg    = M.with_alpha(P.bar_bg, A.bar_bg),     -- 原 bar.bg: 0x66181a22
		bar_border= P.bar_border,                         -- 原 bar.border: 0xff3a3a45
		dim       = M.with_alpha(P.pill_bg, A.pill),     -- 原 bg2_opaque: 0xaa363537
		border    = M.with_alpha(P.overlay0, A.border),   -- 原 sep: 0x336c7086
		highlight = M.with_alpha(P.mauve, A.border),      -- 原 accent: 0x33cba6f7
		-- 标准色直接透传（原值就是 opaque）
		mauve     = P.mauve,
		red       = P.red,
		green     = P.green,
		peach     = P.peach,
		yellow    = P.yellow,
		sapphire  = P.sapphire,
		blue      = P.blue,
		text      = P.text,
		subtext1  = P.subtext1,
		surface1  = P.surface1,
		overlay0  = P.overlay0,
	}
end

-- ========== ⑤ 切换 ==========
M.active = "mocha"
M.colors = build_colors(palette[M.active])

-- ========== ⑥ 全局默认样式 ==========
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
			height = settings.height - 6,
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
