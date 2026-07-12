-- ========== 微信未读消息数 + social bracket ==========
-- dingtalk 须在 widgets/init.lua 里先于本文件 require。
local sbar = require("sketchybar")
local appearance = require("appearance")
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
	shared_bracket = true,
	padding_left = 4,
	padding_right = 0,
	icon_padding_left = 2,
	icon_padding_right = 2,
	icon_font = "sketchybar-app-font:Regular:13.0",
	label_padding_left = 2,
	label_padding_right = 2,
})

sbar.add("bracket", "widgets.social", { "widgets.dingtalk", "widgets.wechat" }, {
	position = "right",
	background = appearance.pill_bg(),
})
