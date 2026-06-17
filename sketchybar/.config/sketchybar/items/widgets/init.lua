-- ========== 加载所有右侧小组件（从右到左排列） ==========
local sbar = require("sketchybar")

require("items.widgets.sys") -- CPU 占用率
require("items.widgets.battery") -- 电池电量
require("items.widgets.clash_tun") -- Clash TUN 代理状态
require("items.widgets.network") -- 网络速度

sbar.set("widgets.clash_tun", { background = { drawing = false }, padding_left = 1, padding_right = 0 })
sbar.set("widgets.network", { background = { drawing = false } })
sbar.add("bracket", "widgets.system", {
	"widgets.clash_tun",
	"widgets.network_up",
	"widgets.network_down",
}, {
	position = "right",
	background = {
		color = require("appearance").colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})
-- spacer：network 的上下行 item 用 y_offset 垂直堆叠（X 范围重合），
-- 不预留水平空间。media 是水平 item，加在 network 之后会被算法放到
-- bar 右边缘，覆盖 network 的 X 区域，造成两个 bracket pill 视觉重叠。
-- spacer 必须：1) 放在 network 之后、media 之前；2) 宽度等于 network
-- bracket（68），让它和 network 完全重叠，强制 media 停在 spacer 左
-- 边缘外侧。spacer 自身 background.drawing=false 不画背景，视觉上
-- 就是 network 的 pill。
sbar.add("item", "widgets.media_spacer", {
	position = "right",
	width = 58,
	padding_left = 0,
	padding_right = 0,
	background = { drawing = false },
})

require("items.widgets.dingtalk") -- 钉钉消息数
require("items.widgets.wechat") -- 微信消息数
sbar.set("widgets.dingtalk", {
	background = { drawing = false },
	padding_left = 0,
	padding_right = 4,
	icon = {
		padding_left = 0,
		padding_right = 2,
		font = "sketchybar-app-font:Regular:13.0",
	},
	label = { padding_left = 2, padding_right = 2 },
})
sbar.set("widgets.wechat", {
	background = { drawing = false },
	padding_left = 4,
	padding_right = 0,
	icon = {
		padding_left = 2,
		padding_right = 2,
		font = "sketchybar-app-font:Regular:13.0",
	},
	label = { padding_left = 2, padding_right = 2 },
})
sbar.add("bracket", "widgets.social", { "widgets.dingtalk", "widgets.wechat" }, {
	position = "right",
	background = {
		color = require("appearance").colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

require("items.widgets.input_method") -- 当前输入法
require("items.widgets.media") -- 媒体控制
