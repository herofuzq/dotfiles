local M = {}

local WECHAT_SOURCE_PATTERN = "^com%.tencent%.inputmethod%.wetype%."
local VOICE_WINDOW_OWNER = "微信输入法"
local VOICE_WINDOW_LAYER = 2147483629
local VOICE_WINDOW_WIDTH = 200
local VOICE_WINDOW_HEIGHT = 130

function M.isProbeTrigger(keyCode, flags, sourceID, leftCommandKeyCode)
	return keyCode == leftCommandKeyCode
		and type(sourceID) == "string"
		and sourceID:match(WECHAT_SOURCE_PATTERN) ~= nil
		and flags
		and flags.cmd == true
		and not flags.ctrl
		and not flags.alt
		and not flags.shift
end

function M.isVoiceWindow(window)
	local bounds = window and window.kCGWindowBounds
	return window ~= nil
		and window.kCGWindowOwnerName == VOICE_WINDOW_OWNER
		and window.kCGWindowIsOnscreen == true
		and window.kCGWindowLayer == VOICE_WINDOW_LAYER
		and bounds ~= nil
		and bounds.Width == VOICE_WINDOW_WIDTH
		and bounds.Height == VOICE_WINDOW_HEIGHT
end

function M.probeAction(voiceActive, voiceWindowVisible)
	if not voiceActive and voiceWindowVisible then return "start" end
	if voiceActive and not voiceWindowVisible then return "finish" end
	return nil
end

function M.shouldShowHud(voiceActive, stateIsChinese, alternateSourceActive)
	return voiceActive or (stateIsChinese and alternateSourceActive)
end

return M
