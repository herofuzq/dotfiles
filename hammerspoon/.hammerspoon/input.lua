-- ============================================================
-- 输入法切换 - macOS input source
-- 1 = 英文（ABC）, 2 = 中文（任意非 ABC 输入法）
-- 仅启用 ABC + 一个中文输入法时，“上一个输入源”切换最可靠。
-- ============================================================
local notification = require("notification_hud")
local wechatVoice = require("wechat_voice")
local EN = 1
local ZH = 2

local ABC_SRC = "com.apple.keylayout.ABC"
-- 微信输入法仅用于双 Command 语音适配；通用切换不依赖具体中文输入法。
local WECHAT_SRC = "com.tencent.inputmethod.wetype.pinyin"
local LEFT_COMMAND_KEYCODE = hs.keycodes.map.cmd or hs.keycodes.map.leftcmd or 55

local function hasModifier(rawFlags, mask)
	return math.floor(rawFlags / mask) % 2 == 1
end

local function readInputSourceShortcut()
	local home = os.getenv("HOME")
	local plist = home and hs.plist.read(home .. "/Library/Preferences/com.apple.symbolichotkeys.plist")
	local hotkeys = plist and plist.AppleSymbolicHotKeys
	local entry = hotkeys and (hotkeys["60"] or hotkeys[60])
	local parameters = entry and entry.value and entry.value.parameters
	if not entry or entry.enabled ~= true or type(parameters) ~= "table" then
		return nil, "系统未启用“选择上一个输入源”快捷键"
	end

	local keyCode = tonumber(parameters[2])
	local rawFlags = tonumber(parameters[3])
	if not keyCode or not rawFlags then
		return nil, "无法解析“选择上一个输入源”快捷键"
	end
	local key = hs.keycodes.map[keyCode]
	if type(key) ~= "string" then
		return nil, "无法识别“选择上一个输入源”的按键"
	end

	local modifiers = {}
	for _, item in ipairs({
		{ mask = 131072, name = "shift" },
		{ mask = 262144, name = "ctrl" },
		{ mask = 524288, name = "alt" },
		{ mask = 1048576, name = "cmd" },
		{ mask = 8388608, name = "fn" },
	}) do
		if hasModifier(rawFlags, item.mask) then
			modifiers[#modifiers + 1] = item.name
		end
	end
	return { key = key, modifiers = modifiers }
end

local _inputSourceShortcut, _inputSourceShortcutError = readInputSourceShortcut()
if not _inputSourceShortcut then
	print("[Input] " .. tostring(_inputSourceShortcutError))
end

local INPUT_SHORTCUT_MODIFIER_HOLD = 0.05
local INPUT_SHORTCUT_SPACE_HOLD = 0.10
-- watchdog 时长在创建时按 INPUT_SHORTCUT_SPACE_HOLD + SOURCE_VERIFY_DELAY + 此余量计算，
-- 因为 SOURCE_VERIFY_DELAY 的声明位置晚于这里的常量区。
local INPUT_SWITCH_WATCHDOG_MARGIN = 0.4

local function postShortcutKey(key, isDown, modifiers)
	local event = hs.eventtap.event.newKeyEvent(modifiers or {}, key, isDown)
	event:post()
end

-- 精确记录已按下的键：任何路径（重入替换、投递中途失败、watchdog 超时、reload/退出）
-- 都只补偿释放确实按下且尚未抬起的键，不无条件补发 key-up。
local _inputShortcutPressedModifiers = {}
local _inputShortcutKeyPressed = false

-- 同步释放所有记录为已按下的键：修饰键逆序释放，最后释放 Space。
-- 释放成功的键即时清除记录；失败的保留记录，留给后续路径重试。
local function releasePendingInputShortcut()
	if not _inputSourceShortcut then return end
	for index = #_inputShortcutPressedModifiers, 1, -1 do
		local modifier = _inputShortcutPressedModifiers[index]
		local ok, err = pcall(postShortcutKey, modifier, false)
		if ok then
			table.remove(_inputShortcutPressedModifiers, index)
		else
			print("[Input] 补偿释放输入源快捷键修饰键失败: " .. tostring(err))
		end
	end
	if _inputShortcutKeyPressed then
		local ok, err = pcall(postShortcutKey, _inputSourceShortcut.key, false)
		if ok then
			_inputShortcutKeyPressed = false
		else
			print("[Input] 补偿释放输入源快捷键主键失败: " .. tostring(err))
		end
	end
end

local function sendInputSourceShortcut(onComplete)
	if not _inputSourceShortcut then return false end
	local modifierReleaseError
	if _InputShortcutModifierTimer then
		_InputShortcutModifierTimer:stop()
		_InputShortcutModifierTimer = nil
	end
	if _InputShortcutKeyTimer then
		_InputShortcutKeyTimer:stop()
		_InputShortcutKeyTimer = nil
	end
	-- 替换旧事务时，先补发其已按下但尚未释放的键。
	releasePendingInputShortcut()

	-- 模拟系统可识别的短按：修饰键按下、Space 按下，先释放修饰键，再释放 Space。
	-- 每个 key-down 成功后才记录；投递中途抛错时立即补偿释放已按下的键再向上抛出。
	local postOk, postErr = pcall(function()
		for _, modifier in ipairs(_inputSourceShortcut.modifiers) do
			postShortcutKey(modifier, true)
			table.insert(_inputShortcutPressedModifiers, modifier)
		end
		-- 主键事件必须携带修饰标记，否则会被文本框当成普通空格。
		postShortcutKey(_inputSourceShortcut.key, true, _inputSourceShortcut.modifiers)
		_inputShortcutKeyPressed = true
	end)
	if not postOk then
		releasePendingInputShortcut()
		error(postErr, 0)
	end

	_InputShortcutModifierTimer = hs.timer.doAfter(INPUT_SHORTCUT_MODIFIER_HOLD, function()
		_InputShortcutModifierTimer = nil
		for index = #_inputShortcutPressedModifiers, 1, -1 do
			local modifier = _inputShortcutPressedModifiers[index]
			local ok, err = pcall(postShortcutKey, modifier, false)
			if ok then
				table.remove(_inputShortcutPressedModifiers, index)
			else
				modifierReleaseError = modifierReleaseError or err
				print("[Input] 释放输入源快捷键修饰键失败: " .. tostring(err))
			end
		end
	end)
	_InputShortcutKeyTimer = hs.timer.doAfter(INPUT_SHORTCUT_SPACE_HOLD, function()
		_InputShortcutKeyTimer = nil
		local ok, err = pcall(postShortcutKey, _inputSourceShortcut.key, false)
		if ok then
			_inputShortcutKeyPressed = false
		end
		if onComplete then onComplete(ok and not modifierReleaseError, err or modifierReleaseError) end
	end)
	return true
end

-- reload/退出会销毁 Lua 环境，pending timer 随之失效；shutdownCallback 是销毁前
-- 同步补发 key-up 的唯一可靠时机（文档要求回调内不做异步任务）。
hs.shutdownCallback = releasePendingInputShortcut

-- Fcitx5 旧后端保留，观察期内不删除，必要时可恢复。
--[[
local command = require("command")
local FCITX = command.find({
	"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote",
	"/opt/homebrew/bin/fcitx5-remote",
	"/usr/local/bin/fcitx5-remote",
}, "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote")
local MACISM_BIN = command.find({ "/opt/homebrew/bin/macism", "/usr/local/bin/macism" }, "macism")
local FCITX5_SRC = "org.fcitx.inputmethod.Fcitx5.zhHans"
local IM_ZH = "rime"
local IM_EN = "keyboard-us"
]]

local function isUsingWeChat()
	local id = hs.keycodes.currentSourceID()
	return id ~= nil and (
		id == WECHAT_SRC
			or id:match("^com%.tencent%.inputmethod%.wetype%.") ~= nil
	)
end

-- 内部状态只在查询或切换成功后更新，避免命令失败时误报。
local _zhState
local _toggled = 0
local _idleTimer = nil
local _switchInFlight = false
local _zhSwitchKeyBufferUntil = 0
local _zhBufferedKey = nil
local _replayingBufferedKey = false
local _zhBufferedTarget = nil
local _voiceInputActive = false
local _voiceActionTimer = nil
local _voiceWindowProbeTimer = nil
local stopVoiceWindowProbe

-- ============================================================
-- 空闲自动切换回英文
-- ============================================================
local IDLE_TIMEOUT = 10
local IDLE_TICK_INTERVAL = 1
local KEY_RATE_WINDOW = 60
-- 暂时关闭中文切换后的首键缓冲，观察 Hyper 与输入法切换的即时体感。
local ZH_SWITCH_KEY_BUFFER_WINDOW = 0
local ZH_SWITCH_KEY_REPLAY_DELAY = 0
local HUD_BAR_SLOTS = 10
local HUD_WIDTH = 212
local HUD_HEIGHT = 26
local HUD_BOTTOM_OFFSET = 30
local HUD_VOICE_OFFSET = 40  -- 语音模式下向上位移，避让微信语音栏
local HUD_MOVE_DURATION = 0.20
local HUD_MOVE_INTERVAL = 1 / 60
local VOICE_WINDOW_PROBE_INTERVAL = 0.05
local VOICE_WINDOW_PROBE_ATTEMPTS = 60
local HUD_CORNER_RADIUS = 10
local HUD_FADE_OUT_DURATION = 0.16
local MOCHA_BASE = { red = 30 / 255, green = 30 / 255, blue = 46 / 255 }
local MOCHA_SURFACE0 = { red = 49 / 255, green = 50 / 255, blue = 68 / 255 }
local MOCHA_SUBTEXT1 = { red = 186 / 255, green = 194 / 255, blue = 222 / 255 }
local MOCHA_GREEN = { red = 166 / 255, green = 227 / 255, blue = 161 / 255 }
local MOCHA_YELLOW = { red = 249 / 255, green = 226 / 255, blue = 175 / 255 }
local MOCHA_RED = { red = 243 / 255, green = 139 / 255, blue = 168 / 255 }
local HUD_BG = { red = MOCHA_BASE.red, green = MOCHA_BASE.green, blue = MOCHA_BASE.blue, alpha = 0.42 }
local HUD_TEXT = { red = MOCHA_SUBTEXT1.red, green = MOCHA_SUBTEXT1.green, blue = MOCHA_SUBTEXT1.blue, alpha = 1.0 }
local HUD_PROGRESS_GREEN = { red = MOCHA_GREEN.red, green = MOCHA_GREEN.green, blue = MOCHA_GREEN.blue, alpha = 0.9 }
local HUD_PROGRESS_YELLOW = { red = MOCHA_YELLOW.red, green = MOCHA_YELLOW.green, blue = MOCHA_YELLOW.blue, alpha = 0.9 }
local HUD_PROGRESS_RED = { red = MOCHA_RED.red, green = MOCHA_RED.green, blue = MOCHA_RED.blue, alpha = 0.9 }
local HUD_PROGRESS_EMPTY = { red = MOCHA_SURFACE0.red, green = MOCHA_SURFACE0.green, blue = MOCHA_SURFACE0.blue, alpha = 0.52 }

local resetIdleTimer
local hideInputHud
local _idleDeadline = nil
local _idleTickTimer = nil
local _keyTimestamps = {}
local _inputHud = nil
local _hudMoveTimer = nil
-- 暂时不等待异步验证，避免输入法切换链路增加体感延迟。
local SOURCE_VERIFY_DELAY = 0
local _sourceVerifyTimer = nil

local function isUsingAlternateInput()
	return hs.keycodes.currentSourceID() ~= ABC_SRC
end

local function enabledInputSourceNames()
	local names = {}
	for _, name in ipairs(hs.keycodes.layouts() or {}) do
		names[#names + 1] = name
	end
	for _, name in ipairs(hs.keycodes.methods() or {}) do
		names[#names + 1] = name
	end
	return names
end

local function warnInputSourceConfiguration()
	local names = enabledInputSourceNames()
	local warnings = {}
	local hasABC = false
	for _, name in ipairs(names) do
		if name == "ABC" then
			hasABC = true
			break
		end
	end
	if #names ~= 2 or not hasABC then
		warnings[#warnings + 1] = string.format("输入源 %d 个", #names)
		print("[Input] 已启用输入源: " .. (#names > 0 and table.concat(names, "、") or "无"))
	end
	if not _inputSourceShortcut then
		warnings[#warnings + 1] = "快捷键不可用"
	end
	if #warnings > 0 then
		notification.show("配置异常：" .. table.concat(warnings, "、"), "warning", 2.0)
	end
end

local function stopIdleTimer(fadeHud, keepHud)
	if _idleTimer then
		_idleTimer:stop()
		_idleTimer = nil
	end
	if _idleTickTimer then
		_idleTickTimer:stop()
		_idleTickTimer = nil
	end
	_idleDeadline = nil
	if hideInputHud and not keepHud then
		hideInputHud(fadeHud)
	end
end

local function pauseIdleTimerForVoice()
	if _idleTimer then
		_idleTimer:stop()
		_idleTimer = nil
	end
	if _idleTickTimer then
		_idleTickTimer:stop()
		_idleTickTimer = nil
	end
	if not _idleDeadline then
		_idleDeadline = hs.timer.secondsSinceEpoch() + IDLE_TIMEOUT
	end
end

local function copyHudFrame(frame)
	if not frame then return nil end
	return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function stopHudMoveAnimation()
	if _hudMoveTimer then
		_hudMoveTimer:stop()
		_hudMoveTimer = nil
	end
end

local function pruneKeyTimestamps(now)
	local cutoff = now - KEY_RATE_WINDOW
	while #_keyTimestamps > 0 and _keyTimestamps[1] < cutoff do
		table.remove(_keyTimestamps, 1)
	end
end

local function currentKpm(now)
	pruneKeyTimestamps(now)
	if #_keyTimestamps == 0 then
		return 0
	end
	local elapsed = math.max(1, math.min(KEY_RATE_WINDOW, now - _keyTimestamps[1]))
	return math.floor((#_keyTimestamps / elapsed) * 60 + 0.5)
end

local function countdownFilledSlots(remaining, total)
	remaining = math.max(0, tonumber(remaining) or 0)
	total = math.max(1, tonumber(total) or IDLE_TIMEOUT)
	return math.max(0, math.min(HUD_BAR_SLOTS, math.ceil((remaining / total) * HUD_BAR_SLOTS)))
end

local function progressSlotColor(index)
	local fromRight = HUD_BAR_SLOTS - index + 1
	if fromRight <= 4 then
		return HUD_PROGRESS_GREEN
	elseif fromRight <= 7 then
		return HUD_PROGRESS_YELLOW
	end
	return HUD_PROGRESS_RED
end

local function isInputActivityKey(event)
	local char = event:getCharacters()
	local kc = event:getKeyCode()
	return (char and char:match("^[a-zA-Z0-9 %p]$"))
		or kc == 51   -- Backspace (Delete)
		or kc == 117  -- Forward Delete (fn+delete)
		or kc == 123  -- Left
		or kc == 124  -- Right
		or kc == 125  -- Down
		or kc == 126  -- Up
end

local function shouldCountKpm(event)
	local kc = event:getKeyCode()
	return kc ~= 51 and kc ~= 117
end

local function isBufferedZhSwitchKey(event)
	local char = event:getCharacters()
	local flags = event:getFlags()
	return char and char:match("^[a-zA-Z0-9 %p]$")
		and not flags.cmd
		and not flags.ctrl
		and not flags.alt
end

local function clearZhSwitchKeyBuffer()
	_zhSwitchKeyBufferUntil = 0
	_zhBufferedKey = nil
	_zhBufferedTarget = nil
end

local function frontmostIdentity()
	local window = hs.window.frontmostWindow()
	if not window then return nil end
	local app = window:application()
	return {
		windowID = window:id(),
		bundleID = app and app:bundleID() or nil,
	}
end

local function sameFrontmost(identity)
	local current = frontmostIdentity()
	return identity
		and current
		and identity.windowID == current.windowID
		and identity.bundleID == current.bundleID
end

local function modifiersFromEvent(event)
	local flags = event:getFlags()
	local modifiers = {}
	if flags.shift then
		modifiers[#modifiers + 1] = "shift"
	end
	if flags.fn then
		modifiers[#modifiers + 1] = "fn"
	end
	return modifiers
end

local function armZhSwitchKeyBuffer()
	_zhSwitchKeyBufferUntil = hs.timer.secondsSinceEpoch() + ZH_SWITCH_KEY_BUFFER_WINDOW
	_zhBufferedKey = nil
end

local function maybeBufferZhSwitchKey(event)
	if _replayingBufferedKey or _zhBufferedKey or not isBufferedZhSwitchKey(event) then
		return false
	end
	if hs.timer.secondsSinceEpoch() > _zhSwitchKeyBufferUntil then
		return false
	end
	_zhBufferedKey = {
		keyCode = event:getKeyCode(),
		modifiers = modifiersFromEvent(event),
	}
	_zhBufferedTarget = frontmostIdentity()
	return true
end

local function flushZhSwitchKeyBuffer()
	local bufferedKey = _zhBufferedKey
	local bufferedTarget = _zhBufferedTarget
	clearZhSwitchKeyBuffer()
	if not bufferedKey then
		return
	end
	if not sameFrontmost(bufferedTarget) then
		print("[Input] 丢弃前台窗口已变化的中文首键重放")
		return
	end
	hs.timer.doAfter(ZH_SWITCH_KEY_REPLAY_DELAY, function()
		if not sameFrontmost(bufferedTarget) then
			print("[Input] 丢弃重放期间前台窗口变化的中文首键")
			return
		end
		_replayingBufferedKey = true
		local ok, err = pcall(function()
			hs.eventtap.keyStroke(bufferedKey.modifiers, bufferedKey.keyCode, 1000)
		end)
		_replayingBufferedKey = false
		if not ok then
			print("[Input] 重放中文首键失败: " .. tostring(err))
		end
	end)
end

hideInputHud = function(fade)
	stopHudMoveAnimation()
	if _inputHud then
		local hud = _inputHud
		_inputHud = nil
		if fade then
			pcall(function() hud:hide(HUD_FADE_OUT_DURATION) end)
			hs.timer.doAfter(HUD_FADE_OUT_DURATION + 0.02, function()
				pcall(function() hud:delete() end)
			end)
			return
		end
		hud:delete()
	end
end

local function animateInputHud(fromFrame, toFrame)
	if not _inputHud or not fromFrame or not toFrame then return end
	stopHudMoveAnimation()
	local startedAt = hs.timer.secondsSinceEpoch()
	_inputHud:frame(fromFrame)
	_hudMoveTimer = hs.timer.doEvery(HUD_MOVE_INTERVAL, function()
		if not _inputHud then
			stopHudMoveAnimation()
			return
		end
		local progress = math.min(1, (hs.timer.secondsSinceEpoch() - startedAt) / HUD_MOVE_DURATION)
		local eased = 1 - (1 - progress) ^ 3
		_inputHud:frame({
			x = fromFrame.x + (toFrame.x - fromFrame.x) * eased,
			y = fromFrame.y + (toFrame.y - fromFrame.y) * eased,
			w = fromFrame.w + (toFrame.w - fromFrame.w) * eased,
			h = fromFrame.h + (toFrame.h - fromFrame.h) * eased,
		})
		if progress >= 1 then
			_inputHud:frame(toFrame)
			stopHudMoveAnimation()
		end
	end)
end

local function inputHudFrame()
	local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	local frame = screen:fullFrame()
	local voiceShift = _voiceInputActive and HUD_VOICE_OFFSET or 0
	return {
		x = frame.x + math.floor((frame.w - HUD_WIDTH) / 2),
		y = frame.y + frame.h - HUD_HEIGHT - HUD_BOTTOM_OFFSET - voiceShift,
		w = HUD_WIDTH,
		h = HUD_HEIGHT,
	}
end

local function showInputHud(state, remaining, kpm)
	if not wechatVoice.shouldShowHud(
		_voiceInputActive,
		state == ZH,
		isUsingAlternateInput()
	) then
		hideInputHud()
		return
	end

	local voiceShift = _voiceInputActive and HUD_VOICE_OFFSET or 0
	local filledSlots = countdownFilledSlots(remaining, IDLE_TIMEOUT)
	local elements = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = HUD_BG,
			roundedRectRadii = { xRadius = HUD_CORNER_RADIUS, yRadius = HUD_CORNER_RADIUS },
			frame = { x = 0, y = 0, w = HUD_WIDTH, h = HUD_HEIGHT },
		},
		{
			type = "text",
			text = _voiceInputActive and "语音" or "中→英",
			textFont = "SF Pro Text",
			textSize = 13,
			textColor = HUD_TEXT,
			textAlignment = "left",
			frame = { x = 12, y = 6, w = 42, h = 18 },
		},
		{
			type = "text",
			text = string.format("%d kpm", kpm),
			textFont = "SF Pro Text",
			textSize = 13,
			textColor = HUD_TEXT,
			textAlignment = "right",
			frame = { x = 140, y = 6, w = 60, h = 18 },
		},
	}
	local slotW = 6
	local slotH = 8
	local slotGap = 2
	local slotX = 58
	local slotY = 9
	for i = 1, HUD_BAR_SLOTS do
		local filled = i <= filledSlots
		table.insert(elements, {
			type = "rectangle",
			action = "fill",
			fillColor = filled and progressSlotColor(i) or HUD_PROGRESS_EMPTY,
			roundedRectRadii = { xRadius = 2, yRadius = 2 },
			frame = { x = slotX + (i - 1) * (slotW + slotGap), y = slotY, w = slotW, h = slotH },
		})
	end
	if not _inputHud then
		_inputHud = hs.canvas.new(inputHudFrame())
		if not _inputHud then
			return
		end
		_inputHud:appendElements(table.unpack(elements))
		_inputHud:level(hs.canvas.windowLevels.overlay)
		_inputHud:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
		_inputHud:show()
		return
	end

	-- Reuse the canvas while the countdown ticks. Rebuilding an Accessibility
	-- window every second was enough to stall Hammerspoon's main run loop.
	_inputHud:frame(inputHudFrame())
	_inputHud:elementAttribute(2, "text", _voiceInputActive and "语音" or "中→英")
	_inputHud:elementAttribute(3, "text", string.format("%d kpm", kpm))
	for i = 1, HUD_BAR_SLOTS do
		_inputHud:elementAttribute(i + 3, "fillColor", i <= filledSlots and progressSlotColor(i) or HUD_PROGRESS_EMPTY)
	end
end

local function updateInputHud(state)
	local now = hs.timer.secondsSinceEpoch()
	local alternateActive = isUsingAlternateInput()
	local remaining = 0
	if state == ZH and alternateActive and _idleDeadline then
		remaining = math.max(0, math.ceil(_idleDeadline - now))
		if remaining <= 0 then
			if _idleTickTimer then
				_idleTickTimer:stop()
				_idleTickTimer = nil
			end
			hideInputHud(true)
			return
		end
	end
	local kpm = currentKpm(now)
	showInputHud(state, remaining, kpm)
end

local function applyState(state)
	local previousState = _zhState
	_zhState = state
	if state == ZH then
		if previousState ~= ZH or not _idleDeadline then
			resetIdleTimer()
		end
	else
		if _voiceInputActive then
			pauseIdleTimerForVoice()
			updateInputHud(state)
			return
		end
		_voiceInputActive = false
		if _voiceActionTimer then
			_voiceActionTimer:stop()
			_voiceActionTimer = nil
		end
		if stopVoiceWindowProbe then stopVoiceWindowProbe() end
		stopIdleTimer(true)
	end
end

local function queryState(callback, options)
	local state = isUsingAlternateInput() and ZH or EN
	if not (options and options.apply == false) then
		applyState(state)
	end
	if callback then callback(state) end
	return true
end

local function requestState(targetState, callback)
	if targetState ~= EN and targetState ~= ZH then
		if callback then callback(false) end
		return false
	end
	if _switchInFlight then
		if callback then callback(false) end
		return false
	end

	local currentState = isUsingAlternateInput() and ZH or EN
	if currentState == targetState then
		applyState(targetState)
		if callback then callback(true) end
		return true
	end
	if targetState == ZH and not _inputSourceShortcut then
		print("[Input] 切换输入源失败: " .. tostring(_inputSourceShortcutError))
		if callback then callback(false) end
		return false
	end

	_switchInFlight = true
	local finished = false
	local function finish(success, message)
		if finished then return end
		finished = true
		if _InputSwitchWatchdogTimer then
			_InputSwitchWatchdogTimer:stop()
			_InputSwitchWatchdogTimer = nil
		end
		if _sourceVerifyTimer then
			_sourceVerifyTimer:stop()
			_sourceVerifyTimer = nil
		end
		_switchInFlight = false
		if success then
			applyState(targetState)
		else
			-- 失败路径统一补偿释放仍记录为按下的键（含 watchdog 超时、释放失败等出口）。
			releasePendingInputShortcut()
			print("[Input] 切换输入源失败: " .. tostring(message))
		end
		if callback then callback(success) end
	end

	if targetState == EN then
		local ok, switched = pcall(hs.keycodes.currentSourceID, ABC_SRC)
		if not ok or not switched then
			finish(false, ok and "ABC 输入源设置返回失败" or switched)
			return false
		end
		-- 返回英文始终直接使用 TIS，不发送系统输入源快捷键。
		finish(true)
		return true
	else
		local sendOk, sent = pcall(sendInputSourceShortcut, function(shortcutReleased, releaseError)
			if not shortcutReleased then
				finish(false, "释放系统输入源快捷键失败: " .. tostring(releaseError))
				return
			end
			if SOURCE_VERIFY_DELAY <= 0 then
				-- 当前处于低延迟观察模式，快捷键完整释放后直接完成。
				finish(true)
				return
			end
			_sourceVerifyTimer = hs.timer.doAfter(SOURCE_VERIFY_DELAY, function()
				_sourceVerifyTimer = nil
				local reachedTarget = isUsingAlternateInput()
				finish(reachedTarget, "系统快捷键未切换到预期输入源")
			end)
		end)
		if not sendOk or not sent then
			finish(false, sendOk and "系统输入源快捷键发送失败" or sent)
		else
			-- 超时与验证延迟联动：快捷键释放耗时 + 验证窗口 + 固定余量。
			local watchdogTimeout = INPUT_SHORTCUT_SPACE_HOLD + SOURCE_VERIFY_DELAY + INPUT_SWITCH_WATCHDOG_MARGIN
			_InputSwitchWatchdogTimer = hs.timer.doAfter(watchdogTimeout, function()
				_InputSwitchWatchdogTimer = nil
				finish(false, "系统输入源快捷键收尾超时")
			end)
		end
		return true
	end
end

-- Fcitx5 旧切换实现保留在上面的 source-level requestState 旁边，便于观察期回滚。
--[[
local function queryState(callback, options)
	local generation = _stateGeneration
	return startTask(FCITX, {}, function(exitCode, stdout, stderr)
		local raw = tonumber((stdout or ""):match("^%s*([012])%s*$"))
		if exitCode ~= 0 or raw == nil then
			print("[Input] 查询状态失败: " .. tostring(stderr or exitCode))
			if callback then callback(nil) end
			return
		end
		if generation ~= _stateGeneration then
			if callback then callback(nil) end
			return
		end
		local state = raw == 2 and ZH or EN
		if not (options and options.apply == false) then
			applyState(state)
		end
		if callback then callback(state) end
	end, "fcitx5 状态查询")
end

local function requestFcitxState(targetState, callback)
	local im = targetState == ZH and IM_ZH or IM_EN
	return startTask(FCITX, { "-s", im }, callback, "fcitx5 输入法切换")
end

-- 旧 Fcitx5 在 ABC 下切入 Fcitx5 的路径曾使用：
-- startTask(MACISM_BIN, { FCITX5_SRC, "150" }, ...)
]]

resetIdleTimer = function(keepHud)
	if _voiceInputActive then return end
	stopIdleTimer(nil, keepHud)
	if _zhState ~= ZH or not isUsingAlternateInput() then return end
	_idleDeadline = hs.timer.secondsSinceEpoch() + IDLE_TIMEOUT
	updateInputHud(ZH)
	_idleTickTimer = hs.timer.doEvery(IDLE_TICK_INTERVAL, function()
		if _zhState == ZH and isUsingAlternateInput() then
			updateInputHud(ZH)
		else
			stopIdleTimer()
		end
	end)
	_idleTimer = hs.timer.doAfter(IDLE_TIMEOUT, function()
		_idleTimer = nil
		queryState(function(state)
			if state == ZH then
				requestState(EN, function(success)
				end)
			elseif state == EN then
				applyState(EN)
			end
		end, { apply = false })
	end)
end

local function noteInputActivity(countKpm)
	local now = hs.timer.secondsSinceEpoch()
	if countKpm ~= false then
		table.insert(_keyTimestamps, now)
		pruneKeyTimestamps(now)
	end
	if _zhState == ZH and isUsingAlternateInput() then
		resetIdleTimer()
	else
		updateInputHud(_zhState or EN)
	end
end

local function startVoiceInput()
	if _voiceInputActive then return end
	local fromFrame = _inputHud and copyHudFrame(_inputHud:frame()) or nil
	_voiceInputActive = true
	pauseIdleTimerForVoice()
	updateInputHud(_zhState or (isUsingAlternateInput() and ZH or EN))
	-- 语音模式：HUD 向上位移避让微信语音栏，带动画过渡。
	animateInputHud(fromFrame, inputHudFrame())
end

local function finishVoiceInput()
	if not _voiceInputActive then return false end
	local fromFrame = _inputHud and copyHudFrame(_inputHud:frame()) or nil
	_voiceInputActive = false
	if isUsingAlternateInput() then
		_zhState = ZH
		resetIdleTimer(true)
	else
		_zhState = EN
		stopIdleTimer(true)
	end
	-- 语音结束：HUD 平滑恢复原位。
	animateInputHud(fromFrame, inputHudFrame())
	return true
end

local function scheduleVoiceInputAction(shouldFinish)
	if stopVoiceWindowProbe then stopVoiceWindowProbe() end
	if _voiceActionTimer then
		_voiceActionTimer:stop()
	end
	_voiceActionTimer = hs.timer.doAfter(0, function()
		_voiceActionTimer = nil
		if shouldFinish then
			finishVoiceInput()
		else
			startVoiceInput()
		end
	end)
end

local function isVoiceWindowVisible()
	for _, window in ipairs(hs.window.list(true) or {}) do
		if wechatVoice.isVoiceWindow(window) then return true end
	end
	return false
end

stopVoiceWindowProbe = function()
	if not _voiceWindowProbeTimer then return end
	_voiceWindowProbeTimer:stop()
	_voiceWindowProbeTimer = nil
end

local function scheduleVoiceWindowProbe()
	stopVoiceWindowProbe()
	local expectedAction = _voiceInputActive and "finish" or "start"
	local attempts = 0
	local function inspectVoiceWindow()
		attempts = attempts + 1
		local action = wechatVoice.probeAction(_voiceInputActive, isVoiceWindowVisible())
		if action == expectedAction then
			stopVoiceWindowProbe()
			scheduleVoiceInputAction(action == "finish")
		elseif attempts >= VOICE_WINDOW_PROBE_ATTEMPTS then
			stopVoiceWindowProbe()
		end
	end
	_voiceWindowProbeTimer = hs.timer.doEvery(
		VOICE_WINDOW_PROBE_INTERVAL,
		inspectVoiceWindow
	)
	inspectVoiceWindow()
end

-- ============================================================
-- 中文状态进入以下 App 时弹提醒
-- ============================================================
local WARN_APPS = {
	["com.apple.Terminal"] = true,
	["com.googlecode.iterm2"] = true,
	["org.alacritty"] = true,
	["com.mitchellh.ghostty"] = true,
	["com.cmuxterm.app"] = true,
	["net.kovidgoyal.kitty"] = true,
	["com.microsoft.VSCode"] = true,
	["com.jetbrains.intellij"] = true,
	["com.jetbrains.intellij.ce"] = true,
	["md.obsidian"] = true,
	["com.raycast.macos"] = true,
	["com.raycast-x.macos"] = true,
	["org.vim.MacVim"] = true,
	["com.neovide.neovide"] = true,
}

local function warnEN(id)
	if not WARN_APPS[id] then
		return
	end
	if hs.timer.secondsSinceEpoch() - _toggled < 2 then
		return
	end
	if not isUsingAlternateInput() then
		return
	end
	queryState(function(state)
		if state == ZH then
			notification.show("中文输入：请切换为英文", "warning", 1.0)
		end
	end)
end

-- 中文警告监听：进入指定应用时检查中文输入法状态
-- 用 pcall 保护，避免进程已终止时抛出 "Unable to fetch NSRunningApplication"
_WarnWatcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated and app then
		local ok, id = pcall(function() return app:bundleID() end)
		if ok and id then
			warnEN(id)
		end
	end
end)
_WarnWatcher:start()

-- 启动时对当前前台应用做一次初始检查
do
	local frontApp = hs.application.frontmostApplication()
	if frontApp then
		local ok, id = pcall(function() return frontApp:bundleID() end)
		if ok and id then
			warnEN(id)
		end
	end
end

-- ============================================================
-- CapsLock 单按由 macOS 原生切换输入法；Raycast 仅处理 Hyper 组合键。
-- 微信输入法会吞掉右 Command；纯 Command 事件只启动短时浮层检测。
-- ============================================================
_InputTap = hs.eventtap.new({
	hs.eventtap.event.types.flagsChanged,
	hs.eventtap.event.types.keyDown,
	hs.eventtap.event.types.keyUp,
	hs.eventtap.event.types.leftMouseDown,
	hs.eventtap.event.types.rightMouseDown,
	hs.eventtap.event.types.otherMouseDown,
}, function(event)
	local etype = event:getType()
	local f = event:getFlags()
	local hyper = f.ctrl and f.alt and f.cmd

	if etype == hs.eventtap.event.types.keyDown and _voiceInputActive then
		scheduleVoiceInputAction(true)
		return false
	end

	if etype == hs.eventtap.event.types.flagsChanged then
		if wechatVoice.isProbeTrigger(
			event:getKeyCode(),
			f,
			hs.keycodes.currentSourceID(),
			LEFT_COMMAND_KEYCODE
		) then
			scheduleVoiceWindowProbe()
		end
	end
	if etype == hs.eventtap.event.types.keyDown then
		-- Hyper 组合键（如 Hyper+数字 切换工作区）不重置空闲
		if not hyper and not _switchInFlight then
			if maybeBufferZhSwitchKey(event) then
				return true
			end
			-- 字母、数字、空格、标点、退格/删除、方向键才重置空闲
			if _zhState == ZH and isInputActivityKey(event) then
				noteInputActivity(shouldCountKpm(event))
			end
		end
	end
	return false
end)
_InputTap:start()

-- 启动时读取真实状态，避免默认缓存导致误报。
queryState()

-- 输入源变化由 macOS 分布式通知驱动，不使用常驻轮询。
_InputSourceWatcher = hs.distributednotifications.new(
	function()
		if not _switchInFlight then
			queryState()
		end
	end,
	"com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
)
_InputSourceWatcher:start()

-- 仅在 reload 时检查一次，不为配置健康度增加常驻轮询。
warnInputSourceConfiguration()

-- ============================================================
-- 暴露接口给外部模块使用（如 wps.lua）
-- ============================================================
return {
	isChineseAsync = function(callback)
		queryState(function(state)
			callback(state == ZH)
		end)
	end,
	switchToEnglishAsync = function(callback)
		requestState(EN, callback)
	end,
	switchToChineseAsync = function(callback)
		requestState(ZH, callback)
	end,
}
