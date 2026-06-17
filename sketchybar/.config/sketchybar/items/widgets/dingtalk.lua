-- ========== 钉钉未读消息数 ==========
local status_widget = require("status_widget")

status_widget({
	name = "widgets.dingtalk",
	app_id = "com.alibaba.DingTalkMac",
	icon = ":dingtalk:",
	icon_color = "blue",
	icon_inactive_color = "blue",
	label_color = "peach",
	label_inactive_color = "text",
})
