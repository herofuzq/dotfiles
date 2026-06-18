-- ============================================================
-- 输入法切换 - fcitx5-remote
-- 1 = 英文, 2 = 中文
-- ============================================================
-- 动态查找 fcitx5-remote 路径（支持 .app 安装和 brew 安装）
local function findFcitxRemote()
	local candidates = {
		"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote",
		"/opt/homebrew/bin/fcitx5-remote",
		"/usr/local/bin/fcitx5-remote",
	}
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p, "mode") == "file" then
			return p
		end
	end
	return "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"
end
local FCITX = findFcitxRemote()
local EN = 1
local ZH = 2

-- fcitx5 的 sourceID（macism + currentSourceID 共用）
local FCITX5_SRC = "org.fcitx.inputmethod.Fcitx5.zhHans"

-- fcitx5 内的输入法名（用 `fcitx5-remote -n` 查得）
-- -s <imname> 是显式切换：行为比 -c/-o 更可预测，不依赖上次激活记忆
local IM_ZH = "rime"
local IM_EN = "keyboard-us"

-- 动态查找 macism 路径（避免依赖 PATH）
local MACISM_BIN = (function()
	local candidates = { "/opt/homebrew/bin/macism", "/usr/local/bin/macism" }
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p, "mode") == "file" then
			return p
		end
	end
	return "macism" -- fallback 到 PATH
end)()

local function isUsingFcitx5()
	return hs.keycodes.currentSourceID() == FCITX5_SRC
end

-- 内部状态只在查询或切换成功后更新，避免命令失败时误报。
local _zhState = EN
local _toggled = 0
local _idleTimer = nil
local _switchInFlight = false
local _desiredState = nil
local _desiredCallback = nil
local _stateGeneration = 0

-- ============================================================
-- 空闲自动切换回英文
-- ============================================================
local IDLE_TIMEOUT = 10

local resetIdleTimer

local function stopIdleTimer()
	if _idleTimer then
		_idleTimer:stop()
		_idleTimer = nil
	end
end

local function applyState(state)
	_zhState = state
	if state == ZH then
		resetIdleTimer()
	else
		stopIdleTimer()
	end
end

local function startTask(executable, args, callback, label)
	local ok, task = pcall(hs.task.new, executable, callback, args)
	if not ok or not task then
		print("[Input] 无法创建任务 " .. (label or executable) .. ": " .. tostring(task))
		return false
	end
	local started, result = pcall(function() return task:start() end)
	if not started or not result then
		print("[Input] 无法启动任务 " .. (label or executable) .. ": " .. tostring(result))
		return false
	end
	return true
end

local function queryState(callback)
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
		applyState(state)
		if callback then callback(state) end
	end, "fcitx5 状态查询")
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
		local im = state == ZH and IM_ZH or IM_EN
		local started = startTask(FCITX, { "-s", im }, function(exitCode, _, stderr)
			_switchInFlight = false
			local superseded = _desiredState and _desiredState ~= state
			if exitCode == 0 then
				applyState(state)
			else
				print("[Input] 切换失败: " .. tostring(stderr or exitCode))
			end
			if stateCallback and not superseded then stateCallback(exitCode == 0) end
			if superseded then
				drain()
			else
				_desiredState = nil
				_desiredCallback = nil
			end
		end, "fcitx5 输入法切换")
		if not started then
			_switchInFlight = false
			if stateCallback then stateCallback(false) end
		end
	end

	drain()
end

resetIdleTimer = function()
	stopIdleTimer()
	if _zhState ~= ZH or not isUsingFcitx5() then return end
	_idleTimer = hs.timer.doAfter(IDLE_TIMEOUT, function()
		_idleTimer = nil
		queryState(function(state)
			if state == ZH then
				requestState(EN, function(success)
					if success then hs.alert.show("⏱ 英文输入中", 0.4) end
				end)
			end
		end)
	end)
end

local function toggle()
	_toggled = hs.timer.secondsSinceEpoch()

	-- 如果当前输入源是 ABC（非 fcitx5），先切输入源，再显式启用中文引擎。
	if not isUsingFcitx5() then
		startTask(MACISM_BIN, { FCITX5_SRC, "150" }, function(exitCode, _, stderr)
			if exitCode ~= 0 then
				print("[Input] 切换输入源失败: " .. tostring(stderr or exitCode))
				return
			end
			requestState(ZH, function(success)
				if success then hs.alert.show("⌨ 中文输入中", 0.4) end
			end)
		end, "macism 输入源切换")
		return
	end

	queryState(function(state)
		if not state then return end
		local target = state == ZH and EN or ZH
		requestState(target, function(success)
			if success then
				hs.alert.show(target == ZH and "⌨ 中文输入中" or "⌨ 英文输入中", 0.4)
			end
		end)
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
	if not isUsingFcitx5() then
		return
	end
	queryState(function(state)
		if state == ZH then
			hs.alert.show("⚠ 中文输入中", 1.0)
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
-- 不监听 shift：shift 由 fcitx5 内部处理（左 shift = -t 切激活），
-- Hammerspoon 主动 -s 切 IM，shift 的状态变化 _zhState 不感知。
-- ============================================================
local hyper_pressed = false
local hyper_used = false
local shift_pressed = false

_InputTap = hs.eventtap.new({
	hs.eventtap.event.types.flagsChanged,
	hs.eventtap.event.types.keyDown,
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
		local shift = f.shift == true
		if shift_pressed and not shift and not hyper and isUsingFcitx5() then
			-- Fcitx5 在 Shift 松开后切换内部状态，稍后读取真实值。
			hs.timer.doAfter(0.03, queryState)
		end
		shift_pressed = shift
	elseif hyper_pressed then
		hyper_used = true
	end
	if etype == hs.eventtap.event.types.keyDown then
		-- Hyper 组合键（如 Hyper+数字 切换工作区）不重置空闲
		if not hyper_pressed then
			-- 字母、数字、空格、标点、退格/删除 才重置空闲
			local char = event:getCharacters()
			local kc = event:getKeyCode()
			if (char and char:match("^[a-zA-Z0-9 %p]$"))
				or kc == 51   -- Backspace (Delete)
				or kc == 117  -- Forward Delete (fn+delete)
			then
				resetIdleTimer()
			end
		end
	end
	return false
end)
_InputTap:start()

-- 启动时读取真实状态，避免默认缓存导致误报。
queryState()

-- ============================================================
-- 暴露接口给外部模块使用（如 wps.lua）
-- ============================================================
return {
	isChineseAsync = function(callback)
		if not isUsingFcitx5() then
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
