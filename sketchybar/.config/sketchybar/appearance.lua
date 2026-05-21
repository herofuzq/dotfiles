-- ========== 外观：配色方案 + 全局默认样式 ==========
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local M = {}

M.colors = {
	bar = {
		bg = 0x990d0d13,
		-- bg = 0xff000000, -- 备用：不透明纯黑背景
		border = 0xB33a3a45,
	},

	popup = { -- 预留未使用（popup 实际配色由 sbar.default 中 colors.active.bar_bg 控制）
		bg = 0xFF1d1b2d,
		border = 0xff7f8490,
	},

	accent = 0xffb482c2, -- 预留未使用（实际配色通过 catppuccin_mocha.accent → colors.active.accent 引用）
	accent_bright = 0xffefc2fc, -- 预留未使用
	accent_tbright = 0x33efc2fc, -- 预留未使用

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
		bg2_opaque = 0xff313244,
		bg3_opaque = 0xff45475a,
		sep_opaque = 0xffa3aed2,
		accent_opaque = 0xffcba6f7,
		deep_blue = 0xff74c7ec,
		-- ── 旧主题 (catppuccin_mocha) 备份 ──
		-- gradient1  = 0xfff5c2e7, -- apple
		-- gradient2  = 0xfff2cdcd, -- spaces 1
		-- gradient3  = 0xfff8c0b0, -- spaces 2
		-- gradient4  = 0xfff8d0a0, -- spaces 3
		-- gradient5  = 0xffd0e8a0, -- spaces 4
		-- gradient6  = 0xffa8e0d8, -- spaces 5
		-- gradient7  = 0xff80d8d0, -- spaces 6
		-- gradient8  = 0xff60d0e0, -- spaces 7
		-- gradient9  = 0xff40c8e8, -- spaces 8
		-- gradient10 = 0xff89dceb, -- spaces 9
		-- gradient11 = 0xff40c8e8, -- front_app
		-- gradient12 = 0xff50c0e0, -- input_method
		-- gradient13 = 0xff60b8d8, -- battery
		-- gradient14 = 0xffb4befe, -- wechat
		-- gradient15 = 0xffc8a8f0, -- dingtalk
		-- gradient16 = 0xffd0a8f8, -- clash_tun
		-- gradient17 = 0xffd8a8f4, -- sys
		-- gradient18 = 0xffcba6f7, -- calendar
		-- ────────────────────────────

		-- 所有边框颜色已迁移至 helpers/borders.lua 统一管理
		-- 此处 gradient1-18 保留仅为兼容占位，实际颜色由 borders.lua 动态分配

		-- 预留颜色（暂未使用，供后续扩展配色方案）
		red_bright = 0xe0f38ba8,
		blue_bright = 0xe089b4fa,
		spotify_green = 0xff1db954,
		default = 0x80ffffff,
		transparent = 0x00000000,
		orange = 0xfff39660,
	},

	catppuccin_latte = {
		bg0 = 0x66eff1f5,
		bg1 = 0x66e6e9ef,
		bg2 = 0x33ccd0da,
		bg3 = 0x33bcc0cc,
		accent = 0x337286bd,
		sep = 0x339ca0b0,
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
		purple_1 = 0xff8c6bb8,
		purple_2 = 0xff8050b8,
		purple_light = 0xffa080f0,
		purple_mid = 0xff9070e0,
		purple_warm = 0xffa070c0,
		magenta = 0xffc060b0,
		rose_pink = 0xffd070b0,
		rose_deep = 0xffd05090,
		input_border = 0xff7287fd,
		text = 0xff8c8fa0,
		subtext1 = 0xff5c5f77,
		subtext0 = 0xffa0a4b4,
		overlay2 = 0xff7c7f93,
		overlay1 = 0xff8c8fa1,
		overlay0 = 0xff9ca0b0,
		surface2 = 0xffacb0be,
		surface1 = 0xffbcc0cc,
		surface0 = 0xffccd0da,
		base = 0x66eff1f5,
		mantle = 0x66e6e9ef,
		crust = 0x66dce0e8,
		white = 0xff4c4f69,
		black = 0xffdce0e8,
		bar_bg = 0xff5a5a70, -- 比暗色模式明显更浅，保持紫色灰调
		bg2_opaque = 0xffccd0da,
		bg3_opaque = 0xffbcc0cc,
		sep_opaque = 0xffc0c4d4,
		accent_opaque = 0xff7287fd,
		deep_blue = 0xff1e66f5,
		red_bright = 0xe0d20f39,
		blue_bright = 0xe01e66f5,
		spotify_green = 0xff1db954,
		default = 0x80000000,
		transparent = 0x00000000,
		orange = 0xfffe640b,
	},

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) * 0x1000000)
	end,
}

M.colors.active = M.colors.catppuccin_mocha

-- ========== 主题检测与切换 ==========

-- 检测当前系统外观：返回 "dark" 或 "light"
function M.detect_system_theme()
	local success, result = pcall(function()
		local f = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
		local style = f:read("*l")
		f:close()
		return style
	end)
	if success and result == "Dark" then
		return "dark"
	end
	return "light"
end

-- 切换主题并应用所有颜色更新
function M.switch_theme(mode)
	if mode == "dark" then
		M.colors.active = M.colors.catppuccin_mocha
		M.colors.bar.bg = 0xB20d0d13 -- 深色模式 70% opacity
		M.colors.bar.border = 0xB33a3a45
	else
		M.colors.active = M.colors.catppuccin_latte
		M.colors.bar.bg = 0xB2E3E3E3 -- 浅色模式 70% opacity
		M.colors.bar.border = 0xB3bcc0cc
	end
	M.apply_current_theme()
end

-- 将当前主题（M.colors.active）应用到 bar 和所有 item
function M.apply_current_theme()
	-- 0. 通知 borders.lua 当前主题（影响 distribute 的深色系数）
	local mode = (M.colors.active == M.colors.catppuccin_mocha) and "dark" or "light"
	require("helpers.borders").set_theme(mode)

	-- 1. Bar 背景（已由 begin_config 内 bar.lua 设好初始色，此处再调确保生效）
	sbar.bar({
		color = M.colors.bar.bg,
		border_color = M.colors.bar.border,
	})

	-- 2. 更新 M.styles（供 spaces.lua 引用）
	M.styles.workspace.background.color = M.colors.active.bar_bg
	M.styles.workspace.icon.color = M.colors.active.sep_opaque
	M.styles.workspace.label.color = M.colors.active.sep_opaque

	-- 3. 更新所有已知 item 的颜色
	sbar.set("apple", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.red },
	})
	sbar.set("front_app", {
		background = { color = M.colors.active.bar_bg },
		label = { color = M.colors.active.sep_opaque },
	})
	-- i3 / aerospace_mode 在 spaces.lua 异步回调中创建，由 theme_changed 事件更新
	sbar.set("calendar", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.sep_opaque },
		label = { color = M.colors.active.sep_opaque },
		popup = {
			background = { color = M.colors.with_alpha(M.colors.active.bar_bg, 0.85) },
		},
	})
	sbar.set("calendar.doy", {
		label = { color = M.colors.active.text },
	})
	sbar.set("calendar.remaining", {
		label = { color = M.colors.active.subtext0 },
	})
	sbar.set("widgets.sys", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.accent_opaque },
		label = { color = M.colors.active.sep_opaque },
	})
	sbar.set("widgets.clash_tun", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.bg3_opaque },
		label = { color = M.colors.active.sep_opaque },
	})
	sbar.set("widgets.battery", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.sep_opaque },
		label = { color = M.colors.active.sep_opaque },
	})
	sbar.set("widgets.input_method", {
		background = { color = M.colors.active.bar_bg },
		icon = { color = M.colors.active.deep_blue },
		label = { color = M.colors.active.sep_opaque },
	})
	sbar.set("widgets.dingtalk", {
		background = { color = M.colors.active.bar_bg },
	})
	sbar.set("widgets.wechat", {
		background = { color = M.colors.active.bar_bg },
	})

	-- 4. 通知工作区 items 更新背景色（spaces.lua / front_app.lua 订阅了 "theme_changed"）
	sbar.exec("sketchybar --trigger theme_changed")
end

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
			highlight_color = 0xffff4444, -- workspace 聚焦高亮色
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
			highlight_color = 0xffff4444,
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
