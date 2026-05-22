-- ========== sketchybar 主入口 ==========
local sbar = require("sketchybar")

-- 预先检测主题并设好色值，让 begin_config 内的 bar/items 直接用正确的颜色
local appearance = require("appearance")
local current_theme = appearance.detect_system_theme()
if current_theme == "dark" then
	appearance.colors.active = appearance.colors.catppuccin_mocha
	-- appearance.colors.bar.bg = 0xB20d0d13  -- 原：深色 70% 不透明
	appearance.colors.bar.bg = 0x000d0d13    -- 全透明
else
	appearance.colors.active = appearance.colors.catppuccin_latte
	-- appearance.colors.bar.bg = 0xB2E3E3E3  -- 原：浅色 70% 不透明
	appearance.colors.bar.bg = 0x00E3E3E3    -- 全透明
end

-- 将所有初始化配置打包成一条消息发给 sketchybar，提高启动效率
sbar.begin_config()
require("bar")           -- 菜单栏本体尺寸/样式（此时 colors.bar.bg 已是正确主题色）
require("appearance")    -- 配色、字体默认值
-- 同步 M.styles 到当前主题（M.styles 在模块加载时以 mocha 定值）
appearance.styles.workspace.background.color = appearance.colors.active.bar_bg
appearance.styles.workspace.icon.color = appearance.colors.active.sep_opaque
appearance.styles.workspace.label.color = appearance.colors.active.sep_opaque
require("items")         -- 加载所有状态栏条目
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

-- 启动后 3 秒主动检测（弥补守护进程刚 reload 还未就绪的空窗期）
sbar.delay(3, function()
	local startup_theme = appearance.detect_system_theme()
	if startup_theme ~= last_theme then
		last_theme = startup_theme
		appearance.switch_theme(startup_theme)
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

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
