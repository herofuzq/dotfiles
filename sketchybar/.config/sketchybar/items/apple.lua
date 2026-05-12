local icons = require("icons")
local settings = require("settings")
local sbar = require("sketchybar")
local colors = require("appearance")

local apple = sbar.add("item", {
	padding_left = 11,
	padding_right = 2,
	icon = {
		padding_left = 13,
		padding_right = 13,
		string = icons.apple,
		color = colors.colors.active.yellow,
	},
	label = { drawing = false },
	click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
	background = {
		color = colors.colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.colors.active.purple,
		border_width = 2,
	},
})

apple:subscribe("mouse.clicked", function()
	sbar.animate("tanh", 8, function()
		apple:set({
			background = {
				shadow = {
					distance = 0,
				},
			},
			y_offset = -4,
		})
		apple:set({
			background = {
				shadow = {
					distance = 4,
				},
			},
			y_offset = 0,
		})
	end)
end)
