-- AeroSpace floating window -> BetterTouchTool pin bridge
--
-- Hammerspoon owns observation and AeroSpace state matching. BetterTouchTool
-- only receives the exact window ID and executes the Pin action.

local command = require("command")
local btt = require("btt")
local pinState = require("floating_pin_state")

local CREATED_DELAY = 0.30
local RETRY_DELAYS = { 0.30, 0.50, 0.80 }
local PIN_AFTER_PLACEMENT_DELAY = 0.28
_floatingPinnedWindowIDs = _floatingPinnedWindowIDs or {}
local pinnedWindowIDs = _floatingPinnedWindowIDs
local scheduledTimers = {}
local pinTimers = {}
local SKIP_BUNDLE_IDS = {
	["pl.maketheweb.cleanshotx"] = true,
	["now.typeless.desktop"] = true,
}

local function isStandardWindow(window)
	local ok, standard = pcall(function()
		return window and window:isStandard()
	end)
	return ok and standard == true
end

local function bundleID(window)
	local ok, app = pcall(function()
		return window and window:application()
	end)
	if not ok or not app then
		return nil
	end

	local okBundle, id = pcall(function()
		return app:bundleID()
	end)
	if okBundle and id and id ~= "" then
		return id
	end
	return nil
end

local function isFloatingWindow(stdout, windowID)
	local ok, windows = pcall(hs.json.decode, stdout or "")
	if not ok or type(windows) ~= "table" then
		return false
	end

	for _, item in ipairs(windows) do
		if tonumber(item["window-id"]) == tonumber(windowID) then
			return item["window-layout"] == "floating"
				or item["window-parent-container-layout"] == "floating"
		end
	end
	return false
end

local function pinFloatingWindow(window, windowID)
	if not pinState.isEnabled() then
		return
	end
	if pinnedWindowIDs[windowID] then
		return
	end

	local started = btt.pinWindow(windowID, function(ok, detail)
		if ok then
			pinnedWindowIDs[windowID] = true
			print("[floating_level] BTT pinned floating window " .. tostring(windowID))
		else
			print("[floating_level] BTT pin failed for " .. tostring(windowID) .. ": " .. tostring(detail))
		end
	end)
	if not started then
		print("[floating_level] BTT task did not start for " .. tostring(windowID))
	end
end

_floatingLevelUnpinAll = function()
	for windowID in pairs(pinnedWindowIDs) do
		local started = btt.unpinWindow(windowID, function(ok, detail)
			if ok then
				pinnedWindowIDs[windowID] = nil
				print("[floating_level] BTT unpinned window " .. tostring(windowID))
			else
				print("[floating_level] BTT unpin failed for " .. tostring(windowID) .. ": " .. tostring(detail))
			end
		end)
		if not started then
			print("[floating_level] BTT unpin task did not start for " .. tostring(windowID))
		end
	end
end

local queryWindow

local function schedulePinAfterPlacement(window, windowID)
	if not pinState.isEnabled() then
		return
	end
	if pinTimers[windowID] then
		pinTimers[windowID]:stop()
	end

	pinTimers[windowID] = hs.timer.doAfter(PIN_AFTER_PLACEMENT_DELAY, function()
		pinTimers[windowID] = nil
		if not pinState.isEnabled() then
			return
		end
		local currentWindow = hs.window(windowID) or window
		if not currentWindow then
			return
		end

		-- Re-query after the center animation settles so a stale floating result
		-- cannot pin a window that moved workspace or changed layout meanwhile.
		queryWindow(currentWindow, function(floating)
			if floating then
				pinFloatingWindow(currentWindow, windowID)
			end
		end)
	end)
end

queryWindow = function(window, callback)
	if not isStandardWindow(window) then
		return false
	end

	local windowID = window:id()
	if not windowID then
		return false
	end
	if SKIP_BUNDLE_IDS[bundleID(window)] then
		return false
	end

	local args = {
		"list-windows",
		"--workspace",
		"focused",
		"--format",
		"%{window-id}%{window-layout}",
		"--json",
	}
	local started = command.aerospace(args, function(exitCode, stdout)
		local floating = exitCode == 0 and isFloatingWindow(stdout, windowID)
		callback(floating)
	end)
	return started == true
end

local function scheduleWindow(window, delay, attempt)
	if not pinState.isEnabled() then
		return
	end
	attempt = attempt or 1
	local windowID = window and window:id()
	if not windowID then
		return
	end
	if scheduledTimers[windowID] then
		scheduledTimers[windowID]:stop()
	end

	scheduledTimers[windowID] = hs.timer.doAfter(delay, function()
		scheduledTimers[windowID] = nil
		if not pinState.isEnabled() then
			return
		end
		local started = queryWindow(window, function(floating)
			if floating then
				schedulePinAfterPlacement(window, windowID)
			elseif attempt < #RETRY_DELAYS + 1 then
				scheduleWindow(window, RETRY_DELAYS[attempt], attempt + 1)
			end
		end)
		if not started and attempt < #RETRY_DELAYS + 1 then
			scheduleWindow(window, RETRY_DELAYS[attempt], attempt + 1)
		end
	end)
end

local function handleWindow(window)
	if pinState.isEnabled() and isStandardWindow(window) then
		scheduleWindow(window, CREATED_DELAY)
	end
end

_floatingLevelReconcile = function()
	if not pinState.isEnabled() then
		return
	end
	for _, window in ipairs(hs.window.allWindows()) do
		if isStandardWindow(window) then
			scheduleWindow(window, CREATED_DELAY)
		end
	end
end

-- Keep the filter alive globally; otherwise Hammerspoon may collect it.
_floatingLevel_filter = hs.window.filter.new()
_floatingLevel_filter:subscribe({
	hs.window.filter.windowCreated,
	hs.window.filter.windowVisible,
}, function(window, _, event)
	if event == hs.window.filter.windowCreated then
		handleWindow(window)
		return
	end
	if event == hs.window.filter.windowVisible then
		handleWindow(window)
	end
end)

-- Reconcile windows that already existed when Hammerspoon reloaded.
_floatingLevelReconcile()

print("[floating_level] AeroSpace floating windows use BTT Pin by window ID")
