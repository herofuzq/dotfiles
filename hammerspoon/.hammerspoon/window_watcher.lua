-- 窗口/应用变化监听 → 通知 sketchybar 更新工作区显示
-- 触发窗口清单变化与焦点变化事件（由 sketchybar spaces.lua 订阅）
--
-- 注意：watcher 必须用全局变量持有，否则会被 Lua GC 回收（Hammerspoon #681）

local CREATE_DELAY = 0.25
local DESTROY_DELAY = 0.05
local debounceTimer = nil
local command = require("command")

-- 每次创建新 hs.task 对象。hs.task 不能在前一个未结束时复用 start()，
-- 否则会刷 "task already launched" 警告并占用事件循环。
local function fireSketchybarTrigger(name, fields)
	local started, err = command.triggerSketchybar(name, function(exitCode, _, stderr)
		if exitCode ~= 0 then
			print("[window_watcher] sketchybar trigger 失败: " .. tostring(stderr or exitCode))
		end
	end, fields)
	if not started then
		print("[window_watcher] 无法启动 sketchybar trigger: " .. tostring(err))
	end
end

local function scheduleNotify(delay)
	if debounceTimer then debounceTimer:stop() end
	debounceTimer = hs.timer.doAfter(delay, function()
		debounceTimer = nil
		fireSketchybarTrigger("space_windows_change")
	end)
end

local function notify(window, _, event)
	if event == hs.window.filter.windowFocused then
		local windowID = window and window:id()
		if windowID then
			fireSketchybarTrigger("window_focus_change", { FOCUSED_WINDOW_ID = windowID })
		end
		return
	end
	local created = event == hs.window.filter.windowCreated
	scheduleNotify(created and CREATE_DELAY or DESTROY_DELAY)
end

-- 窗口变化（用默认 filter）
-- 注：原订阅 windowNotVisible（噪音大：minimize/hide/occlusion 都会触发），已移除

_windowWatcher_filter = hs.window.filter.new()
_windowWatcher_filter:rejectApp("iStat Menus")

_windowWatcher_filter:subscribe({
	hs.window.filter.windowCreated,
	hs.window.filter.windowDestroyed,
	hs.window.filter.windowFocused,
}, notify)

-- 某些菜单栏/工具类应用不会产生可见的 windowDestroyed，退出事件作为兜底。
_windowWatcher_app = hs.application.watcher.new(function(_, event)
	if event == hs.application.watcher.terminated then
		scheduleNotify(DESTROY_DELAY)
	end
end)
_windowWatcher_app:start()

print("[window_watcher] window topology + focused window → sketchybar cache events")
