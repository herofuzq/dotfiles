-- BetterTouchTool action bridge.
-- Hammerspoon decides which window is eligible; BTT only executes the action.

local command = require("command")

local OSASCRIPT = "/usr/bin/osascript"
local JXA_TRIGGER_ACTION = [[
function run(argv) {
  const btt = Application("BetterTouchTool");
  btt.trigger_action(argv[0]);
  return "ok";
}
]]

local M = {}
local actionQueue = {}
local actionRunning = false

local function actionJSON(windowID, bundleID, actionType)
	local additional = {
		BTTActionPinOnTopWindowMode = 1,
		BTTActionPinOnTopWindowID = windowID,
		BTTActionPinOnTopOnlyChangeFocusOnClick = false,
	}
	if bundleID and bundleID ~= "" then
		additional.BTTActionPinOnTopWindowBelongsToApp = bundleID
	end
	return hs.json.encode({
		BTTPredefinedActionType = actionType,
		BTTAdditionalActionData = additional,
	})
end

local pump

local function runPinAction(item)
	local started = command.start(OSASCRIPT, {
		"-l",
		"JavaScript",
		"-e",
		JXA_TRIGGER_ACTION,
		actionJSON(item.windowID, item.bundleID, item.actionType),
	}, function(exitCode, stdout, stderr)
		actionRunning = false
		if item.callback then
			item.callback(exitCode == 0, stderr ~= "" and stderr or stdout)
		end
		pump()
	end)

	if not started then
		actionRunning = false
		if item.callback then
			item.callback(false, "BTT task did not start")
		end
		pump()
	end
end

pump = function()
	if actionRunning then
		return
	end
	local item = table.remove(actionQueue, 1)
	if not item then
		return
	end
	if item.shouldRun and not item.shouldRun() then
		if item.callback then
			item.callback(false, "stale BTT action skipped")
		end
		pump()
		return
	end
	actionRunning = true
	runPinAction(item)
end

local function enqueue(windowID, bundleID, actionType, shouldRun, callback)
	windowID = tonumber(windowID)
	if not windowID then
		if callback then
			callback(false, "invalid window id")
		end
		return false
	end
	table.insert(actionQueue, {
		windowID = windowID,
		bundleID = bundleID,
		actionType = actionType,
		shouldRun = shouldRun,
		callback = callback,
	})
	pump()
	return true
end

function M.pinWindow(windowID, bundleID, shouldRun, callback)
	return enqueue(windowID, bundleID, 402, shouldRun, callback)
end

function M.unpinWindow(windowID, bundleID, shouldRun, callback)
	return enqueue(windowID, bundleID, 401, shouldRun, callback)
end

return M
