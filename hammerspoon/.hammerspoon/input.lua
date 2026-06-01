-- ============================================================
-- 输入法切换 - fcitx5-remote
-- 1 = 英文, 2 = 中文
-- ============================================================
local FCITX = "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"
local EN = 1
local ZH = 2

-- fcitx5 的 sourceID（macism + currentSourceID 共用）
local FCITX5_SRC = "org.fcitx.inputmethod.Fcitx5.zhHans"

local function isUsingFcitx5()
	return hs.keycodes.currentSourceID() == FCITX5_SRC
end

-- 内部状态追踪：不依赖 fcitx5-remote 查询（返回值不稳定），
-- 由 toggle() 每次切换后自己记录，默认假设为中文。
local _zhState = ZH

local _toggled = 0

local function toggle()
	_toggled = hs.timer.secondsSinceEpoch()

	-- 如果当前输入源是 ABC（非 fcitx5），切到 fcitx5（macism 自带等待）
	if not isUsingFcitx5() then
		hs.execute("macism " .. FCITX5_SRC .. " 150", true)
		hs.alert.show("中文", 0.4)
		_zhState = ZH
		return
	end

	-- 已在 fcitx5 中，切换中英文
	if _zhState == ZH then
		hs.execute("'" .. FCITX .. "' -c", true)
		hs.alert.show("英文", 0.4)
		_zhState = EN
	else
		hs.execute("'" .. FCITX .. "' -o", true)
		hs.alert.show("中文", 0.4)
		_zhState = ZH
	end
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
	if not WARN_APPS[id] then return end
	if hs.timer.secondsSinceEpoch() - _toggled < 2 then return end
	if not isUsingFcitx5() then return end
	if _zhState == ZH then
		hs.alert.show("⚠️ 中文输入中", 1.0)
	end
end

_WarnWatcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated and app then
		warnEN(app:bundleID())
	end
end)
_WarnWatcher:start()

-- 启动时对当前前台应用做一次初始检查
do
	local frontApp = hs.application.frontmostApplication()
	if frontApp then warnEN(frontApp:bundleID()) end
end

-- ============================================================
-- CapsLock (Hyper) 单独按下 → 切换中英文
-- ============================================================
local pressed = false
local used = false

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
		if hyper and not pressed then
			pressed, used = true, false
		elseif hyper and pressed then
			used = true
		elseif not hyper and pressed then
			pressed = false
			if not used then toggle() end
		end
	elseif pressed then
		used = true
	end
	return false
end)
_InputTap:start()

-- ============================================================
-- 暴露接口给外部模块使用（如 wps.lua）
-- ============================================================
_FcitxInput = {
	isChinese = function()
		return isUsingFcitx5() and _zhState == ZH
	end,
	switchToEnglish = function()
		hs.execute("'" .. FCITX .. "' -c", true)
		_zhState = EN
	end,
	switchToChinese = function()
		hs.execute("'" .. FCITX .. "' -o", true)
		_zhState = ZH
	end,
}
