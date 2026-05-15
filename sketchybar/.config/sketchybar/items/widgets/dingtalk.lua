-- ========== 钉钉未读消息数 ==========
local colors = require("appearance").colors
local status_widget = require("status_widget")

status_widget {
	name = "widgets.dingtalk",
	app_id = "com.alibaba.DingTalkMac",
	icon = ":dingtalk:",
	icon_color = colors.peach,                       -- 有消息时变亮橙
	icon_inactive_color = colors.tokyo_night.blue,   -- 无消息时蓝色
	label_color = colors.peach,
	label_inactive_color = colors.tokyo_night.sep_opaque,
	border_color = colors.active.item_gradient[5],
}
