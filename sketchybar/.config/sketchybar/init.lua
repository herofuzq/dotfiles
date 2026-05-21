-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("bar")           -- 菜单栏本体尺寸/样式
require("appearance")    -- 配色、字体默认值
require("items")         -- 加载所有状态栏条目
sbar.end_config()

-- ========== 系统外观主题检测与自动切换 ==========
local appearance = require("appearance")
local current_theme = appearance.detect_system_theme()
appearance.switch_theme(current_theme)

local last_theme = current_theme
-- 隐藏 item，每 30 秒轮询系统外观变化
local theme_check = sbar.add("item", "theme_check", {
	drawing = false,
	update_freq = 30,
})
theme_check:subscribe("routine", function()
	local new_theme = appearance.detect_system_theme()
	if new_theme ~= last_theme then
		last_theme = new_theme
		appearance.switch_theme(new_theme)
	end
end)
theme_check:subscribe("system_woke", function()
	local new_theme = appearance.detect_system_theme()
	if new_theme ~= last_theme then
		last_theme = new_theme
		appearance.switch_theme(new_theme)
	end
end)

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
