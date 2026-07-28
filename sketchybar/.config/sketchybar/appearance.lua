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
-- 三层语义：中性色（顶层）+ status（状态语义）+ identity（widget 固定强调色登记表）。
-- widget 只许引用 colors.status.* / colors.identity.* / 中性色，禁止裸引用色板色。
local function build_colors(P)
	return {
		pill_bg = M.with_alpha(P.surface0, A.pill), -- surface0 @ 0.667
		pill_fg = P.text,
		bar_bg = M.with_alpha(P.crust, A.bar_bg),
		-- dim: 历史命名，当前与 pill_bg 同值，不是「弱前景色」。
		-- install_defaults 用它当默认 icon.color；widget 应显式设自己的颜色。
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
		-- 按压反馈色（apple 图标、media 按钮共用）
		press = P.yellow,
		-- 状态语义色：电量/CPU/网络/git/docker/clash 等状态驱动场景专用
		status = {
			ok = P.green, -- 正常 / 开 / 全部运行
			error = P.red, -- 异常 / 关 / 离线 / 低电
			warn = P.yellow, -- 注意：git dirty、docker 部分运行、暂停、操作进行中
			caution = P.peach, -- 中档警告：电量/CPU 中间档
		},
		-- 身份色登记表：widget 的固定强调色，与状态无关
		identity = {
			apple = P.green,
			music_icon = P.peach,
			music_text = P.yellow,
			sys_icon = P.mauve,
			sys_info = P.peach, -- sys popup 提示文字
			calendar_month = P.mauve,
			input_default = P.sapphire,
			input_a = P.blue, -- 英文 ABC
			input_zh = P.green, -- 中文「微」
			input_ch = P.mauve,
			input_en = P.mauve,
			network = P.sapphire, -- 正常连接
			network_hotspot = P.mauve, -- 热点
			clash_all = P.mauve, -- 全局模式
			clash_sys = P.sapphire, -- 系统代理
			spaces_mode = P.sapphire, -- aerospace_mode
			spaces_ws = P.peach, -- workspace 编号/标签
			spaces_service = P.sapphire, -- service mode 标签
			spaces_win_highlight = P.red, -- 窗口标题高亮
		},
	}
end

-- ========== (5) 切换 ==========
-- defaults read -g AppleInterfaceStyle：stdout 首行 "Dark" = 深色；
-- 键不存在（浅色）时命令失败、stdout 为空。
function M.parse_apple_interface_style(output)
	return output == "Dark" and "mocha" or "latte"
end

-- 启动同步检测：必须在做任何颜色决策前完成（io.popen 一次，<100ms）。
-- 失败按浅色处理（与 macOS 键不存在语义一致）。
function M.detect_system_theme_sync()
	local ok, style = pcall(function()
		local f = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
		local line = f and f:read("*l") or nil
		if f then
			f:close()
		end
		return line
	end)
	return M.parse_apple_interface_style(ok and style or nil)
end

-- 配置加载即确定主题：appearance 在 begin_config 前被首次 require，
-- 浅色系统 reload 不会先显示 mocha 再切 latte。
M.active = M.detect_system_theme_sync()
M.colors = build_colors(palette[M.active])
-- 导出供测试与主题切换使用
M.palette = palette
M.build_colors = build_colors

-- ========== (5.1) 原地更新 + 注册表热换色 ==========
-- M.colors 表对象终身不变：9+ 个模块缓存了 local colors = appearance.colors，
-- 直接换表会让旧缓存指向旧色板，状态刷新时写回旧主题色（反弹）。
-- 约束：模块生命周期内禁止缓存标量色值（local red = colors.red 禁止）；
-- 只允许缓存表引用（表内容会被原地更新）。函数体内单次计算不受限。
local function update_table_in_place(target, source)
	for k in pairs(target) do
		if source[k] == nil then
			target[k] = nil
		end
	end
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			update_table_in_place(target[k], v) -- 子表保持引用，递归原地更新
		else
			target[k] = v
		end
	end
end
M.update_table_in_place = update_table_in_place -- 导出供测试

-- 各 owner 注册的"应用颜色"回调：fn(colors) 按模块当前状态重算并 set 颜色。
-- enter_animation 包装了 sbar.set/item:set，回调里的 set 会自动同步 reveal 目标色。
local appliers = {}
function M.register_colors(name, fn)
	appliers[name] = fn
end

-- 已注册 owner 名单（测试用，防旧架构式名单漂移）
function M.registered_names()
	local list = {}
	for name in pairs(appliers) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

-- 热切换主题：原地更新 M.colors 后遍历注册表重涂，不 reload。
-- 同主题/未知主题为 no-op（防抖由调用方 detect 比较保证，这里双保险）。
function M.switch_theme(theme)
	if theme ~= "mocha" and theme ~= "latte" then
		return false
	end
	if theme == M.active then
		return false
	end
	M.active = theme
	update_table_in_place(M.colors, build_colors(palette[theme]))
	local sbar = require("sketchybar")
	local timing = require("helpers.timing")
	sbar.animate("linear", timing.THEME_SWITCH_FRAMES, function()
		for _, fn in pairs(appliers) do
			fn(M.colors)
		end
	end)
	return true
end

-- bar 本体也是 owner：切换时重涂 bar_bg。
-- 注意：这里只注册、不在配置期调用——配置期 bar 由 bar.lua 保持全透明，
-- 启动 reveal 时 startup/enter_animation 会现读 appearance.colors.bar_bg 上色。
M.register_colors("appearance.core", function(C)
	require("sketchybar").bar({ color = C.bar_bg })
end)

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
