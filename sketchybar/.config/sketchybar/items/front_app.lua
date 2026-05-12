local fonts = require("fonts")
local sbar = require("sketchybar")
local colors = require("appearance")

local front_app = sbar.add("item", "front_app", {
	display = "active",
	updates = true,
	position = "right",
	padding_right = 2,
	padding_left = 2,
	icon = { drawing = false },
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 8,
		padding_right = 8,
		align = "center",
		color = colors.colors.active.mauve,
	},
	background = {
		drawing = true,
		color = colors.colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.colors.active.lavender,
		border_width = 2,
		shadow = { drawing = false },
	},
})

front_app:subscribe("front_app_switched", function(env)
	front_app:set({
		label = {
			string = "ミ" .. env.INFO .. "彡",
		},
	})
end)

front_app:subscribe("mouse.clicked", function()
	sbar.exec("aerospace workspace next")
end)
