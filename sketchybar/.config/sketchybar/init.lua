-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("appearance").install_defaults()
require("bar")
require("items")
sbar.end_config()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
