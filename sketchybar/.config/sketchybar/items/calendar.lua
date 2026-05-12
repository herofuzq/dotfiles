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
		color = colors.colors.active.sep_opaque,
	},
	label = {
		align = "right",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_right = 10,
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
	local is_leap = (t.year % 4 == 0 and t.year % 100 ~= 0) or (t.year % 400 == 0)
	local day_str = is_leap and string.format("第%d/366天", t.yday) or string.format("第%d天", t.yday)
	cal:set({
		icon = string.format("%d月%d日 %s", t.month, t.day, day_str),
		label = os.date("%H:%M"),
	})
end)
