local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local sys = sbar.add("item", "widgets.sys", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.cpu,
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 0,
		color = colors.tokyo_night.accent_opaque,
	},
	label = {
		string = "0%",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 2,
		padding_right = 8,
		align = "right",
		width = 36,
		color = colors.tokyo_night.sep_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.surface2,
		border_width = 2,
	},
})

sys:subscribe("cpu_update", function(env)
	local cpu_load = tonumber(env.total_load) or 0
	local cpu_str = string.format("%d%%", cpu_load)
	local cpu_color = cpu_load > 70 and colors.red or (cpu_load > 40 and colors.orange or colors.green)
	sys:set({
		icon = { color = cpu_color },
		label = {
			string = cpu_str,
			color = colors.tokyo_night.sep_opaque,
		},
	})
end)
