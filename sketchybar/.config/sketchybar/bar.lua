-- ========== 菜单栏本体配置 ==========
-- sbar.bar() 在此调用（在 begin_config 内），颜色读取自 theme-aware 的 colors.colors.bar.bg
local colors = require("appearance")
local sbar = require("sketchybar")

sbar.bar({
	color = colors.colors.bar.bg,
	border_width = 0,
	border_color = colors.colors.bar.border,
	margin = 0,
	corner_radius = 0,
	height = 32,
	padding_right = 1,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "on",
	y_offset = 2,
	blur_radius = 10,
})
