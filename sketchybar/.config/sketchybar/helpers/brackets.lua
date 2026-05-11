local sbar = require("sketchybar")
local fonts = require("fonts")

local M = {}

function M.add_right_bracket(name, left_color, right_color)
	sbar.add("item", name, {
		position = "left",
		background = {
			color = right_color,
			drawing = true,
			corner_radius = 0,
			height = 34,
		},
		icon = { drawing = false },
		label = {
			string = "",
			font = {
				family = fonts.font_icon.text,
				style = "Regular",
				size = 32.0,
			},
			color = left_color,
			padding_left = 0,
			padding_right = 0,
			y_offset = 0,
		},
		padding_left = 0,
		padding_right = 0,
		drawing = true,
	})
end

return M
