-- ========== 菜单栏本体配置 ==========
local colors = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	color = colors.colors.with_alpha(0xff0d0d13, 0.6), -- 背景色（半透明深色）
	border_width = 0, -- 无边框
	border_color = 0xB33a3a45,
	margin = 0, -- 边距
	corner_radius = 0, -- 圆角
	height = settings.height, -- 高度取自 settings
	padding_right = 1,
	padding_left = 0,
	sticky = "on", -- 始终显示
	topmost = "window", -- 窗口级别（高于普通窗口，低于全屏）
	position = "top", -- 屏幕顶部
	shadow = "true", -- 阴影
	y_offset = 0, -- Y 轴偏移
	blur_radius = 10, -- 毛玻璃模糊半径
	-- notch_width = 1000, --避开notch的宽度
	-- notch_offset = 34, --避开notch的高度
})
