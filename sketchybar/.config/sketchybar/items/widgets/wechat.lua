-- ========== 微信未读消息数 ==========
local colors = require("appearance").colors
local status_widget = require("status_widget")

status_widget {
	name = "widgets.wechat",
	app_id = "com.tencent.xinWeChat",
	icon = ":wechat:",
	icon_color = colors.green,                     -- 有消息时图标变亮绿
	icon_inactive_color = colors.tokyo_night.green, -- 无消息时暗绿
	label_color = colors.green,
	label_inactive_color = colors.tokyo_night.sep_opaque,
	border_color = colors.tokyo_night.overlay2,
}
