-- ========== 工作区动态边框管理 ==========
-- 仅处理 spaces workspace 的焦点/全屏边框，静态 widget 边框由各自 item 文件自行设置
local sbar = require("sketchybar")
local colors = require("appearance").colors

function distribute(visible_workspace_names, fullscreen_set)
	fullscreen_set = fullscreen_set or {}

	for i, name in ipairs(visible_workspace_names) do
		if fullscreen_set[i] then
			sbar.set(name, {
				background = { border_color = colors.red, border_width = 4, corner_radius = 10 },
			})
		else
			sbar.set(name, { background = { border_width = 1, corner_radius = 10 } })
		end
	end
end

return { distribute = distribute }
