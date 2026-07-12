-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")
local enter_animation = require("helpers.enter_animation")

-- bar 透明已在 helpers/init.lua 最早设过一次；这里不再重复 sbar.bar，
-- 避免 reload 路径上多次改 bar 属性造成可见闪烁。

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("appearance").install_defaults()
require("bar")
require("items")
sbar.end_config()

-- end_config 之后:
--   1) run_bar：写出最终 bar 样式并取消 hidden（配置期 hidden，避免透明条闪）
--   2) prepare/run items：主条 item 颜色 alpha 渐入
enter_animation.run_bar()
enter_animation.prepare()
enter_animation.run()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
