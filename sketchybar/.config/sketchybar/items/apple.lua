-- ========== Apple Logo 按钮（最左侧） ==========
local sbar = require("sketchybar")
local icons = require("icons")
local colors = require("appearance").colors

local apple = sbar.add("item", "apple", {
	padding_left = 6,
	padding_right = 2,
	icon = {
		padding_left = 16,
		padding_right = 16,
		string = icons.apple,
		color = colors.active.red,
	},
	label = { drawing = false },
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

apple:subscribe("mouse.clicked", function()
	sbar.animate("tanh", 0.15, function()
		apple:set({
			background = { shadow = { distance = 0 } },
			y_offset = -4,
		})
	end)
	sbar.delay(0.15, function()
		sbar.animate("tanh", 0.15, function()
			apple:set({
				background = { shadow = { distance = 4 } },
				y_offset = 0,
			})
		end)
	end)
	sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
end)
