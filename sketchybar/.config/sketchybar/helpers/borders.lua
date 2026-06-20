-- ========== Workspace 分段状态样式 ==========
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")

local focused_bg = appearance.with_alpha(colors.red, 0.18)
local fullscreen_bg = appearance.with_alpha(colors.peach, 0.36)
local workspace_style = {
	bracket_height = settings.height - 4,
	bracket_border_width = 2,
	bracket_radius = 10,
}
workspace_style.segment_height = workspace_style.bracket_height - 2 * workspace_style.bracket_border_width
workspace_style.segment_radius = workspace_style.bracket_radius - 1

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

local function distribute(visible_workspace_names, fullscreen_set, focused_name)
	fullscreen_set = fullscreen_set or {}

	for i, name in ipairs(visible_workspace_names) do
		if fullscreen_set[i] then
			set_fullscreen(name)
		elseif name == focused_name then
			set_focused(name)
		else
			sbar.set(name, { background = { drawing = false, border_width = 0 } })
		end
	end
end

return {
	distribute = distribute,
	set_focused = set_focused,
	set_fullscreen = set_fullscreen,
	workspace_style = workspace_style,
}
