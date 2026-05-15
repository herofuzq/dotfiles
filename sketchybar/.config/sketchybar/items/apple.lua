-- ========== Apple Logo 按钮（最左侧） ==========
local sbar = require("sketchybar")
local icons = require("icons")
local colors = require("appearance").colors

local apple = sbar.add("item", {
	padding_left = 11,
	padding_right = 2,
	icon = {
		padding_left = 13,
		padding_right = 13,
		string = icons.apple,
		color = colors.active.yellow,
	},
	label = { drawing = false },
	click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.active.apple_border,
		border_width = 2,
	},
})

apple:subscribe("mouse.clicked", function()
	sbar.animate("tanh", 8, function()
		apple:set({
			background = { shadow = { distance = 0 } },
			y_offset = -4,
		})
		apple:set({
			background = { shadow = { distance = 4 } },
			y_offset = 0,
		})
	end)
end)
