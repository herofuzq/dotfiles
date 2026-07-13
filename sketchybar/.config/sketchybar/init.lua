-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")
local enter_animation = require("helpers.enter_animation")
local startup = require("helpers.startup")

-- bar hidden 已在 helpers/init.lua 最早设过；这里不再重复 sbar.bar。

-- 登记主条 item，并在 add 时预置渐入所需的透明颜色。
enter_animation.install()

startup.configure(function()
	require("appearance").install_defaults()
	require("bar")
	require("items")
end)

-- end_config 之后：记录已登记的颜色，立即揭示 bar，再执行 item 渐入。
enter_animation.prepare()
startup.reveal()
enter_animation.run()

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
