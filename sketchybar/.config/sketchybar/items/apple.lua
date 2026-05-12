-- ========== Apple Logo 按钮（最左侧） ==========
local icons = require("icons")
local sbar = require("sketchybar")
local colors = require("appearance")

local apple = sbar.add("item", {
	padding_left = 11,
	padding_right = 2,
	icon = {
		padding_left = 13,
		padding_right = 13,
		string = icons.apple,                   --  Apple 图标
		color = colors.colors.active.yellow,    -- 金色图标（搭配紫色边框，互补撞色）
	},
	label = { drawing = false },               -- 不显示文字
	click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
	background = {
		color = colors.colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.colors.active.purple,  -- 深紫边框
		border_width = 2,
	},
})

-- 点击动画：上弹回弹效果
apple:subscribe("mouse.clicked", function()
	sbar.animate("tanh", 8, function()
		apple:set({
			background = { shadow = { distance = 0 } },
			y_offset = -4,     -- 向上移动 4px
		})
		apple:set({
			background = { shadow = { distance = 4 } },
			y_offset = 0,      -- 回到原位
		})
	end)
end)
