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

local function runPinAction(windowID, actionType, callback)
	windowID = tonumber(windowID)
	if not windowID then
		if callback then
			callback(false, "invalid window id")
		end
		return false
	end

	local action = hs.json.encode({
		BTTPredefinedActionType = actionType,
		BTTAdditionalActionData = {
			BTTActionPinOnTopWindowMode = 1,
			BTTActionPinOnTopWindowID = windowID,
			BTTActionPinOnTopOnlyChangeFocusOnClick = true,
		},
	})

	local started = command.start(OSASCRIPT, {
		"-l",
		"JavaScript",
		"-e",
		JXA_TRIGGER_ACTION,
		action,
	}, function(exitCode, stdout, stderr)
		if callback then
			callback(exitCode == 0, stderr ~= "" and stderr or stdout)
		end
	end)

	return started == true
end

function M.pinWindow(windowID, callback)
	return runPinAction(windowID, 402, callback)
end

function M.unpinWindow(windowID, callback)
	return runPinAction(windowID, 401, callback)
end

return M
