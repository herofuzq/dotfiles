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

local function screenSignature()
	local ids = {}
	for _, screen in ipairs(hs.screen.allScreens()) do
		local ok, id = pcall(function() return screen:id() end)
		ids[#ids + 1] = ok and tostring(id) or tostring(screen:name())
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

-- ---- 内部状态 ----
local _screenSignature = screenSignature()
local _pendingTimer = nil

-- ---- 查找设备 ----
local function findDevice(transports)
	local devices = hs.audiodevice.allOutputDevices()
	for _, d in ipairs(devices) do
		local ok, transport = pcall(function() return d:transportType() end)
		if ok and transports[transport] then
			return d
		end
	end
	return nil
end

-- ---- 执行切换 ----
local function doSwitch(target, label)
	if not target then
		print("[AudioSwitch] 目标设备不存在")
		return false
	end
	local valid, isOutput = pcall(function() return target:isOutputDevice() end)
	if not valid or not isOutput then
		print("[AudioSwitch] 目标设备已失效")
		return false
	end

	local current = hs.audiodevice.defaultOutputDevice()
	local targetOK, targetUID = pcall(function() return target:uid() end)
	local currentOK, currentUID = pcall(function() return current and current:uid() end)
	if not targetOK then
		print("[AudioSwitch] 无法读取目标设备")
		return false
	end
	if currentOK and currentUID == targetUID then
		print("[AudioSwitch] 已是目标设备: " .. target:name())
		return true
	end

	local switched, result = pcall(function() return target:setDefaultOutputDevice() end)
	if switched and result then
		hs.alert.show(label .. target:name(), 1.5)
		print("[AudioSwitch] 已切换: " .. target:name())
		return true
	else
		print("[AudioSwitch] 切换失败: " .. tostring(result))
		return false
	end
end

local function switchToExternal(retries, onExhausted, device)
	retries = retries or RETRY_COUNT
	local ext = device or findDevice(EXTERNAL_TRANSPORTS)
	if ext then
		doSwitch(ext, "♪ → ")
		return
	end
	if retries > 0 then
		print("[AudioSwitch] 未找到外接音频设备，" .. retries .. " 秒后重试...")
		if _pendingTimer then _pendingTimer:stop() end
		_pendingTimer = hs.timer.doAfter(1, function()
			_pendingTimer = nil
			switchToExternal(retries - 1, onExhausted)
		end)
	else
		print("[AudioSwitch] 重试耗尽，未找到 HDMI/DisplayPort 音频设备")
		if onExhausted then
			onExhausted()
		else
			hs.alert.show("⚠ 未找到外接显示器音频设备", 1.5)
		end
	end
end

local function switchToInternal()
	local internal = findDevice(INTERNAL_TRANSPORTS)
	if internal then
		doSwitch(internal, "♪ → ")
	end
end

-- ---- 检测是否有外接音频设备 ----
local function hasExternalAudio()
	return findDevice(EXTERNAL_TRANSPORTS) ~= nil
end

local function hasExternalScreen()
	for _, screen in ipairs(hs.screen.allScreens()) do
		local name = screen:name() or ""
		if not name:find("Built%-in") then return true end
	end
	return false
end

local function reconcileAudio()
	_pendingTimer = nil
	local ext = findDevice(EXTERNAL_TRANSPORTS)
	if ext then
		switchToExternal(0, nil, ext)
	elseif hasExternalScreen() then
		-- 外接音频设备可能比屏幕晚出现，短暂重试；耗尽后保持当前输出。
		switchToExternal(RETRY_COUNT, function() end)
	else
		switchToInternal()
	end
end

local function scheduleReconcile()
	if _pendingTimer then _pendingTimer:stop() end
	_pendingTimer = hs.timer.doAfter(SWITCH_DELAY, reconcileAudio)
end

-- ---- 屏幕变化回调 ----
local function onScreenChange()
	local signature = screenSignature()
	if signature == _screenSignature then return end
	_screenSignature = signature

	-- 取消正在进行的延迟切换（快速插拔时防抖）
	if _pendingTimer then
		_pendingTimer:stop()
		_pendingTimer = nil
	end

	print("[AudioSwitch] 屏幕拓扑变化，" .. SWITCH_DELAY .. " 秒后检查音频设备...")
	scheduleReconcile()
end

-- ---- 系统唤醒监听（盒盖待机连接显示器场景） ----
_WakeWatcher = hs.caffeinate.watcher.new(function(eventType)
	if eventType == hs.caffeinate.watcher.systemDidWake then
		print("[AudioSwitch] 系统唤醒，检测显示器...")
		scheduleReconcile()
	end
end)
_WakeWatcher:start()

-- ---- 启动屏幕监听 ----
_ScreenWatcher = hs.screen.watcher.new(onScreenChange)
_ScreenWatcher:start()

-- ---- 启动时检查 ----
if hasExternalAudio() then
	print("[AudioSwitch] 启动时检测到外接音频设备，切换音频...")
	scheduleReconcile()
end
