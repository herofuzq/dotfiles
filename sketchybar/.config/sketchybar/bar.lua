-- ========== 菜单栏本体配置 ==========
-- sbar.bar() 在此调用（在 begin_config 内），颜色读取自 theme-aware 的 appearance.colors.bar.bg
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	color = 0xFF11111b,
	border_width = 0,
	border_color = appearance.colors.bar.border,
	margin = 0,
	corner_radius = 0,
	height = settings.height,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
	blur_radius = 80,
})
