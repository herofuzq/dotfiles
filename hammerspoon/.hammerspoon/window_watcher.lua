-- 窗口/应用变化监听 → 通知 sketchybar 更新工作区显示
-- 触发 event: space_windows_change（由 sketchybar spaces.lua 订阅）
--
-- 注意：watcher 必须用全局变量持有，否则会被 Lua GC 回收（Hammerspoon #681）

local DEBOUNCE_MS = 50
local debounceTimer = nil

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
	local task = hs.task.new(SKETCHYBAR_BIN, function(exitCode, _, stderr)
		if exitCode ~= 0 then
			print("[window_watcher] sketchybar trigger 失败: " .. tostring(stderr or exitCode))
		end
	end, {"--trigger", name})
	if task then
		local ok, started = pcall(function() return task:start() end)
		if ok and started then return end
	end
	print("[window_watcher] 无法启动 sketchybar trigger")
end

local function notify()
	if debounceTimer then debounceTimer:stop() end
	debounceTimer = hs.timer.doAfter(DEBOUNCE_MS / 1000, function()
		debounceTimer = nil
		fireSketchybarTrigger("space_windows_change")
	end)
end

-- 窗口变化（用默认 filter）
-- 注：原订阅 windowNotVisible（噪音大：minimize/hide/occlusion 都会触发），已移除

_windowWatcher_filter = hs.window.filter.new()
_windowWatcher_filter:rejectApp("iStat Menus")

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
