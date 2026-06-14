-- ========== 菜单栏本体配置 ==========
-- sbar.bar() 在此调用（在 begin_config 内），颜色读取自 theme-aware 的 appearance.colors.bar.bg
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	color = 0x4a181a22,
	border_width = 1,
	border_color = 0x2ab0b8cc,
	margin = 0,
	corner_radius = 0,
	height = settings.height,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
	blur_radius = 50,
})
