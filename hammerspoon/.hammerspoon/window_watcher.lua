-- 窗口/应用变化监听 → 通知 sketchybar 更新工作区显示
-- 与 sketchybar 侧 space_windows_change + front_app_switched 共同作用
--
-- 注意：watcher 必须用全局变量持有，否则会被 Lua GC 回收（Hammerspoon #681）

local DEBOUNCE_MS = 50
local next_notify = 0

local function notify()
	local now = hs.timer.absoluteTime() / 1000000000
	if now < next_notify then return end
	next_notify = now + DEBOUNCE_MS / 1000
	hs.execute("sketchybar --trigger space_windows_change", true)
end

-- 窗口变化（用默认 filter，不用 new(false)，确保 windowNotVisible 可用）
windowWatcher_filter = hs.window.filter.default
windowWatcher_filter:subscribe(hs.window.filter.windowCreated, notify)
windowWatcher_filter:subscribe(hs.window.filter.windowFocused, notify)
windowWatcher_filter:subscribe(hs.window.filter.windowNotVisible, notify)

-- cmd+q 退出应用
windowWatcher_app = hs.application.watcher.new(function(_, event, _)
	if event == hs.application.watcher.terminated then
		notify()
	end
end)
windowWatcher_app:start()

print("[window_watcher] windowCreated + windowFocused + app terminated → sketchybar")
