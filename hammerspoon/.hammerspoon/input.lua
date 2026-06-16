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

-- 内部状态追踪：与 fcitx5 内部状态通过 eventtap 同步（caps / shift 都触发 toggle），
-- 不再轮询，避免同步 fork 子进程造成卡顿。
local _zhState = ZH

local _toggled = 0

-- ============================================================
-- 空闲自动切换回英文
-- ============================================================
local IDLE_TIMEOUT = 10

local function resetIdleTimer()
	if _IdleTimer then
		_IdleTimer:stop()
	end
	_IdleTimer = hs.timer.doAfter(IDLE_TIMEOUT, function()
		hs.task.new(FCITX, function(_, stdout)
			local state = tonumber(stdout and stdout:match("(%d)"))
			if state == 2 then
				hs.execute("'" .. FCITX .. "' -s " .. IM_EN, true)
				_zhState = EN
				hs.alert.show("⏱ 英文输入中", 0.4)
			elseif state == 1 then
				_zhState = EN
			end
		end, {}):start()
	end)
end

local function toggle()
	_toggled = hs.timer.secondsSinceEpoch()

	-- 如果当前输入源是 ABC（非 fcitx5），切到 fcitx5（macism 自带等待）
	if not isUsingFcitx5() then
		hs.execute(MACISM_BIN .. " " .. FCITX5_SRC .. " 150", true)
		hs.alert.show("⌨ 中文输入中", 0.4)
		_zhState = ZH
		resetIdleTimer()
		return
	end

	-- 已在 fcitx5 中，用 -t 强制翻转 fcitx5 引擎激活态（异步避免阻塞 eventtap）
	-- -t 不输出，需分两步：先翻再查真实态
	hs.task.new(FCITX, function()
		hs.task.new(FCITX, function(_, stdout)
			_zhState = (tonumber(stdout and stdout:match("(%d)")) == 2) and ZH or EN
			hs.alert.show(_zhState == ZH and "⌨ 中文输入中" or "⌨ 英文输入中", 0.4)
			if _zhState == ZH then
				resetIdleTimer()
			end
		end, {}):start()
	end, { "-t" }):start()
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
	if _zhState == ZH then
		hs.alert.show("⚠ 中文输入中", 1.0)
	end
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
	elseif hyper_pressed then
		hyper_used = true
	end
	if etype == hs.eventtap.event.types.keyDown then
		-- 字母、数字、空格、标点、退格/删除 才重置空闲
		local char = event:getCharacters()
		local kc = event:getKeyCode()
		if (char and char:match("^[a-zA-Z0-9 %p]$"))  -- 字母/数字/空格/标点
			or kc == 51   -- Backspace (Delete)
			or kc == 117  -- Forward Delete (fn+delete)
		then
			resetIdleTimer()
		end
	end
	return false
end)
_InputTap:start()

-- 启动空闲计时器
resetIdleTimer()

-- ============================================================
-- 暴露接口给外部模块使用（如 wps.lua）
-- ============================================================
_FcitxInput = {
	isChinese = function()
		return isUsingFcitx5() and _zhState == ZH
	end,
	-- @deprecated 同步阻塞，eventtap 回调中应使用 switchToEnglishAsync
	switchToEnglish = function()
		hs.execute("'" .. FCITX .. "' -s " .. IM_EN, true)
		_zhState = EN
	end,
	-- @deprecated 同步阻塞，eventtap 回调中应使用 switchToChineseAsync
	switchToChinese = function()
		hs.execute("'" .. FCITX .. "' -s " .. IM_ZH, true)
		_zhState = ZH
	end,
	-- 异步版本：用 hs.task 避免阻塞 eventtap 回调，减少右键延迟
	switchToEnglishAsync = function()
		hs.task.new(FCITX, nil, { "-s", IM_EN }):start()
		_zhState = EN
	end,
	switchToChineseAsync = function()
		hs.task.new(FCITX, nil, { "-s", IM_ZH }):start()
		_zhState = ZH
	end,
}
