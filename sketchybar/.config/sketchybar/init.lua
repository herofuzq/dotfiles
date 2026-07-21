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

-- 首屏查询并行完成（最长等 1 秒）后，以真实内容作为目标统一渐入。
startup.when_ready(function()
	enter_animation.prepare()
	enter_animation.conceal()
	startup.reveal()
	enter_animation.run()
end)

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
