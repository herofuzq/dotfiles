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
		color = 0xfffab387,
	},
	background = { drawing = false },
})

front_app:subscribe("front_app_switched", function(env)
	front_app:set({ label = { string = env.INFO } })
end)
