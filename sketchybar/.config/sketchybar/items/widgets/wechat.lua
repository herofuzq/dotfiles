-- ========== 微信未读消息数 ==========
local colors = require("appearance").colors
local status_widget = require("status_widget")

status_widget({
	name = "widgets.wechat",
	app_id = "com.tencent.xinWeChat",
	icon = ":wechat:",
	icon_color = colors.active.green,
	icon_inactive_color = colors.active.green,
	label_color = colors.active.green,
	label_inactive_color = colors.active.sep_opaque,
})
