-- ========== 菜单栏本体配置 ==========
-- sbar.bar() 在此调用（在 begin_config 内），颜色读取自 theme-aware 的 appearance.colors.bar.bg
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	color = appearance.colors.bar_bg,
	border_width = 2,
	border_color = appearance.colors.border,
	margin = 4,
	corner_radius = 12,
	height = settings.height,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
	blur_radius = 80,
})
