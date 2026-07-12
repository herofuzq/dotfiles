-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")
local enter_animation = require("helpers.enter_animation")

-- bar hidden 已在 helpers/init.lua 最早设过；这里不再重复 sbar.bar。

-- 登记主条 item 名（供 prepare 只 query 这些 name，不扫 bar 上全部 popup）
enter_animation.install()

sbar.begin_config()
require("appearance").install_defaults()
require("bar")
require("items")
sbar.end_config()

-- end_config 之后（顺序固定）:
--   1) prepare：bar 仍 hidden，query 已登记 item 并铺透明
--   2) run_bar：瞬时 unhide
--   3) run：item alpha 渐入
enter_animation.prepare()
enter_animation.run_bar()
enter_animation.run()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
