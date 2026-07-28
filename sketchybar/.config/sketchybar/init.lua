-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")
local enter_animation = require("helpers.enter_animation")
local startup = require("helpers.startup")

-- bar hidden 已在 helpers/init.lua 最早设过；这里不再重复 sbar.bar。

-- 登记主条 item，并在 add 时预置渐入所需的透明颜色。
enter_animation.install()

startup.configure(function()
	require("appearance").install_defaults()
	require("helpers.window_border").install()
	require("bar")
	require("items")

	-- ========== 跟随系统外观自动切换主题 ==========
	-- 事件源：SketchyBar 原生分布式通知映射（无需 Swift 守护进程）。
	-- 通知不保证必达 → system_woke 复检兜底；异步 detect 用 generation 防抖。
	sbar.add("event", "system_appearance_changed", "AppleInterfaceThemeChangedNotification")
	sbar.add("event", "theme_scheme_change")
	local theme_trigger = sbar.add("item", "theme_trigger", { drawing = false })
	local theme_detect_generation = 0
	local function detect_and_switch()
		theme_detect_generation = theme_detect_generation + 1
		local generation = theme_detect_generation
		sbar.exec("defaults read -g AppleInterfaceStyle 2>/dev/null", function(output)
			if output == nil or generation ~= theme_detect_generation then
				return -- nil = exec 失败（区别于键不存在的空输出），保持当前主题
			end
			local first_line = output:match("^%s*(.-)%s*$")
			require("appearance").switch_theme(require("appearance").parse_apple_interface_style(first_line))
		end)
	end
	theme_trigger:subscribe("system_appearance_changed", detect_and_switch)
	theme_trigger:subscribe("system_woke", detect_and_switch)
	theme_trigger:subscribe("theme_scheme_change", function()
		local appearance = require("appearance")
		local scheme, err = appearance.read_scheme_state()
		if scheme then
			appearance.switch_scheme(scheme)
		elseif err ~= "missing" then
			print("[theme] unable to apply scheme state: " .. tostring(err))
		end
	end)
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
