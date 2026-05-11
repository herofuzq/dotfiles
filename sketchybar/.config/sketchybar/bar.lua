local colors = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

-- Equivalent to the --bar domain
sbar.bar({
	color = colors.colors.with_alpha(0xff0d0d13, 0.6),
	border_width = 0,
	border_color = colors.colors.active.mauve,
	margin = 0,
	corner_radius = 0,
	height = settings.height,
	padding_right = 1,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	-- position = "bottom",
	shadow = "true",
	y_offset = 0,
	blur_radius = 5,
})
