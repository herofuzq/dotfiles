-- ========== 当前前台应用名 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local front_app = sbar.add("item", "front_app", {
	display = "active",
	updates = true,
	position = "right",
	padding_right = 2,
	padding_left = 2,
	shadow = "on",
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
		color = colors.active.sep_opaque,
	},
	background = {
		drawing = true,
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
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
