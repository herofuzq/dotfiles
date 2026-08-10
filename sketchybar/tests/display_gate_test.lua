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

local function start_fast_verify(fresh)
	fresh.on_will_sleep()
	fresh.on_display_event("system_woke")
	fresh.on_unlock()
	local verify_delay = assert(last_delay(0.5), "system sleep unlock must schedule fast verify")
	verify_delay.callback()
	local verify_probe = assert(calls.probe[#calls.probe], "fast verify delay must invoke the probe handler")
	local verify_timeout = assert(last_delay(2.0), "fast verify must arm an exact 2s timeout")
	return verify_probe, verify_timeout
end

-- renew 期间已有 settling probe 在途时，只保留最新 pending；旧 generation
-- 回调须先释放自己的 owner、丢弃 payload，再立即排空当前 pending。
do
	local fresh = fresh_gate()
	local _, old_probe_delay = start_settling(fresh)
	old_probe_delay.callback()
	local old_probe = assert(calls.probe[#calls.probe], "settling delay must invoke the old probe")
	local probes_before_renew = #calls.probe

	fresh.on_display_event("display_change")
	assert(last_delay(0.2), "renew must schedule the latest settling request").callback()
	assert(#calls.probe == probes_before_renew,
		"renew while active must retain one pending request instead of issuing a second probe")

	old_probe({
		height = 99,
		height_changed = true,
		monitor_changed = true,
		monitor_valid = true,
		monitor_signature = "stale-display",
		topology_signature = "stale-topology",
	})
	assert(#calls.probe == probes_before_renew + 1,
		"same-session old-generation callback must drain the eligible current pending request")
	assert(#calls.apply == 0 and #calls.release == 0,
		"same-session old-generation callback must discard its stale payload")
end

-- 已排空 pending 并产生新 owner 后，旧 request 的重复回调不能清掉新 owner。
do
	local fresh = fresh_gate()
	local _, first_probe_delay = start_settling(fresh)
	first_probe_delay.callback()
	local first_probe = assert(calls.probe[#calls.probe], "first settling probe must be active")

	fresh.on_display_event("display_change")
	assert(last_delay(0.2), "first renew must schedule pending work").callback()
	first_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	local second_probe = assert(calls.probe[#calls.probe], "old callback must drain the second probe")
	local probes_with_second_active = #calls.probe

	first_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	fresh.on_display_event("display_change")
	assert(last_delay(0.2), "second renew must schedule pending work").callback()
	assert(#calls.probe == probes_with_second_active,
		"mismatched stale request must not clear the newer active owner")

	second_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	assert(#calls.probe == probes_with_second_active + 1,
		"newer active callback must still drain the latest eligible pending request")
end

-- fast verify 的 active 状态覆盖 0.5s delay 与 probe/timeout 全生命周期；重复 unlock 不得重入。
do
	local fresh = fresh_gate()
	start_fast_verify(fresh)
	local fast_delays = count_delays(0.5)
	local probes = #calls.probe
	fresh.on_unlock()
	assert(count_delays(0.5) == fast_delays, "duplicate unlock during verify must not schedule another delay")
	assert(#calls.probe == probes, "duplicate unlock during verify must issue only one probe")
end

-- valid unchanged callback 先完成后，2s timeout 必须成为 no-op。
do
	local fresh = fresh_gate()
	local verify_probe, verify_timeout = start_fast_verify(fresh)
	verify_probe({ height_changed = false, monitor_changed = false, monitor_valid = true })
	assert(#calls.release == 1, "valid unchanged fast verify must reveal")
	verify_timeout.callback()
	assert(#calls.release == 1 and #calls.hold == 1,
		"callback-first fast verify must make its timeout a no-op")
end

-- 2s timeout 先完成时进入 settling；迟到 callback 不能 reveal 或再次转移状态。
do
	local fresh = fresh_gate()
	local verify_probe, verify_timeout = start_fast_verify(fresh)
	verify_timeout.callback()
	assert(#calls.hold == 2 and #calls.release == 0,
		"fast verify timeout must enter settling without revealing")
	local delays_after_timeout = #calls.delay
	verify_probe({ height_changed = false, monitor_changed = false, monitor_valid = true })
	assert(#calls.hold == 2 and #calls.release == 0 and #calls.delay == delays_after_timeout,
		"timeout-first fast verify must make its late callback a no-op")
end

-- monitor 无效即使没有 change flag 也必须进入 settling，随后 timeout 不得重复终止。
do
	local fresh = fresh_gate()
	local verify_probe, verify_timeout = start_fast_verify(fresh)
	verify_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	assert(#calls.hold == 2 and #calls.release == 0,
		"invalid fast verify callback must enter settling")
	local delays_after_callback = #calls.delay
	verify_timeout.callback()
	assert(#calls.hold == 2 and #calls.release == 0 and #calls.delay == delays_after_callback,
		"invalid callback must make its fast verify timeout a no-op")
end

-- changed snapshot 也必须由 callback 终止 fast verify 并进入 settling。
do
	local fresh = fresh_gate()
	local verify_probe, verify_timeout = start_fast_verify(fresh)
	verify_probe({ height_changed = true, monitor_changed = false, monitor_valid = true })
	assert(#calls.hold == 2 and #calls.release == 0,
		"changed fast verify callback must enter settling")
	verify_timeout.callback()
	assert(#calls.hold == 2 and #calls.release == 0,
		"changed callback must make its fast verify timeout a no-op")
end

-- 永久丢失 settling probe 回调时，绝对 watchdog 仍会在 10s 释放当前 token。
do
	local fresh = fresh_gate()
	local watchdog, settling_probe = start_settling(fresh)
	settling_probe.callback()
	assert(#calls.probe == 2, "settling delay must invoke the probe handler")
	local lost_probe = calls.probe[2]
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"10s watchdog must recover from permanent probe callback loss")
	assert(#calls.apply == 0, "absolute watchdog must reveal with a no-change snapshot")
	lost_probe({ height_changed = false, monitor_changed = false, monitor_valid = true })
	assert(#calls.release == 1, "watchdog must invalidate the lost settling request")
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
