-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")
local enter_animation = require("helpers.enter_animation")

-- 在 begin_config 之外立即把 bar 设为完全透明:
-- reload 信号到达后到 sbar.end_config() 触发前有一段 ~200ms 的窗口,
-- bar 默认会用 internal default (黑色 + 红色边框) 短暂显示。
-- 提前把它设成全透明,这段窗口里 bar 不可见,default 状态被彻底隐藏。
sbar.bar({ color = 0x00000000, border_color = 0x00000000, border_width = 0 })

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("appearance").install_defaults()
require("bar")
require("items")
sbar.end_config()

-- 必须在 end_config 之后：按 bar 最终状态 query 快照，再 alpha 渐入
-- （此时 social/system bracket 的 sbar.set 补丁已经生效）
enter_animation.prepare()
enter_animation.run_bar()
enter_animation.run()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
