-- ========== 当前前台应用名 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local front_app = sbar.add("item", "front_app", {
	display = "active",
	updates = true,
	position = "left",
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
	-- 装饰性尖括号，i3 风格（品牌一致）。如需纯应用名，去掉 ">" 和 "<"
	front_app:set({
		label = {
			string = ">" .. env.INFO .. "<",
		},
	})
end)
