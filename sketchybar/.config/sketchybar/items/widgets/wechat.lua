-- ========== 微信未读消息数 ==========
local status_widget = require("status_widget")

status_widget({
	name = "widgets.wechat",
	app_id = "com.tencent.xinWeChat",
	icon = ":wechat:",
	icon_color = "green",
	icon_inactive_color = "green",
	label_color = "green",
	label_inactive_color = "sep_opaque",
})
