-- ========== 钉钉未读消息数 ==========
local colors = require("appearance").colors
local status_widget = require("status_widget")

status_widget({
	name = "widgets.dingtalk",
	app_id = "com.alibaba.DingTalkMac",
	icon = ":dingtalk:",
	icon_color = colors.active.peach,
	icon_inactive_color = colors.active.blue,
	label_color = colors.active.peach,
	label_inactive_color = colors.active.sep_opaque,
})
