local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance")

local cal = sbar.add("item", {
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 8,
		padding_right = 2,
		color = colors.colors.active.sep_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = 17,
		color = colors.colors.active.sep_opaque,
	},
	background = {
		color = colors.colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.colors.active.surface1,
		border_width = 2,
	},
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 11,
})

cal:subscribe({ "forced", "routine", "system_woke" }, function()
	local t = os.date("*t")
	cal:set({
		icon = string.format("%d月%d日", t.month, t.day),
		label = " " .. os.date("%H:%M"),
	})
end)
