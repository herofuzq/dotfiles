-- ========== Workspace 分段状态样式 ==========
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")

local focused_bg = appearance.with_alpha(colors.red, 0.18)
local fullscreen_bg = appearance.with_alpha(colors.peach, 0.36)
local inactive_bg = appearance.with_alpha(colors.red, 0)
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
	if name:match("^workspace%.1") then
		return 2
	end
	if name:match("^workspace%.6") then
		return -2
	end
	return 0
end

local function set_focused(name)
	sbar.set(name, {
		background = {
			drawing = true,
			color = focused_bg,
			height = workspace_style.segment_height,
			border_width = 0,
			corner_radius = workspace_style.segment_radius,
			padding_left = 0,
			padding_right = 0,
			x_offset = segment_x_offset(name),
		},
	})
end

local function set_fullscreen(name)
	sbar.set(name, {
		background = {
			drawing = true,
			color = fullscreen_bg,
			height = workspace_style.segment_height,
			border_width = 0,
			corner_radius = workspace_style.segment_radius,
			padding_left = 0,
			padding_right = 0,
			x_offset = segment_x_offset(name),
		},
	})
end

local function set_inactive(name)
	sbar.set(name, {
		background = {
			drawing = true,
			color = inactive_bg,
			height = workspace_style.segment_height,
			border_width = 0,
			corner_radius = workspace_style.segment_radius,
			padding_left = 0,
			padding_right = 0,
			x_offset = segment_x_offset(name),
		},
	})
end

local function distribute(visible_workspace_names, fullscreen_set, focused_name, animated)
	fullscreen_set = fullscreen_set or {}

	local function apply()
		for i, name in ipairs(visible_workspace_names) do
			if fullscreen_set[i] then
				set_fullscreen(name)
			elseif name == focused_name then
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
	set_fullscreen = set_fullscreen,
	workspace_style = workspace_style,
}
