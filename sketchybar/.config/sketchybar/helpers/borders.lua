-- ========== Workspace 分段状态样式 ==========
-- segment 几何（x_offset、height、corner_radius 等）跟 segment 颜色分开管理：
--   - 几何：set_segment_geometry 在 animation 之外 set，一次到位、不会被插值
--   - 颜色：set_focused / set_inactive 在 sbar.animate 回调里 set，
--           sketchybar 自动同步插值 bg.color + icon/label.color
--
-- 为什么拆开：实测发现 sketchybar 在 sbar.animate 里把 x_offset 当成"相对变化"处理，
-- 每次 animation 启动都从某个隐式 baseline（target - 1）插到 target，造成最右 segment
-- 在动画期间 x_offset 显示为 -1 而不是 -2，视觉上就是"高亮往回跳 1px"。
-- 把 x_offset 拆到 animation 之外后就不参与插值，bug 消失。
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")
local timing = require("helpers.timing")

local focused_bg = colors.red
local inactive_bg = 0x00000000
local workspace_style = {
	bracket_height = settings.height - 4,
	bracket_border_width = 2,
	bracket_radius = 10,
}
workspace_style.segment_height = workspace_style.bracket_height - 2 * workspace_style.bracket_border_width
workspace_style.segment_radius = workspace_style.bracket_radius - 1

-- bracket 左右端点的 focus 高亮圆角比 bracket 内沿圆角多 1px,
-- 导致焦点段两端和 bracket 边距错位。给两端各 ±2px 水平偏移补偿。
-- 中间 workspace 不需要补偿。
local function segment_x_offset(name, workspace_order)
	if #workspace_order == 0 then
		return 0
	end
	local first = workspace_order[1]
	local last = workspace_order[#workspace_order]
	if name == "workspace." .. first or name:match("^workspace%." .. first:gsub("([^%w])", "%%%1") .. "%.") then
		return 2
	end
	if name == "workspace." .. last or name:match("^workspace%." .. last:gsub("([^%w])", "%%%1") .. "%.") then
		return -2
	end
	return 0
end

local function set_segment_geometry(name, workspace_order)
	sbar.set(name, {
		background = {
			drawing = true,
			height = workspace_style.segment_height,
			border_width = 0,
			corner_radius = workspace_style.segment_radius,
			padding_left = 0,
			padding_right = 0,
			x_offset = segment_x_offset(name, workspace_order),
		},
	})
end

local function set_focused(name)
	sbar.set(name, {
		background = { color = focused_bg },
		icon = { color = colors.crust, highlight_color = colors.crust },
		label = { color = colors.crust, highlight_color = colors.crust },
	})
end

local function set_inactive(name)
	sbar.set(name, {
		background = { color = inactive_bg },
		icon = { color = colors.pill_fg, highlight_color = colors.pill_fg },
		label = { color = colors.pill_fg, highlight_color = colors.pill_fg },
	})
end

local function distribute(visible_workspace_names, focused_name, animated, workspace_order)
	-- 第一步：segment 几何在 animation 之外一次设好（不被插值，避免 x_offset 跳 1px）
	for i, name in ipairs(visible_workspace_names) do
		set_segment_geometry(name, workspace_order)
	end

	-- 第二步：颜色（bg + icon/label）走 sbar.animate 同步插值
	local function apply()
		for i, name in ipairs(visible_workspace_names) do
			if name == focused_name then
				set_focused(name)
			else
				set_inactive(name)
			end
		end
	end

	if animated then
		sbar.animate("tanh", timing.STANDARD_DURATION_FRAMES, apply)
	else
		apply()
	end
end

return {
	distribute = distribute,
	set_focused = set_focused,
	workspace_style = workspace_style,
}
