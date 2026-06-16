-- ========== 中央调色器（简约版）==========
-- 管理工作区边框、全屏高亮、widget/calendar 统一边框
local sbar = require("sketchybar")
local colors = require("appearance").colors

-- item 名称列表（按 bar 上从左到右顺序）
local apple_item = "apple"

local widget_order = {
	"front_app",
	"widgets.input_method",
	"widgets.battery",
	"widgets.social",
	"widgets.system",
	"widgets.sys",
}

local calendar_item = "calendar"

-- set_theme 保留接口兼容（当前固定深色主题，无需操作）
function set_theme(theme) end

function distribute(visible_workspace_names, fullscreen_set)
	fullscreen_set = fullscreen_set or {}

	-- apple 图标颜色（固定）
	sbar.set(apple_item, { icon = { color = colors.active.green } })

	-- 工作区边框
	for i, name in ipairs(visible_workspace_names) do
		if fullscreen_set[i] then
			sbar.set(name, {
				background = { border_color = colors.active.red, border_width = 4 },
			})
		else
			sbar.set(name, { background = { border_width = 1 } })
		end
	end

	-- widget 统一边框
	for _, name in ipairs(widget_order) do
		sbar.set(name, { background = { border_color = colors.active.sep } })
	end

	-- calendar 边框
	sbar.set(calendar_item, {
		background = { border_color = colors.active.sep },
		popup = { background = { border_color = colors.active.sep } },
	})
end

return { distribute = distribute, set_theme = set_theme }
