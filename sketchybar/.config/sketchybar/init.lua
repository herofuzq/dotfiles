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

-- ========== 开机自愈：登录初期显示器重构风暴下的原生窗口不可见 ==========
-- 排查结论（2026-08-01）：开机后 sketchybar 在会话开始 ~4s 创建 bar 窗口，撞上
-- 外接显示器初始化风暴，原生窗口不可见；Lua hidden 链路无异常（stderr 无报错、
-- 无门控超时日志），手动 --reload 在风暴平息后重建窗口即恢复（与 wake 重建同族）。
-- 这里把手动操作自动化：开机 120s 内加载配置时，延时 20s 自 reload 一次。
-- marker 以 boot epoch 命名：自 reload 引发的二次加载会命中已有 marker，不会循环排程。
local boot_f = io.popen("sysctl -n kern.boottime 2>/dev/null")
local boot_epoch = tonumber(boot_f and boot_f:read("*a") or "")
if boot_f then
	boot_f:close()
end
if boot_epoch and (os.time() - boot_epoch) < 120 then
	local marker = require("helpers.utils").tmp_path("sketchybar_boot_selfheal." .. boot_epoch)
	local mf = io.open(marker, "r")
	if mf then
		mf:close() -- 本次开机已排程（含自愈 reload 的二次加载）
	else
		local wf = io.open(marker, "w")
		if wf then
			wf:write(tostring(os.time()))
			wf:close()
		end
		io.stderr:write(os.date("sketchybar: boot self-heal scheduled at %H:%M:%S (reload in 20s)\n"))
		sbar.delay(20, function()
			sbar.exec("/opt/homebrew/bin/sketchybar --reload", function() end)
		end)
	end
end

-- 启动事件循环（必须！否则所有回调函数不会执行）
sbar.event_loop()
