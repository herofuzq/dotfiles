-- ========== Workspace 分段状态样式 ==========
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors

local focused_bg = appearance.with_alpha(colors.red, 0.18)
local fullscreen_bg = appearance.with_alpha(colors.peach, 0.36)
local segment_height = 22
local segment_radius = 8

local function set_focused(name)
	sbar.set(name, {
		background = {
			drawing = true,
			color = focused_bg,
			height = segment_height,
			border_width = 0,
			corner_radius = segment_radius,
		},
	})
end

local function set_fullscreen(name)
	sbar.set(name, {
		background = {
			drawing = true,
			color = fullscreen_bg,
			height = segment_height,
			border_width = 0,
			corner_radius = segment_radius,
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
}
