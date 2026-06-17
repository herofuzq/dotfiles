-- ========== 全屏动态边框管理 ==========
-- 仅处理 spaces workspace 的全屏边框，焦点/静态边框由各自路径管理
local sbar = require("sketchybar")
local colors = require("appearance").colors

function distribute(visible_workspace_names, fullscreen_set, focused_name)
	fullscreen_set = fullscreen_set or {}

	for i, name in ipairs(visible_workspace_names) do
		if fullscreen_set[i] then
			sbar.set(name, { background = { border_color = colors.peach, border_width = 2, corner_radius = 10 } })
		elseif name == focused_name then
			sbar.set(name, { background = { border_color = colors.red, border_width = 1, corner_radius = 10 } })
		else
			sbar.set(name, { background = { border_color = colors.border, border_width = 1, corner_radius = 10 } })
		end
	end
end

return { distribute = distribute }
