-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 预先检测主题并设好色值，让 begin_config 内的 bar/items 直接用正确的颜色
local appearance = require("appearance")
local current_theme = appearance.detect_system_theme()
appearance.init_colors(current_theme)

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
appearance.install_defaults()
require("bar") -- 菜单栏本体尺寸/样式（此时 colors.bar.bg 已是正确主题色）
-- M.styles 中的 color 已通过元表动态读取 M.colors.active，无需手动同步
require("items") -- 加载所有状态栏条目
sbar.end_config()

-- 通知 borders.lua 当前主题（深色系数），item 颜色已在 begin_config 内由 colors.active 正确设定
require("helpers.borders").set_theme(current_theme)

local last_theme = current_theme

-- Swift 守护进程监听系统通知，即时触发主题切换
local theme_trigger = sbar.add("item", "theme_trigger", {
	drawing = false,
})
theme_trigger:subscribe("system_appearance_changed", function()
	local new_theme = appearance.detect_system_theme()
	if new_theme ~= last_theme then
		last_theme = new_theme
		appearance.switch_theme(new_theme)
	end
end)

-- 等 10 秒系统稳定后，注册主题检测的兜底机制
local STARTUP_DELAY = 10
sbar.delay(STARTUP_DELAY, function()
	-- 启动阶段一次性复检（弥补守护进程启动后可能遗漏的首次变更）
	sbar.delay(3, function()
		local check_theme = appearance.detect_system_theme()
		if check_theme ~= last_theme then
			last_theme = check_theme
			appearance.switch_theme(check_theme)
		end
	end)

	-- 后备轮询（120 秒一次，守护进程未运行时兜底）
	local theme_check = sbar.add("item", "theme_check", {
		drawing = false,
		update_freq = 120,
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
end)

-- 启动 sketchybar-toggle: 鼠标接近屏幕顶部时自动隐藏 SketchyBar，露出原生菜单栏
-- pkill -x 防 reload 时残留僵尸进程
sbar.exec("pkill -x sketchybar-toggle; sketchybar-toggle --trigger-zone 5 --menu-bar-height 40 --debounce 150 &")

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
