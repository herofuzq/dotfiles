local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local calls = {
	hold = {},
	release = {},
	delay = {},
	trigger = {},
	probe = {},
	apply = {},
	close_popups = 0,
}
local sbar = {
	delay = function(seconds, callback)
		calls.delay[#calls.delay + 1] = { seconds = seconds, callback = callback }
	end,
	trigger = function(name)
		calls.trigger[#calls.trigger + 1] = name
	end,
}
package.preload["sketchybar"] = function() return sbar end
package.preload["helpers.enter_animation"] = function()
	return {
		hold = function(opts)
			calls.hold[#calls.hold + 1] = opts
			return #calls.hold
		end,
		release = function(token, on_complete)
			calls.release[#calls.release + 1] = { token = token, on_complete = on_complete }
			if on_complete then
				on_complete()
			end
		end,
	}
end

local gate = require("helpers.display_gate")
gate.configure({
	probe = function(on_done)
		calls.probe[#calls.probe + 1] = on_done
	end,
	apply = function(snapshot, on_complete)
		calls.apply[#calls.apply + 1] = snapshot
		if on_complete then
			on_complete()
		end
	end,
	close_popups = function()
		calls.close_popups = calls.close_popups + 1
	end,
	on_transition_begin = function()
		sbar.trigger("display_transition_begin")
	end,
	on_topology_change = function()
		sbar.trigger("display_topology_change")
	end,
})

-- 清醒 display_change：先 probe，无变化则零动作。
gate.on_display_event("display_change")
local verify_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.2 then
		verify_callback = entry.callback
	end
end
assert(verify_callback, "awake event must schedule a verify probe")
verify_callback()
assert(#calls.probe == 1, "awake event must probe once")
calls.probe[1]({ height_changed = false, monitor_changed = false, monitor_valid = true })
assert(#calls.hold == 0, "no-change probe must not enter settling")

-- 纯锁屏：立即 hidden，第一次解锁进入冷静期，期间不 probe。
gate.on_lock()
assert(#calls.hold == 1 and calls.hold[1].hidden == true and calls.hold[1].no_timeout == true)
assert(calls.close_popups == 1)
assert(calls.trigger[#calls.trigger] == "display_transition_begin")

gate.on_unlock()
local quiet_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.3 then
		quiet_callback = entry.callback
	end
end
assert(quiet_callback, "pure lock must schedule a quiet release")
quiet_callback()
assert(#calls.release == 1, "pure lock quiet release must release once")
assert(#calls.probe == 1, "pure lock quiet release must not add a probe")

-- 安静窗口内 system_woke / display_change 会重置计时，但不会重复隐藏或转 settling。
gate.on_lock()
gate.on_unlock()
local delays_before_events = #calls.delay
gate.on_display_event("system_woke")
gate.on_display_event("display_change")
assert(#calls.hold == 2, "cooldown must ignore all late events")
assert(#calls.delay > delays_before_events, "late events must reset the quiet timer")
local quiet2
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.3 then
		quiet2 = entry.callback
	end
end
assert(quiet2, "second pure lock must schedule another quiet release")
quiet2()
assert(#calls.release == 2, "second quiet release must release once")

-- 真睡眠：system_will_sleep 后解锁走单次快速 probe，无变化再释放。
gate.on_will_sleep()
gate.on_display_event("system_woke")
gate.on_unlock()
local sleep_verify_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.5 then
		sleep_verify_callback = entry.callback
	end
end
assert(sleep_verify_callback, "system sleep unlock must schedule fast verify")
sleep_verify_callback()
assert(#calls.probe == 2, "system sleep fast verify must probe once")
calls.probe[2]({ height_changed = false, monitor_changed = false, monitor_valid = true })
assert(#calls.release == 3, "system sleep no-change fast verify must release")

local real_os_time = os.time
local now = 100
os.time = function()
	return now
end

local function fresh_gate()
	calls = {
		hold = {},
		release = {},
		delay = {},
		trigger = {},
		probe = {},
		apply = {},
		close_popups = 0,
	}
	package.loaded["helpers.display_gate"] = nil
	local fresh = require("helpers.display_gate")
	fresh.configure({
		probe = function(on_done)
			calls.probe[#calls.probe + 1] = on_done
		end,
		apply = function(snapshot, on_complete)
			calls.apply[#calls.apply + 1] = snapshot
			if on_complete then
				on_complete()
			end
		end,
		close_popups = function()
			calls.close_popups = calls.close_popups + 1
		end,
		on_transition_begin = function()
			sbar.trigger("display_transition_begin")
		end,
		on_topology_change = function()
			sbar.trigger("display_topology_change")
		end,
	})
	return fresh
end

local function last_delay(seconds)
	for index = #calls.delay, 1, -1 do
		if calls.delay[index].seconds == seconds then
			return calls.delay[index]
		end
	end
	return nil
end

local function count_delays(seconds)
	local count = 0
	for _, entry in ipairs(calls.delay) do
		if entry.seconds == seconds then
			count = count + 1
		end
	end
	return count
end

local function start_settling(fresh)
	fresh.on_display_event("display_change")
	local verify = assert(last_delay(0.2), "display event must schedule a verify probe")
	verify.callback()
	local verify_probe = assert(calls.probe[#calls.probe], "verify delay must invoke the probe handler")
	verify_probe({
		height = 30,
		height_changed = true,
		monitor_changed = false,
		monitor_valid = true,
		monitor_signature = "display-a",
		topology_signature = "topology-a",
	})
	return assert(last_delay(10), "new settling session must arm a 10s watchdog"),
		assert(last_delay(0.2), "settling session must schedule a probe")
end

-- 永久丢失 settling probe 回调时，绝对 watchdog 仍会在 10s 释放当前 token。
do
	local fresh = fresh_gate()
	local watchdog, settling_probe = start_settling(fresh)
	settling_probe.callback()
	assert(#calls.probe == 2, "settling delay must invoke the probe handler")
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"10s watchdog must recover from permanent probe callback loss")
	assert(#calls.apply == 0, "absolute watchdog must reveal with a no-change snapshot")
end

-- renew 只续探测 generation，不得新建或推迟当前会话的绝对 watchdog。
do
	local fresh = fresh_gate()
	local watchdog = start_settling(fresh)
	assert(count_delays(10) == 1, "new session must arm exactly one watchdog")
	fresh.on_display_event("display_change")
	assert(count_delays(10) == 1, "renew must not arm another watchdog")
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 2,
		"original watchdog must release the token current after renew")
end

-- 已正常结束的旧会话 watchdog 不能释放随后建立的新会话。
do
	local fresh = fresh_gate()
	local old_watchdog, old_probe_delay = start_settling(fresh)
	now = 104
	old_probe_delay.callback()
	local old_probe = assert(calls.probe[#calls.probe], "settling delay must invoke the probe handler")
	old_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	assert(#calls.release == 1, "legacy probe timeout must end the old session")

	now = 108
	local current_watchdog = start_settling(fresh)
	old_watchdog.callback()
	assert(#calls.release == 1, "old session watchdog must not release a newer session")
	current_watchdog.callback()
	assert(#calls.release == 2 and calls.release[2].token == 2,
		"current session watchdog must release the current token")
end

-- 会话身份不能依赖 os.time()：同一秒内建立的两个 settling 会话仍须彼此隔离。
do
	now = 200
	local fresh = fresh_gate()
	local old_watchdog = start_settling(fresh)
	local stable_snapshot = {
		height = 30,
		height_changed = false,
		monitor_changed = false,
		monitor_valid = true,
		monitor_signature = "display-a",
		topology_signature = "topology-a",
	}
	for _ = 1, 4 do
		local probe_delay = assert(last_delay(0.2), "stable settling session must keep probing")
		probe_delay.callback()
		local probe_callback = assert(calls.probe[#calls.probe], "probe delay must invoke the probe handler")
		probe_callback(stable_snapshot)
	end
	assert(#calls.release == 1, "stable probes must reveal the first session")

	fresh.on_will_sleep()
	fresh.on_display_event("system_woke")
	fresh.on_display_event("display_change")
	fresh.on_unlock()
	local current_watchdog = assert(last_delay(10), "second same-second session must arm a watchdog")
	assert(count_delays(10) == 2, "same-second sessions must each arm one watchdog")
	old_watchdog.callback()
	assert(#calls.release == 1, "same-second old watchdog must not release the new session")
	current_watchdog.callback()
	assert(#calls.release == 2 and calls.release[2].token == 3,
		"same-second current watchdog must release the current token")
end

os.time = real_os_time

print("display_gate_test: ok")
