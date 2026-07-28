-- ========== 钉钉未读消息数 ==========
-- shared_bracket：背景由 wechat.lua 里的 widgets.social bracket 统一提供
local status_widget = require("status_widget")

status_widget({
	name = "widgets.dingtalk",
	app_id = "com.alibaba.DingTalkMac",
	update_freq = 32,
	icon = ":dingtalk:",
	icon_color = "blue", -- 有消息亮起
	icon_inactive_color = "text", -- 无消息普通色（与 input 一致）
	label_color = "count", -- 计数统一色
	label_inactive_color = "text",
	shared_bracket = true,
	padding_left = 0,
	padding_right = 4,
	icon_padding_left = 0,
	icon_padding_right = 2,
	icon_font = "sketchybar-app-font:Regular:13.0",
	label_padding_left = 2,
	label_padding_right = 2,
})
