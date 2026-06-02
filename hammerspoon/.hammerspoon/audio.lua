-- ============================================================
-- 外接显示器 → 自动切换音频输出
-- 通过 hs.audiodevice.transportType() 区分设备：
--   "HDMI" / "DisplayPort" → 外接显示器扬声器
--   "Built-in"             → 内置扬声器
-- ============================================================

-- ---- 配置 ----
-- 外接显示器音频的 transport 类型（macOS 返回 "HDMI" 或 "DisplayPort"）
local EXTERNAL_TRANSPORTS = {
	HDMI = true,
	DisplayPort = true,
}

-- 内置扬声器的 transport 类型
local INTERNAL_TRANSPORTS = {
	["Built-in"] = true,
}

-- 连接显示器后等待音频设备就绪的延迟（秒）
local SWITCH_DELAY = 3.0

-- 找不到设备时的重试次数（每次间隔 1 秒）
local RETRY_COUNT = 3

-- ---- 内部状态 ----
local _screenCount = #hs.screen.allScreens()
local _pendingTimer = nil

-- ---- 查找设备 ----
local function findDevice(transports)
	local devices = hs.audiodevice.allOutputDevices()
	for _, d in ipairs(devices) do
		if transports[d:transportType()] then
			return d
		end
	end
	return nil
end

-- ---- 执行切换 ----
local function doSwitch(target, label)
	local current = hs.audiodevice.defaultOutputDevice()
	if current:uid() == target:uid() then
		print("[AudioSwitch] 已是目标设备: " .. target:name())
		return
	end
	target:setDefaultOutputDevice()
	hs.alert.show(label .. target:name(), 1.5)
	print("[AudioSwitch] 已切换: " .. target:name())
end

local function switchToExternal(retries)
	retries = retries or RETRY_COUNT
	local ext = findDevice(EXTERNAL_TRANSPORTS)
	if ext then
		doSwitch(ext, "🔊 → ")
		return
	end
	if retries > 0 then
		print("[AudioSwitch] 未找到外接音频设备，" .. retries .. " 秒后重试...")
		if _pendingTimer then _pendingTimer:stop() end
		_pendingTimer = hs.timer.doAfter(1, function()
			_pendingTimer = nil
			switchToExternal(retries - 1)
		end)
	else
		hs.alert.show("⚠️ 未找到外接显示器音频设备", 1.5)
		print("[AudioSwitch] 重试耗尽，未找到 HDMI/DisplayPort 音频设备")
	end
end

local function switchToInternal()
	local internal = findDevice(INTERNAL_TRANSPORTS)
	if internal then
		doSwitch(internal, "🔈 → ")
	end
end

-- ---- 检测是否有外接音频设备 ----
local function hasExternalAudio()
	return findDevice(EXTERNAL_TRANSPORTS) ~= nil
end

-- ---- 屏幕变化回调 ----
local function onScreenChange()
	local newCount = #hs.screen.allScreens()
	if newCount == _screenCount then
		return
	end

	-- 取消正在进行的延迟切换（快速插拔时防抖）
	if _pendingTimer then
		_pendingTimer:stop()
		_pendingTimer = nil
	end

	_screenCount = newCount

	if newCount > 1 then
		hs.alert.show("🖥️ 外接显示器 → 切换音频...", 1.0)
		print("[AudioSwitch] 检测到外接显示器，" .. SWITCH_DELAY .. " 秒后切换音频...")
		_pendingTimer = hs.timer.doAfter(SWITCH_DELAY, function()
			_pendingTimer = nil
			switchToExternal()
		end)
	else
		hs.alert.show("🔈 切回内置扬声器", 1.0)
		print("[AudioSwitch] 外接显示器已断开，切回内置扬声器")
		switchToInternal()
	end
end

-- ---- 系统唤醒监听（盒盖待机连接显示器场景） ----
_WakeWatcher = hs.caffeinate.watcher.new(function(eventType)
	if eventType == hs.caffeinate.watcher.systemDidWake then
		print("[AudioSwitch] 系统唤醒，检测显示器...")
		-- 唤醒后屏幕恢复可能有延迟，等 SWITCH_DELAY 再检查
		hs.timer.doAfter(SWITCH_DELAY, function()
			if hasExternalAudio() then
				print("[AudioSwitch] 唤醒后检测到外接显示器，切换音频")
				hs.alert.show("🖥️ 外接显示器 → 切换音频...", 1.0)
				switchToExternal()
			end
		end)
	end
end)
_WakeWatcher:start()

-- ---- 启动屏幕监听 ----
_ScreenWatcher = hs.screen.watcher.new(onScreenChange)
_ScreenWatcher:start()

-- ---- 启动时检查 ----
if hasExternalAudio() then
	print("[AudioSwitch] 启动时检测到外接音频设备，切换音频...")
	hs.timer.doAfter(SWITCH_DELAY, switchToExternal)
end
