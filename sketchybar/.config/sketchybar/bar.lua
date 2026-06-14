-- ========== 菜单栏本体配置 ==========
-- sbar.bar() 在此调用（在 begin_config 内），颜色读取自 theme-aware 的 appearance.colors.bar.bg
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	color = 0xCC000000,
	border_width = 0,
	border_color = appearance.colors.bar.border,
	margin = 5,
	corner_radius = 9,
	height = settings.height,
	padding_right = 5,
	padding_left = 5,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
	blur_radius = 50,
})
