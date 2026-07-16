-- Hyper+P focuses floating windows in the current AeroSpace workspace.
-- It deliberately does not change window levels, move workspaces, or call BTT.

local command = require("command")
local notification = require("notification_hud")

local SKIP_BUNDLE_IDS = {
	["pl.maketheweb.cleanshotx"] = true,
	["now.typeless.desktop"] = true,
}

local WINDOW_FORMAT = "%{window-id}|%{app-bundle-id}|%{workspace}|%{window-layout}|%{window-parent-container-layout}"
local lastFocusedID = nil
local lastFocusedWorkspace = nil

local function cleanupLegacyPinRuntime()
	-- hs.reload() can retain globals from the previous configuration. Remove
	-- the old watcher and hotkey before installing the focus-only behavior.
	if _floatingLevelUnpinAll then
		pcall(_floatingLevelUnpinAll)
		_floatingLevelUnpinAll = nil
	end
	if _floatingLevel_filter then
		pcall(function() _floatingLevel_filter:unsubscribeAll() end)
		_floatingLevel_filter = nil
	end
	if _floatingPinToggleHotkey then
		pcall(function() _floatingPinToggleHotkey:delete() end)
		_floatingPinToggleHotkey = nil
	end
end

cleanupLegacyPinRuntime()

local function isEligible(record, workspace)
	return record
		and record.workspace == workspace
		and record.standard == true
		and record.floating == true
		and not SKIP_BUNDLE_IDS[record.bundleID]
end

local function selectNext(records, workspace, currentID)
	local eligible = {}
	for _, record in ipairs(records or {}) do
		if isEligible(record, workspace) then
			table.insert(eligible, record)
		end
	end
	table.sort(eligible, function(left, right)
		return left.id < right.id
	end)

	if #eligible == 0 then
		return nil
	end
	for index, record in ipairs(eligible) do
		if tonumber(record.id) == tonumber(currentID) then
			return eligible[(index % #eligible) + 1]
		end
	end
	return eligible[1]
end

_floatingFocusSelect = selectNext

local function trim(value)
	return (value or ""):match("^%s*(.-)%s*$")
end

local function parseWindowRecords(stdout)
	local records = {}
	for line in (stdout or ""):gmatch("[^\r\n]+") do
		local id, bundleID, workspace, layout, parentLayout = line:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
		if id then
			local window = hs.window(tonumber(id))
			local standard = false
			if window then
				local ok, value = pcall(function() return window:isStandard() end)
				standard = ok and value == true
			end
			table.insert(records, {
				id = tonumber(id),
				bundleID = trim(bundleID),
				workspace = trim(workspace),
				floating = trim(layout) == "floating" or trim(parentLayout) == "floating",
				standard = standard,
			})
		end
	end
	return records
end

local function focusedFloatingWindow()
	local started = command.aerospace({
		"list-windows",
		"--workspace", "focused",
		"--format", WINDOW_FORMAT,
	}, function(exitCode, stdout)
		if exitCode ~= 0 then
			notification.show("无法读取浮动窗口", "warning", 0.8)
			return
		end

		local records = parseWindowRecords(stdout)
		local workspace = records[1] and records[1].workspace or nil
		local current = hs.window.frontmostWindow()
		local currentID = current and current:id() or nil
		if workspace and lastFocusedWorkspace == workspace and lastFocusedID then
			currentID = currentID or lastFocusedID
		end
		local target = selectNext(records, workspace, currentID)
		if not target then
			notification.show("当前工作区没有浮动窗口", "neutral", 0.8)
			return
		end

		local window = hs.window(target.id)
		if not window then
			notification.show("浮动窗口已经关闭", "warning", 0.8)
			return
		end
		local ok = pcall(function() window:focus() end)
		if not ok then
			notification.show("无法聚焦浮动窗口", "warning", 0.8)
			return
		end
		lastFocusedID = target.id
		lastFocusedWorkspace = workspace
	end)
	if not started then
		notification.show("无法启动 AeroSpace 查询", "warning", 0.8)
	end
end

if _floatingFocusHotkey then
	_floatingFocusHotkey:delete()
end

_floatingFocusHotkey = hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "p", focusedFloatingWindow)

print("[floating_focus] Hyper+P focuses current-workspace floating windows")

return {
	focus = focusedFloatingWindow,
}
