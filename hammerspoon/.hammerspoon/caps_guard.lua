-- Caps Lock should never stay enabled: Raycast maps Caps to Hyper, but the
-- system-level latch can occasionally leak through before Raycast handles it.
-- This is event-driven: no continuous polling loop.

local function clearCapsLock(reason)
	local ok, enabled = pcall(hs.hid.capslock.get)
	if not ok or not enabled then
		return
	end

	local cleared, state = pcall(hs.hid.capslock.set, false)
	if cleared then
		print("[caps_guard] cleared leaked Caps Lock via " .. tostring(reason) .. ": " .. tostring(state))
	else
		print("[caps_guard] failed to clear Caps Lock: " .. tostring(state))
	end
end

local function scheduleCapsLockClear(reason)
	clearCapsLock(reason)
	hs.timer.doAfter(0.05, function()
		clearCapsLock(reason .. "+50ms")
	end)
	hs.timer.doAfter(0.20, function()
		clearCapsLock(reason .. "+200ms")
	end)
end

-- hs.reload() 安全：先停止旧 tap 再创建新的
if _CapsGuardTap then
	_CapsGuardTap:stop()
end
_CapsGuardTap = hs.eventtap.new({
	hs.eventtap.event.types.flagsChanged,
	hs.eventtap.event.types.keyDown,
}, function(event)
	local flags = event:getFlags()
	if flags.capslock then
		scheduleCapsLockClear("event")
	end
	return false
end)
_CapsGuardTap:start()

clearCapsLock("startup")
print("[caps_guard] caps lock guard enabled")
