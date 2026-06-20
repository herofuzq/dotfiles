-- ========== 微信未读消息数 ==========
local sbar = require("sketchybar")
local colors = require("appearance").colors
local status_widget = require("status_widget")

status_widget({
	name = "widgets.wechat",
	app_id = "com.tencent.xinWeChat",
	update_freq = 34,
	icon = ":wechat:",
	icon_color = "green",
	icon_inactive_color = "green",
	label_color = "green",
	label_inactive_color = "text",
})

-- ========== social bracket（dingtalk + wechat）==========
sbar.set("widgets.dingtalk", {
	background = { drawing = false },
	padding_left = 0,
	padding_right = 4,
	icon = { padding_left = 0, padding_right = 2, font = "sketchybar-app-font:Regular:13.0" },
	label = { padding_left = 2, padding_right = 2 },
})
sbar.set("widgets.wechat", {
	background = { drawing = false },
	padding_left = 4,
	padding_right = 0,
	icon = { padding_left = 2, padding_right = 2, font = "sketchybar-app-font:Regular:13.0" },
	label = { padding_left = 2, padding_right = 2 },
})
sbar.add("bracket", "widgets.social", { "widgets.dingtalk", "widgets.wechat" }, {
	position = "right",
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
})
