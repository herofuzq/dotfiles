-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("bar")           -- 菜单栏本体尺寸/样式
require("appearance")    -- 配色、字体默认值
require("items")         -- 加载所有状态栏条目
sbar.end_config()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
