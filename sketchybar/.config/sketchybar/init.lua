-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 预先检测主题并设好色值，让 begin_config 内的 bar/items 直接用正确的颜色
local appearance = require("appearance")
local current_theme = "dark" -- 固定深色主题，禁用自动切换
appearance.init_colors(current_theme)

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
appearance.install_defaults()
require("bar")
require("items")
sbar.end_config()

-- 通知 borders.lua 当前主题（深色系数）
require("helpers.borders").set_theme(current_theme)

-- 主题自动切换已禁用（固定深色）
--local last_theme = current_theme
--local theme_trigger = sbar.add("item", "theme_trigger", { drawing = false })
--theme_trigger:subscribe("system_appearance_changed", function()
--	local new_theme = appearance.detect_system_theme()
--	if new_theme ~= last_theme then
--		last_theme = new_theme
--		appearance.switch_theme(new_theme)
--	end
--end)
--local STARTUP_DELAY = 10
--sbar.delay(STARTUP_DELAY, function()
--	sbar.delay(3, function()
--		local check_theme = appearance.detect_system_theme()
--		if check_theme ~= last_theme then
--			last_theme = check_theme
--			appearance.switch_theme(check_theme)
--		end
--	end)
--	local theme_check = sbar.add("item", "theme_check", { drawing = false, update_freq = 120 })
--	theme_check:subscribe("routine", function()
--		local new_theme = appearance.detect_system_theme()
--		if new_theme ~= last_theme then
--			last_theme = new_theme
--			appearance.switch_theme(new_theme)
--		end
--	end)
--	theme_check:subscribe("system_woke", function()
--		local new_theme = appearance.detect_system_theme()
--		if new_theme ~= last_theme then
--			last_theme = new_theme
--			appearance.switch_theme(new_theme)
--		end
--	end)
--end)

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
