-- 窗口变化监听 → 浮窗安全区归位
-- AeroSpace subscribe 已接管 SketchyBar 刷新事件；这里只保留几何修正。
--
-- 注意：watcher 必须用全局变量持有，否则会被 Lua GC 回收（Hammerspoon #681）

local CREATED_PLACEMENT_DELAY = 0.30
local CREATED_PLACEMENT_RETRY_DELAY = 0.20
local CREATED_PLACEMENT_MAX_ATTEMPTS = 6
local RESCUE_MOVE_DELAY = 0.08
local TOP_GUARD_HEIGHT = 34
local VISIBLE_FRAME_PADDING = 4
local MIN_RESCUE_WIDTH = 220
local MIN_RESCUE_HEIGHT = 120
local RESCUE_ANIMATION_DURATION = 0.20
local rescueTimers = {}
local createdPlacementTimers = {}
local command = require("command")
local SKIP_BUNDLE_IDS = {
	["pl.maketheweb.cleanshotx"] = true,
}

local function safeTopForWindow(window)
	local screen = window and window:screen()
	if not screen then
		return nil
	end
	local visible = screen:frame()
	local full = screen:fullFrame()
	return math.max(visible.y + VISIBLE_FRAME_PADDING, full.y + TOP_GUARD_HEIGHT)
end

local function centerFrameInSafeArea(window, frame, safeTop)
	local visible = window:screen():frame()
	local safeBottom = visible.y + visible.h
	local safeHeight = math.max(0, safeBottom - safeTop)

	frame.x = visible.x + math.max(0, (visible.w - frame.w) / 2)
	frame.y = safeTop + math.max(0, (safeHeight - frame.h) / 2)
	return frame
end

local function windowBundleID(window)
	local okApp, app = pcall(function()
		return window and window:application()
	end)
	if not okApp or not app then
		return nil
	end

	local okBundle, bundleID = pcall(function()
		return app:bundleID()
	end)
	if okBundle and bundleID and bundleID ~= "" then
		return bundleID
	end
	return nil
end

local function isPlaceableWindow(window)
	if not window or not window:isStandard() or window:isFullScreen() then
		return false
	end
	if SKIP_BUNDLE_IDS[windowBundleID(window)] then
		return false
	end

	local frame = window:frame()
	if frame.w < MIN_RESCUE_WIDTH or frame.h < MIN_RESCUE_HEIGHT then
		return false
	end
	return true, frame
end

local function centerWindowInSafeArea(window)
	local ok, frame = isPlaceableWindow(window)
	if not ok then
		return
	end

	local safeTop = safeTopForWindow(window)
	if safeTop then
		frame = centerFrameInSafeArea(window, frame, safeTop)
		window:setFrame(frame, RESCUE_ANIMATION_DURATION)
	end
end

local function rescueTopOverlap(window)
	local ok, frame = isPlaceableWindow(window)
	if not ok then
		return
	end

	local safeTop = safeTopForWindow(window)
	if safeTop and frame.y + 1 < safeTop then
		frame = centerFrameInSafeArea(window, frame, safeTop)
		window:setFrame(frame, RESCUE_ANIMATION_DURATION)
	end
end

local function aerospaceWindowIsFloating(stdout, windowID)
	local ok, windows = pcall(hs.json.decode, stdout or "")
	if not ok or type(windows) ~= "table" then
		return false
	end

	for _, item in ipairs(windows) do
		if tonumber(item["window-id"]) == tonumber(windowID) then
			return item["window-parent-container-layout"] == "floating"
				or item["window-layout"] == "floating"
				or item.layout == "floating"
				or item["is-floating"] == true
				or item.floating == true
		end
	end
	return false
end

local function createdWindowQueryArgs(window)
	local args = { "list-windows", "--workspace", "focused", "--format", "%{window-id}%{window-layout}", "--json" }
	local bundleID = windowBundleID(window)
	if bundleID then
		args[#args + 1] = "--app-bundle-id"
		args[#args + 1] = bundleID
	end
	return args
end

local scheduleCreatedPlacement

local function placeCreatedWindow(window, windowID, attempt)
	attempt = attempt or 1
	local started = command.aerospace(createdWindowQueryArgs(window), function(exitCode, stdout)
		local ok, err = pcall(function()
			if exitCode == 0 and aerospaceWindowIsFloating(stdout, windowID) then
				centerWindowInSafeArea(window)
			elseif attempt < CREATED_PLACEMENT_MAX_ATTEMPTS then
				scheduleCreatedPlacement(window, CREATED_PLACEMENT_RETRY_DELAY, attempt + 1)
			else
				rescueTopOverlap(window)
			end
		end)
		if not ok then
			print("[window_watcher] created window placement 失败: " .. tostring(err))
		end
	end)
	if not started then
		rescueTopOverlap(window)
	end
end

scheduleCreatedPlacement = function(window, delay, attempt)
	local windowID = window and window:id()
	if not windowID then
		return
	end
	if createdPlacementTimers[windowID] then
		createdPlacementTimers[windowID]:stop()
	end
	createdPlacementTimers[windowID] = hs.timer.doAfter(delay, function()
		createdPlacementTimers[windowID] = nil
		local ok, err = pcall(placeCreatedWindow, window, windowID, attempt)
		if not ok then
			print("[window_watcher] schedule created placement 失败: " .. tostring(err))
		end
	end)
end

local function scheduleTopRescue(window, delay)
	local windowID = window and window:id()
	if not windowID then
		return
	end
	if rescueTimers[windowID] then
		rescueTimers[windowID]:stop()
	end
	rescueTimers[windowID] = hs.timer.doAfter(delay, function()
		rescueTimers[windowID] = nil
		local ok, err = pcall(rescueTopOverlap, window)
		if not ok then
			print("[window_watcher] top safe-area rescue 失败: " .. tostring(err))
		end
	end)
end

local function notify(window, _, event)
	if event == hs.window.filter.windowFocused then
		scheduleTopRescue(window, RESCUE_MOVE_DELAY)
		return
	end
	if event == hs.window.filter.windowCreated then
		scheduleCreatedPlacement(window, CREATED_PLACEMENT_DELAY)
		return
	end
	if event == hs.window.filter.windowMoved then
		scheduleTopRescue(window, RESCUE_MOVE_DELAY)
	end
end

-- 窗口变化（用默认 filter）
-- 注：原订阅 windowNotVisible（噪音大：minimize/hide/occlusion 都会触发），已移除。

_windowWatcher_filter = hs.window.filter.new()
_windowWatcher_filter:rejectApp("iStat Menus")

local windowEvents = {
	hs.window.filter.windowCreated,
	hs.window.filter.windowFocused,
}
if hs.window.filter.windowMoved then
	table.insert(windowEvents, hs.window.filter.windowMoved)
end

_windowWatcher_filter:subscribe(windowEvents, notify)

print("[window_watcher] top safe-area rescue + new floating center")
