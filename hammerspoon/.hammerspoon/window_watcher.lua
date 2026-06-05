-- 窗口/应用变化监听 → 通知 sketchybar 更新工作区显示
-- 触发 event: space_windows_change（由 sketchybar spaces.lua 订阅）
--
-- 注意：watcher 必须用全局变量持有，否则会被 Lua GC 回收（Hammerspoon #681）

local DEBOUNCE_MS = 50
local next_notify = 0

-- 动态查找 sketchybar 路径，避免每次 fork shell 解析 PATH
local function findSketchybar()
	local candidates = {"/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"}
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p, "mode") == "file" then return p end
	end
	return "sketchybar"  -- fallback to PATH
end
local SKETCHYBAR_BIN = findSketchybar()

-- 每次创建新 hs.task 对象。hs.task 不能在前一个未结束时复用 start()，
-- 否则会刷 "task already launched" 警告并占用事件循环。
local function fireSketchybarTrigger(name)
	local task = hs.task.new(SKETCHYBAR_BIN, nil, {"--trigger", name})
	if task then
		task:start()
	else
		-- 创建失败时 fallback 到 hs.execute（理论不应发生）
		hs.execute(SKETCHYBAR_BIN .. " --trigger " .. name, true)
	end
end

local function notify()
	local now = hs.timer.absoluteTime() / 1000000000
	if now < next_notify then
		return
	end
	next_notify = now + DEBOUNCE_MS / 1000
	fireSketchybarTrigger("space_windows_change")
end

-- 窗口变化（用默认 filter）
-- 注：原订阅 windowNotVisible（噪音大：minimize/hide/occlusion 都会触发），已移除
_windowWatcher_filter = hs.window.filter.default
_windowWatcher_filter:subscribe(hs.window.filter.windowCreated, notify)
_windowWatcher_filter:subscribe(hs.window.filter.windowFocused, notify)

-- cmd+q 退出应用
_windowWatcher_app = hs.application.watcher.new(function(_, event, _)
	if event == hs.application.watcher.terminated then
		notify()
	end
end)
_windowWatcher_app:start()

print("[window_watcher] windowCreated + windowFocused + app terminated → sketchybar")
