-- ========== 菜单栏本体配置 ==========
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	-- 初始完全透明:reload 时如果遇到 internal default fallback 窗口,
	-- bar 不会用一个不对的灰色短暂显示,而是直接是透明的,看不到任何东西。
	-- 颜色和边框由 enter_animation.run_bar() 渐入到目标值。
	color = appearance.with_alpha(appearance.colors.bar_bg, 0),
	border_width = 0,
	border_color = appearance.with_alpha(appearance.colors.border, 0),
	margin = 4,
	corner_radius = 12,
	height = settings.height,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
	blur_radius = 30,
})
