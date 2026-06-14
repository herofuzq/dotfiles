-- ========== 中央调色器 ==========
-- 根据当前可见工作区数量，从预置色库中选取对应配色方案，
-- 统一分配所有 item 的边框颜色（含 apple 和 calendar）。
local sbar = require("sketchybar")

-- 浅色主题（Catppuccin Latte）独立色表，直接使用标准 Latte 色值
-- 旧版的暗色系数乘法逻辑已废弃，深色主题同样使用预置色值（dark_sets）

-- 所有 item 的 item name（按 bar 上从左到右顺序，apple 最左，calendar 最右）
local apple_item = "apple"

local widget_order = {
	"front_app",
	"widgets.input_method",
	"widgets.battery",
	"widgets.wechat",
	"widgets.dingtalk",
	"widgets.clash_tun",
	"widgets.sys",
}

local calendar_item = "calendar"

-- 预置色值 [spaces数量] = { apple, spaces..., widgets..., calendar }
-- 11 个关键色均匀分布在 N 个 item 上，apple/calendar 固定为两端
local dark_sets = {
	[5] = {
		0xfff38ba8,
		0xffec9bab,
		0xfff3aa98,
		0xfff9c193,
		0xfff2e2ad,
		0xffb2e2a3,
		0xff9ae2c1,
		0xff8fdfdd,
		0xff85d8eb,
		0xff75c8eb,
		0xff82b9f5,
		0xff9cb8fb,
		0xffb9b8fc,
		0xffcba6f7,
	},
	[6] = {
		0xfff38ba8,
		0xffed9aaa,
		0xfff1a89c,
		0xfff9b98c,
		0xfff9dba9,
		0xffc9e2a7,
		0xffa0e2af,
		0xff94e2d5,
		0xff8cdde4,
		0xff80d3eb,
		0xff77c4ee,
		0xff86b6f8,
		0xffa1b9fc,
		0xffbab7fc,
		0xffcba6f7,
	},
	[7] = {
		0xfff38ba8,
		0xffed99aa,
		0xfff0a69f,
		0xfffab387,
		0xfff9d2a1,
		0xffdde2aa,
		0xffa6e3a1,
		0xff9ae2c3,
		0xff90e0dc,
		0xff89dceb,
		0xff7bceeb,
		0xff7bc0f0,
		0xff89b4fa,
		0xffa5bafc,
		0xffbbb6fb,
		0xffcba6f7,
	},
	[8] = {
		0xfff38ba8,
		0xffee98aa,
		0xffeea4a2,
		0xfff8b08b,
		0xfff9ca9b,
		0xffeee2ad,
		0xffbae2a4,
		0xff9fe2b4,
		0xff94e2d5,
		0xff8ddee2,
		0xff83d6eb,
		0xff76c9eb,
		0xff7ebdf3,
		0xff8eb5fa,
		0xffa9bbfd,
		0xffbcb5fb,
		0xffcba6f7,
	},
	[9] = {
		0xfff38ba8,
		0xffee97aa,
		0xffeda3a5,
		0xfff6ae8f,
		0xfff9c395,
		0xfff9dfac,
		0xffcde2a7,
		0xffa3e2a7,
		0xff99e2c5,
		0xff90e0db,
		0xff8adce8,
		0xff7fd2eb,
		0xff75c5ec,
		0xff81baf5,
		0xff93b6fa,
		0xffacbcfd,
		0xffbdb4fb,
		0xffcba6f7,
	},
}

-- 浅色主题独立色表：[spaces数量] = { apple, spaces..., widgets..., calendar }
-- 彩虹顺序：红→橙→黄→绿→青→蓝→紫→粉，色值为自定义渐变色表以保证视觉过渡平滑
-- 插值函数：在颜色 c1 和 c2 之间按 t(0~1) 线性插值
local function lerp_color(c1, c2, t)
	local r1 = (c1 >> 16) & 0xFF
	local g1 = (c1 >> 8) & 0xFF
	local b1 = c1 & 0xFF
	local r2 = (c2 >> 16) & 0xFF
	local g2 = (c2 >> 8) & 0xFF
	local b2 = c2 & 0xFF
	local r = math.floor(r1 + (r2 - r1) * t + 0.5)
	local g = math.floor(g1 + (g2 - g1) * t + 0.5)
	local b = math.floor(b1 + (b2 - b1) * t + 0.5)
	return (0xff << 24) | (r << 16) | (g << 8) | b
end

-- 生成从 red 到 mauve 的平滑渐变，count = apple + spaces + widgets + calendar
local LATTE_ANCHORS = {
	0xffd20f39, -- red
	0xffe64553, -- maroon
	0xfffe640b, -- peach
	0xffdf8e1d, -- yellow
	0xff40a02b, -- green
	0xff179299, -- teal
	0xff209fb5, -- sapphire
	0xff04a5e5, -- sky
	0xff1e66f5, -- blue
	0xff7287fd, -- lavender
	0xff8c6bb8, -- purple_1
	0xff9070e0, -- purple_mid
	0xff9060d8, -- magenta（微调：降低红色分量，与左右蓝紫色系平滑过渡）
	0xff8839ef, -- mauve
}

local function generate_latte_set(count)
	local n = #LATTE_ANCHORS
	local result = {}
	for i = 1, count do
		local t = (i - 1) / (count - 1)
		local pos = t * (n - 1)
		local idx = math.floor(pos) + 1
		local frac = pos - math.floor(pos)
		if idx >= n then
			result[i] = LATTE_ANCHORS[n]
		else
			result[i] = lerp_color(LATTE_ANCHORS[idx], LATTE_ANCHORS[idx + 1], frac)
		end
	end
	return result
end

local latte_sets = {}
for n = 5, 9 do
	latte_sets[n] = generate_latte_set(n + 9) -- n+9 = apple+N+widgets+calendar
end

local current_sets = dark_sets

function set_theme(theme)
	current_sets = (theme == "light") and latte_sets or dark_sets
end

function distribute(visible_workspace_names, fullscreen_set)
	fullscreen_set = fullscreen_set or {}
	local n = #visible_workspace_names
	local set = current_sets[n]
	if not set then
		local fallback_n = math.min(math.max(n, 5), 9)
		set = current_sets[fallback_n]
		if not set then
			return
		end
	end

	local function color_at(idx)
		return set[((idx - 1) % #set) + 1]
	end

	-- apple（无背景无边框，仅图标色）
	sbar.set(apple_item, { icon = { color = 0xffa6e3a1 } })

	-- 工作区（边框颜色由 spaces.lua 的 space_change 控制高亮）
	for i, name in ipairs(visible_workspace_names) do
		local is_fullscreen = fullscreen_set[i]
		if is_fullscreen then
			sbar.set(name, {
				background = { border_color = 0xffff4444, border_width = 4 },
				popup = { background = { border_color = 0xffff4444 } },
			})
		end
	end

	-- 静态 widget（统一灰边框）
	for i, name in ipairs(widget_order) do
		sbar.set(name, { background = { border_color = 0xff6c7086 } })
	end

	-- calendar（统一灰边框）
	sbar.set(calendar_item, {
		background = { border_color = 0xff6c7086 },
		popup = { background = { border_color = 0xff6c7086 } },
	})
end

return { distribute = distribute, set_theme = set_theme }
