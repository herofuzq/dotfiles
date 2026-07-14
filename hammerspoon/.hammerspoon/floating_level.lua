-- AeroSpace floating window -> BetterTouchTool pin bridge.
-- Hammerspoon owns eligibility and active ownership; BTT only executes
-- serialized actions for the exact window and application.

local command = require("command")
local btt = require("btt")
local pinState = require("floating_pin_state")

local CREATED_DELAY = 0.30
local RETRY_DELAYS = { 0.30, 0.50, 0.80 }
local PIN_AFTER_PLACEMENT_DELAY = 0.28
local PIN_HANDOFF_DELAY = 0.10

-- Keep these tables across hs.reload(), but replace stale timers and records.
_floatingPinRecords = _floatingPinRecords or {}
_floatingActiveOwners = _floatingActiveOwners or {}
_floatingDesiredOwners = _floatingDesiredOwners or {}
_floatingWindowGenerations = _floatingWindowGenerations or {}
_floatingPinStack = _floatingPinStack or {}
_floatingPinnedWindowIDs = _floatingPinnedWindowIDs or {}

local records = _floatingPinRecords
local pinStack = _floatingPinStack
local generations = _floatingWindowGenerations
local legacyPinnedIDs = _floatingPinnedWindowIDs
local scheduledTimers = {}
local pinTimers = {}
local handoffTimers = {}

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

local function getBundleID(window)
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

local function nextGeneration(windowID)
	generations[windowID] = (generations[windowID] or 0) + 1
	return generations[windowID]
end

local function currentGeneration(windowID)
	return generations[windowID] or 1
end

local function isCurrentRecord(record)
	return record
		and records[record.id] == record
		and generations[record.id] == record.generation
end

local function stackIndex(windowID)
	for index, id in ipairs(pinStack) do
		if id == windowID then return index end
	end
	return nil
end

local function removeFromStack(windowID)
	local index = stackIndex(windowID)
	if index then
		table.remove(pinStack, index)
		if records[windowID] then records[windowID].inStack = false end
	end
	return index ~= nil
end

local function pushToStack(record)
	if not record or stackIndex(record.id) then return false end
	table.insert(pinStack, record.id)
	record.inStack = true
	return true
end

local function pruneMissingStackWindows()
	for index = #pinStack, 1, -1 do
		local windowID = pinStack[index]
		if not records[windowID] or not hs.window(windowID) then
			table.remove(pinStack, index)
			if handoffTimers[windowID] then handoffTimers[windowID]:stop(); handoffTimers[windowID] = nil end
			legacyPinnedIDs[windowID] = nil
			if records[windowID] then
				nextGeneration(windowID)
				records[windowID] = nil
			end
		end
	end
end

local function recordFor(window, createGeneration)
	if not isStandardWindow(window) then
		return nil
	end
	local windowID = window:id()
	local appID = getBundleID(window)
	if not windowID or not appID or SKIP_BUNDLE_IDS[appID] then
		return nil
	end
	local record = records[windowID]
	if not record then
		record = {
			id = windowID,
			bundleID = appID,
			generation = createGeneration and nextGeneration(windowID) or currentGeneration(windowID),
			state = "idle",
		}
		records[windowID] = record
	elseif record.bundleID ~= appID then
		record.generation = nextGeneration(windowID)
		record.bundleID = appID
		record.state = "idle"
	end
	return record
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

local function queryWindow(window, callback)
	local record = recordFor(window, false)
	if not record then
		return false
	end
	local args = {
		"list-windows", "--workspace", "focused",
		"--format", "%{window-id}%{window-layout}", "--json",
	}
	return command.aerospace(args, function(exitCode, stdout)
		local floating = exitCode == 0 and isFloatingWindow(stdout, record.id)
		record.floating = floating
		callback(floating, record)
	end) == true
end

local function validPinTarget(record)
	if not pinState.isEnabled() or not isCurrentRecord(record) then
		return false
	end
	if pinStack[#pinStack] ~= record.id then
		return false
	end
	if record.floating ~= true then
		return false
	end
	local window = hs.window(record.id)
	return window ~= nil
		and isStandardWindow(window)
		and getBundleID(window) == record.bundleID
end

local reconcileStack

local function enqueueUnpin(record, callback)
	if not record then
		if callback then callback(false, "missing record") end
		return false
	end
	if record.state == "unpinning" then
		return true
	end
	record.state = "unpinning"
	return btt.unpinWindow(record.id, record.bundleID, function()
		return true
	end, function(ok, detail)
		legacyPinnedIDs[record.id] = nil
		if record.state == "unpinning" then
			record.state = "idle"
		end
		if not ok then
			print("[floating_level] BTT unpin failed for " .. tostring(record.id) .. ": " .. tostring(detail))
		end
		if callback then callback(ok, detail) end
		if reconcileStack then reconcileStack() end
	end)
end

local function unpinLegacyWindow(windowID)
	return btt.unpinWindow(windowID, nil, function()
		return true
	end, function(ok, detail)
		if ok then
			legacyPinnedIDs[windowID] = nil
		else
			print("[floating_level] BTT legacy unpin failed for " .. tostring(windowID) .. ": " .. tostring(detail))
		end
		if reconcileStack then reconcileStack() end
	end)
end

local function requestPin(record)
	if not validPinTarget(record) then
		return false
	end
	if record.state == "pinning" or record.state == "pinned" then
		return true
	end
	record.state = "pinning"
	return btt.pinWindow(record.id, record.bundleID, function()
		return validPinTarget(record) and record.state == "pinning"
	end, function(ok, detail)
		local stillWanted = validPinTarget(record)
		if ok and stillWanted then
			record.state = "pinned"
			legacyPinnedIDs[record.id] = true
			print("[floating_level] BTT pinned " .. record.bundleID .. " window " .. tostring(record.id))
		elseif ok then
			-- The action may have started just before focus/workspace changed.
			record.state = "idle"
			enqueueUnpin(record)
		else
			record.state = "idle"
			print("[floating_level] BTT pin skipped/failed for " .. tostring(record.id) .. ": " .. tostring(detail))
		end
		reconcileStack()
	end)
end

reconcileStack = function()
	pruneMissingStackWindows()
	local topID = pinStack[#pinStack]
	local topRecord = records[topID]
	if not topRecord then
		for windowID in pairs(legacyPinnedIDs) do
			unpinLegacyWindow(windowID)
		end
		return
	end
	if topRecord.handoffPending then return end

	-- Pin the new top first. Only after BTT confirms it do we release older
	-- windows, avoiding a visible gap where the old window owns the front.
	if validPinTarget(topRecord) and topRecord.state ~= "pinned" then
		requestPin(topRecord)
		return
	end
	if topRecord.state == "pinning" or topRecord.state == "unpinning" then return end

	-- Older windows remain in the stack but must stay unpinned until the
	-- windows above them close.
	for windowID, record in pairs(records) do
		if windowID ~= topID and (record.state == "pinning" or record.state == "unpinning") then
			return
		end
		if windowID ~= topID and record.state == "pinned" then
			enqueueUnpin(record)
			return
		end
	end
	for windowID in pairs(legacyPinnedIDs) do
		if windowID ~= topID and not records[windowID] then
			unpinLegacyWindow(windowID)
			return
		end
	end
	if validPinTarget(topRecord) then requestPin(topRecord) end
end

local function promoteOwner(record)
	if not record then return end
	if pushToStack(record) then
		local window = hs.window(record.id)
		if window then pcall(function() window:raise() end) end
		record.handoffPending = true
		if handoffTimers[record.id] then handoffTimers[record.id]:stop() end
		handoffTimers[record.id] = hs.timer.doAfter(PIN_HANDOFF_DELAY, function()
			handoffTimers[record.id] = nil
			if isCurrentRecord(record) then
				record.handoffPending = false
				reconcileStack()
			end
		end)
		print("[floating_level] window " .. tostring(record.id) .. " pushed to Pin stack")
	end
	reconcileStack()
end

local function schedulePinAfterPlacement(window, record, promote)
	if not pinState.isEnabled() or not record then return end
	local id = record.id
	if pinTimers[id] then pinTimers[id]:stop() end
	local generation = record.generation
	pinTimers[id] = hs.timer.doAfter(PIN_AFTER_PLACEMENT_DELAY, function()
		pinTimers[id] = nil
		if not isCurrentRecord(record) or record.generation ~= generation then return end
		queryWindow(hs.window(id) or window, function(floating, currentRecord)
			if floating and isCurrentRecord(currentRecord) then
				if promote then
					promoteOwner(currentRecord)
				end
				-- Focus/visibility never changes the stack, but a reload or a
				-- delayed callback may still need to restore its current top.
				reconcileStack()
			elseif not floating and stackIndex(currentRecord.id) then
				removeFromStack(currentRecord.id)
				enqueueUnpin(currentRecord)
				reconcileStack()
			end
		end)
	end)
end

local function scheduleWindow(window, delay, attempt, promote)
	if not pinState.isEnabled() then return end
	local record = recordFor(window, false)
	if not record then return end
	attempt = attempt or 1
	local id, generation = record.id, record.generation
	if scheduledTimers[id] then scheduledTimers[id]:stop() end
	scheduledTimers[id] = hs.timer.doAfter(delay, function()
		scheduledTimers[id] = nil
		if not pinState.isEnabled() or not isCurrentRecord(record) then return end
		local started = queryWindow(hs.window(id) or window, function(floating, currentRecord)
			if not isCurrentRecord(currentRecord) or currentRecord.generation ~= generation then return end
			if floating then
				if promote then promoteOwner(currentRecord) end
				schedulePinAfterPlacement(window, currentRecord, promote)
			elseif stackIndex(currentRecord.id) then
				removeFromStack(currentRecord.id)
				enqueueUnpin(currentRecord)
				reconcileStack()
			elseif attempt < #RETRY_DELAYS + 1 then
				scheduleWindow(window, RETRY_DELAYS[attempt], attempt + 1, promote)
			end
		end)
		if not started and attempt < #RETRY_DELAYS + 1 then
			scheduleWindow(window, RETRY_DELAYS[attempt], attempt + 1, promote)
		end
	end)
end

local function handleWindow(window, promote, attempt)
	attempt = attempt or 1
	if not isStandardWindow(window) then
		if attempt < #RETRY_DELAYS + 1 then
			hs.timer.doAfter(RETRY_DELAYS[attempt], function()
				handleWindow(window, promote, attempt + 1)
			end)
		end
		return
	end
	if not SKIP_BUNDLE_IDS[getBundleID(window)] then
		local windowID = window:id()
		if not promote and scheduledTimers[windowID] then return end
		recordFor(window, true)
		scheduleWindow(window, CREATED_DELAY, 1, promote)
	end
end

-- Enabling the feature must also adopt float windows that already existed
-- before the toggle. Query them serially so their adoption order is stable.
local function adoptExistingFloatingWindows()
	local candidates = {}
	for _, window in ipairs(hs.window.allWindows()) do
		if isStandardWindow(window) and not SKIP_BUNDLE_IDS[getBundleID(window)] then
			table.insert(candidates, window)
		end
	end
	table.sort(candidates, function(left, right)
		return (left:id() or 0) < (right:id() or 0)
	end)

	local index = 1
	local adoptNext
	adoptNext = function()
		local window = candidates[index]
		index = index + 1
		if not window then
			reconcileStack()
			return
		end
		recordFor(window, true)
		local started = queryWindow(window, function(floating, record)
			if floating then promoteOwner(record) end
			adoptNext()
		end)
		if not started then adoptNext() end
	end
	adoptNext()
end

_floatingLevelUnpinAll = function()
	-- Invalidate all future Pin actions before releasing the stack.
	for index = #pinStack, 1, -1 do pinStack[index] = nil end
	for _, record in pairs(records) do
		if record.state == "pinned" or record.state == "pinning" or record.state == "unpinning" then
			enqueueUnpin(record)
		end
	end
	for windowID in pairs(legacyPinnedIDs) do
		if not records[windowID] then unpinLegacyWindow(windowID) end
	end
end

_floatingLevelReconcile = function(adoptExisting)
	if not pinState.isEnabled() then return end
	local focused = hs.window.frontmostWindow()
	if focused then handleWindow(focused, false) end
	for _, window in ipairs(hs.window.allWindows()) do
		if window ~= focused and isStandardWindow(window) then
			handleWindow(window, false)
		end
	end
	if adoptExisting then adoptExistingFloatingWindows() end
end

_floatingLevel_filter = hs.window.filter.new()
_floatingLevel_filter:subscribe({
	hs.window.filter.windowCreated,
	hs.window.filter.windowVisible,
	hs.window.filter.windowFocused,
	hs.window.filter.windowDestroyed,
}, function(window, _, event)
	local id = window and window:id()
	if event == hs.window.filter.windowDestroyed then
		if id then
			if scheduledTimers[id] then scheduledTimers[id]:stop(); scheduledTimers[id] = nil end
			if pinTimers[id] then pinTimers[id]:stop(); pinTimers[id] = nil end
			if handoffTimers[id] then handoffTimers[id]:stop(); handoffTimers[id] = nil end
			local record = records[id]
			if record then
				nextGeneration(id)
				local wasTop = pinStack[#pinStack] == id
				removeFromStack(id)
				legacyPinnedIDs[id] = nil
				records[id] = nil
				if wasTop then
					local previousID = pinStack[#pinStack]
					local previous = records[previousID]
					if previous then previous.state = "idle" end
				end
				reconcileStack()
			end
		end
		return
	end
	if event == hs.window.filter.windowFocused then
		-- Focus never reorders a known window. Some apps expose a newly
		-- created window only through windowFocused, so an unknown window is
		-- treated as a creation fallback.
		local known = id and records[id] ~= nil
		handleWindow(window, not known)
	else
		-- Some apps expose a new window through windowVisible without a
		-- reliable windowCreated event. The stack de-duplicates repeats.
		handleWindow(window, true)
	end
end)

_floatingLevelReconcile()
print("[floating_level] serialized BTT pin bridge with creation-order Pin stack")
