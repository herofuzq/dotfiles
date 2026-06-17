-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("appearance").install_defaults()
require("bar")
require("items")
sbar.end_config()

-- 启动 sketchybar-toggle: 鼠标接近屏幕顶部时自动隐藏 SketchyBar，露出原生菜单栏
-- pkill -x 防 reload 时残留僵尸进程
local settings = require("settings")
local toggle_height = settings.height + 5
sbar.exec(
	"pkill -x sketchybar-toggle; sketchybar-toggle --trigger-zone 5 --menu-bar-height "
		.. toggle_height
		.. " --debounce 150 &"
)

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
