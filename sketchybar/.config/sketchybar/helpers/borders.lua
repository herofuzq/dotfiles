-- ========== Workspace 分段状态样式 ==========
-- segment 几何（x_offset、height、corner_radius 等）跟 segment 颜色分开管理：
--   - 几何：set_segment_geometry 在 animation 之外 set，一次到位、不会被插值
--   - 颜色：set_focused / set_inactive 在 sbar.animate 回调里 set，
--           sketchybar 自动同步插值 bg.color + icon/label.color
--
-- 为什么拆开：实测发现 sketchybar 在 sbar.animate 里把 x_offset 当成"相对变化"处理，
-- 每次 animation 启动都从某个隐式 baseline（target - 1）插到 target，造成最右 segment
-- 在动画前 200ms 期间 x_offset 显示为 -1 而不是 -2，视觉上就是"高亮往回跳 1px"。
-- 把 x_offset 拆到 animation 之外后就不参与插值，bug 消失。
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")

local focused_bg = colors.red
local inactive_bg = 0x00000000
local workspace_style = {
	bracket_height = settings.height - 4,
	bracket_border_width = 2,
	bracket_radius = 10,
}
workspace_style.segment_height = workspace_style.bracket_height - 2 * workspace_style.bracket_border_width
workspace_style.segment_radius = workspace_style.bracket_radius - 1

-- workspace.1 (1̲Main) 和 workspace.6 (6̲Play) 是 brackets 的左右端点,
-- focus 高亮的圆角比 bracket 内沿圆角多 1px,导致焦点段两端和 bracket 边距错位。
-- 这里给两端各 ±2px 的水平偏移补偿,让高亮段贴合 bracket 内部。
-- 中间 workspace 不需要补偿。
-- 注意: 若改 aerospace.toml 的 persistent-workspaces 顺序,让 1 不在左端或 6 不在
-- 右端,这里要相应调整 (例如改成最后一个 workspace 的索引)。
local function segment_x_offset(name)
	if name == "workspace.1" or name:match("^workspace%.1%.") then
		return 2
	end
	if name == "workspace.6" or name:match("^workspace%.6%.") then
		return -2
	end
	return 0
end

local function set_segment_geometry(name)
	sbar.set(name, {
		background = {
			drawing = true,
			height = workspace_style.segment_height,
			border_width = 0,
			corner_radius = workspace_style.segment_radius,
			padding_left = 0,
			padding_right = 0,
			x_offset = segment_x_offset(name),
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

local function distribute(visible_workspace_names, focused_name, animated)
	-- 第一步：segment 几何在 animation 之外一次设好（不被插值，避免 x_offset 跳 1px）
	for i, name in ipairs(visible_workspace_names) do
		set_segment_geometry(name)
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
		-- @120Hz: 200ms
		sbar.animate("tanh", 24, apply)
	else
		apply()
	end
end

return {
	distribute = distribute,
	set_focused = set_focused,
	workspace_style = workspace_style,
}
