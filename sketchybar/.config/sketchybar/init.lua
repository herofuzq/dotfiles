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

-- end_config 之后（顺序固定，不可颠倒）:
--   1) prepare：bar 仍 hidden，把主条 item 铺成透明
--   2) run_bar：取消 hidden，写出最终 bar 样式
--   3) run：item alpha 渐入
enter_animation.prepare()
enter_animation.run_bar()
enter_animation.run()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
