-- ============================================================
-- 输入法切换 - macOS input source
-- 1 = 英文（ABC）, 2 = 中文（微信输入法）
-- ============================================================
local notification = require("notification_hud")
local EN = 1
local ZH = 2

local ABC_SRC = "com.apple.keylayout.ABC"
local WECHAT_SRC = "com.tencent.inputmethod.wetype.pinyin"

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
	return hs.keycodes.currentSourceID() == WECHAT_SRC
end

-- 内部状态只在查询或切换成功后更新，避免命令失败时误报。
local _zhState
local _toggled = 0
local _idleTimer = nil
local _switchInFlight = false
local _desiredState = nil
local _desiredCallback = nil
local _stateGeneration = 0
local _zhSwitchKeyBufferUntil = 0
local _zhBufferedKey = nil
local _replayingBufferedKey = false
local _zhBufferedTarget = nil

-- ============================================================
-- 空闲自动切换回英文
-- ============================================================
local IDLE_TIMEOUT = 10
local IDLE_TICK_INTERVAL = 1
local KEY_RATE_WINDOW = 60
local ZH_SWITCH_KEY_BUFFER_WINDOW = 0.18
local ZH_SWITCH_KEY_REPLAY_DELAY = 0.03
local HUD_BAR_SLOTS = 10
local HUD_WIDTH = 212
local HUD_HEIGHT = 26
local HUD_BOTTOM_OFFSET = 30
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
local SOURCE_VERIFY_DELAY = 0.10

local function stopIdleTimer(fadeHud)
	if _idleTimer then
		_idleTimer:stop()
		_idleTimer = nil
	end
	if _idleTickTimer then
		_idleTickTimer:stop()
		_idleTickTimer = nil
	end
	_idleDeadline = nil
	if hideInputHud then
		hideInputHud(fadeHud)
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

local function inputHudFrame()
	local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	local frame = screen:fullFrame()
	return {
		x = frame.x + math.floor((frame.w - HUD_WIDTH) / 2),
		y = frame.y + frame.h - HUD_HEIGHT - HUD_BOTTOM_OFFSET,
		w = HUD_WIDTH,
		h = HUD_HEIGHT,
	}
end

local function showInputHud(state, remaining, kpm)
	if state ~= ZH or not isUsingWeChat() then
		hideInputHud()
		return
	end

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
			text = "中→英",
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
	_inputHud:elementAttribute(2, "text", "中→英")
	_inputHud:elementAttribute(3, "text", string.format("%d kpm", kpm))
	for i = 1, HUD_BAR_SLOTS do
		_inputHud:elementAttribute(i + 3, "fillColor", i <= filledSlots and progressSlotColor(i) or HUD_PROGRESS_EMPTY)
	end
end

local function updateInputHud(state)
	local now = hs.timer.secondsSinceEpoch()
	local wechat_active = isUsingWeChat()
	local remaining = 0
	if state == ZH and wechat_active and _idleDeadline then
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
	_zhState = state
	if state == ZH then
		resetIdleTimer()
	else
		stopIdleTimer(true)
	end
end

local function queryState(callback, options)
	local state = isUsingWeChat() and ZH or EN
	if not (options and options.apply == false) then
		applyState(state)
	end
	if callback then callback(state) end
	return true
end

local function requestState(targetState, callback)
	_desiredState = targetState
	_desiredCallback = callback
	if _switchInFlight then return end

	local function drain()
		local state = _desiredState
		local stateCallback = _desiredCallback
		_desiredState = nil
		_desiredCallback = nil
		if not state then return end

		_switchInFlight = true
		_stateGeneration = _stateGeneration + 1
		local sourceID = state == ZH and WECHAT_SRC or ABC_SRC
		local function finish(success, message)
			_switchInFlight = false
			local superseded = _desiredState and _desiredState ~= state
			if success then
				applyState(state)
			else
				print("[Input] 切换输入源失败: " .. tostring(message or sourceID))
			end
			if stateCallback and not superseded then stateCallback(success) end
			if superseded then
				drain()
			else
				_desiredState = nil
				_desiredCallback = nil
			end
		end

		local changed = hs.keycodes.currentSourceID(sourceID)
		if not changed then
			finish(false, "原生输入源设置返回失败")
			return
		end
		hs.timer.doAfter(SOURCE_VERIFY_DELAY, function()
			if hs.keycodes.currentSourceID() == sourceID then
				finish(true)
				return
			end

			-- 某些 App 需要第二次原生设置才能完成 source 接管；仍不启动外部进程。
			local retried = hs.keycodes.currentSourceID(sourceID)
			if not retried then
				finish(false, "原生输入源重试返回失败")
				return
			end
			hs.timer.doAfter(SOURCE_VERIFY_DELAY, function()
				finish(hs.keycodes.currentSourceID() == sourceID, "原生输入源复核失败")
			end)
		end)
	end

	drain()
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

resetIdleTimer = function()
	stopIdleTimer()
	if _zhState ~= ZH or not isUsingWeChat() then return end
	_idleDeadline = hs.timer.secondsSinceEpoch() + IDLE_TIMEOUT
	updateInputHud(ZH)
	_idleTickTimer = hs.timer.doEvery(IDLE_TICK_INTERVAL, function()
		if _zhState == ZH and isUsingWeChat() then
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
	if _zhState == ZH and isUsingWeChat() then
		resetIdleTimer()
	else
		updateInputHud(_zhState or EN)
	end
end

local function requestToggleFromState(state)
	if state ~= ZH and state ~= EN then
		return false
	end
	local target = state == ZH and EN or ZH
	if target == ZH then
		armZhSwitchKeyBuffer()
	else
		clearZhSwitchKeyBuffer()
	end
	requestState(target, function(success)
		if target == ZH then
			flushZhSwitchKeyBuffer()
		end
		-- HUD 已显示输入状态，切换提醒不再额外弹窗。
	end)
	return true
end

local function toggle()
	_toggled = hs.timer.secondsSinceEpoch()

	-- 直接根据当前 macOS 输入源切换 ABC 与微信输入法。
	if requestToggleFromState(_zhState) then
		return
	end

	queryState(function(state)
		if not state then return end
		requestToggleFromState(state)
	end)
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
	if not isUsingWeChat() then
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
-- CapsLock (Hyper) 单独按下 → 切换中英文
-- 微信输入法以 macOS source ID 表示中文状态。
-- ============================================================
local hyper_pressed = false
local hyper_used = false

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

	if etype == hs.eventtap.event.types.flagsChanged then
		if hyper and not hyper_pressed then
			hyper_pressed, hyper_used = true, false
		elseif hyper and hyper_pressed then
			hyper_used = true
		elseif not hyper and hyper_pressed then
			hyper_pressed = false
			if not hyper_used then
				toggle()
			end
		end
	elseif etype == hs.eventtap.event.types.keyDown
		or etype == hs.eventtap.event.types.keyUp then
		-- 组合键的按键释放也可能晚于业务方的全局快捷键处理；
		-- 只要完整 Hyper 仍在，就明确标记为已使用，避免误触发单独 Hyper。
		if hyper then
			hyper_pressed, hyper_used = true, true
		elseif hyper_pressed then
			hyper_used = true
		end
	elseif hyper_pressed then
		hyper_used = true
		end
	if etype == hs.eventtap.event.types.keyDown then
		-- Hyper 组合键（如 Hyper+数字 切换工作区）不重置空闲
		if not hyper_pressed then
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
		queryState()
	end,
	"com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
)
_InputSourceWatcher:start()

-- ============================================================
-- 暴露接口给外部模块使用（如 wps.lua）
-- ============================================================
return {
	isChineseAsync = function(callback)
		if not isUsingWeChat() then
			applyState(EN)
			callback(false)
			return
		end
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
