-- ========== 菜单栏本体配置 ==========
local appearance = require("appearance")
local settings = require("settings")
local sbar = require("sketchybar")

sbar.bar({
	-- 配置期保持 hidden；高度先写对，startup.reveal() 会在 end_config 后揭示。
	-- 不用默认高度，避免 unhide 瞬间用错 height。
	hidden = "on",
	color = 0x00000000,
	border_width = 0,
	border_color = 0x00000000,
	blur_radius = 0,
	margin = 4,
	corner_radius = 12,
	height = settings.height,
	padding_right = 0,
	padding_left = 0,
	sticky = "on",
	topmost = "window",
	position = "top",
	shadow = "off",
})
