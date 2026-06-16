-- ========== 加载所有右侧小组件（从右到左排列） ==========
local sbar = require("sketchybar")

require("items.widgets.sys")           -- CPU 占用率
require("items.widgets.clash_tun")     -- Clash TUN 代理状态
require("items.widgets.dingtalk")      -- 钉钉消息数
require("items.widgets.wechat")        -- 微信消息数
require("items.widgets.battery")       -- 电池电量
require("items.widgets.input_method")  -- 当前输入法
require("items.widgets.network")       -- 网络速度

sbar.add("item", "widgets.media_spacer", {
	position = "right",
	width = 68,
	background = { drawing = false },
})

require("items.widgets.media")         -- 媒体控制
