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
local startup_lock_callbacks = {}
package.preload["helpers.lock_state"] = function()
	return {
		probe = function(callback)
			startup_lock_callbacks[#startup_lock_callbacks + 1] = callback
		end,
	}
end
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
	on_topology_change = function()
		sbar.trigger("display_topology_change")
	end,
})

-- 清醒 display_change：先 probe，无变化则零动作。
gate.on_display_event("display_change")
local verify_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.3 then
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
	local verify = assert(last_delay(0.3), "display event must schedule a verify probe")
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
		assert(last_delay(0.8), "settling session must arm a 0.8s quiet timer")
end

local stable_snapshot = {
	height = 30,
	height_changed = false,
	monitor_changed = false,
	monitor_valid = true,
	monitor_signature = "display-a",
	topology_signature = "topology-a",
}

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

-- 进入 settling 后先等待完整 0.8s 安静窗口，不得继承旧的即时 probe。
do
	local fresh = fresh_gate()
	local _, quiet = start_settling(fresh)
	assert(#calls.probe == 1, "settling must not probe before the 0.8s quiet timer")
	quiet.callback()
	assert(#calls.probe == 2, "latest 0.8s quiet timer must launch the first settling probe")
end

-- renew 重置安静窗口但不新建或推迟 10s watchdog；旧 quiet 失效。
do
	local fresh = fresh_gate()
	local watchdog, old_quiet = start_settling(fresh)
	assert(count_delays(10) == 1 and count_delays(0.8) == 1,
		"new session must arm one watchdog and one quiet timer")
	fresh.on_display_event("display_change")
	local current_quiet = assert(last_delay(0.8), "renew must arm a new quiet timer")
	assert(count_delays(10) == 1 and count_delays(0.8) == 2,
		"renew must reset quiet time without arming another watchdog")
	assert(#calls.hold == 1, "renew must not re-hold the whole bar")
	old_quiet.callback()
	assert(#calls.probe == 1, "superseded quiet timer must not launch a probe")
	current_quiet.callback()
	assert(#calls.probe == 2, "latest quiet timer must launch the settling probe")
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"original watchdog must release the original session token after renew")
end

-- 两个连续、有效且相同的 post-quiet snapshot 才能 reveal。
do
	local fresh = fresh_gate()
	local _, quiet = start_settling(fresh)
	quiet.callback()
	local first_probe = assert(calls.probe[2], "quiet timer must launch the first comparison")
	first_probe(stable_snapshot)
	assert(#calls.release == 0, "one valid post-quiet snapshot must not reveal")
	local retry = assert(last_delay(0.3), "first valid snapshot must schedule a serialized retry")
	retry.callback()
	local second_probe = assert(calls.probe[3], "retry must launch the second comparison")
	second_probe(stable_snapshot)
	assert(#calls.release == 1, "two identical valid post-quiet snapshots must reveal")
end

-- invalid 会打断连续性，mismatch 只更新候选 key；两者都串行 0.3s 重试。
do
	local fresh = fresh_gate()
	local _, quiet = start_settling(fresh)
	quiet.callback()
	local first_probe = assert(calls.probe[2], "quiet timer must launch the first comparison")
	first_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	assert(#calls.release == 0 and #calls.probe == 2,
		"invalid snapshot must not reveal or launch a parallel probe")
	assert(last_delay(0.3), "invalid snapshot must schedule a retry").callback()
	local valid_a = assert(calls.probe[3], "invalid retry must launch one probe")
	valid_a(stable_snapshot)
	assert(#calls.release == 0 and #calls.probe == 3,
		"first valid snapshot after invalid must start a new pair")
	assert(last_delay(0.3), "first valid snapshot must retry serially").callback()
	local mismatch_snapshot = {
		height = 30,
		height_changed = false,
		monitor_changed = false,
		monitor_valid = true,
		monitor_signature = "display-b",
		topology_signature = "topology-b",
	}
	local valid_b_first = assert(calls.probe[4], "valid retry must launch one probe")
	valid_b_first(mismatch_snapshot)
	assert(#calls.release == 0 and #calls.probe == 4,
		"mismatched valid snapshot must not reveal or launch a parallel probe")
	assert(last_delay(0.3), "mismatched snapshot must schedule a retry").callback()
	local valid_b_second = assert(calls.probe[5], "mismatch retry must launch one probe")
	valid_b_second(mismatch_snapshot)
	assert(#calls.release == 1, "a consecutive identical pair after mismatch must reveal")
end

-- renew 期间已有 settling probe 在途时，旧回调须先释放自己的 owner
-- 并丢弃 payload；若它早于新 quiet 到达，绝不能启动下一个 probe。
do
	local fresh = fresh_gate()
	local _, old_quiet = start_settling(fresh)
	old_quiet.callback()
	local old_probe = assert(calls.probe[#calls.probe], "quiet timer must invoke the old probe")
	local probes_before_renew = #calls.probe

	fresh.on_display_event("display_change")
	local new_quiet = assert(last_delay(0.8), "renew must schedule the latest quiet timer")

	old_probe({
		height = 99,
		height_changed = true,
		monitor_changed = true,
		monitor_valid = true,
		monitor_signature = "stale-display",
		topology_signature = "stale-topology",
	})
	assert(#calls.probe == probes_before_renew,
		"old callback before renewed quiet must not launch another probe")
	assert(#calls.apply == 0 and #calls.release == 0,
		"same-session old-generation callback must discard its stale payload")
	new_quiet.callback()
	assert(#calls.probe == probes_before_renew + 1,
		"renewed quiet timer may launch the next probe after the old owner clears")
end

-- quiet 到期时旧 owner 仍在途，只保留一个当前 pending；旧 request
-- 的重复回调不能清掉新 owner。
do
	local fresh = fresh_gate()
	local _, first_quiet = start_settling(fresh)
	first_quiet.callback()
	local first_probe = assert(calls.probe[#calls.probe], "first settling probe must be active")

	fresh.on_display_event("display_change")
	assert(last_delay(0.8), "first renew must schedule a quiet timer").callback()
	first_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	local second_probe = assert(calls.probe[#calls.probe], "old callback must drain the second probe")
	local probes_with_second_active = #calls.probe

	first_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	fresh.on_display_event("display_change")
	assert(last_delay(0.8), "second renew must schedule a quiet timer").callback()
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
	local watchdog, quiet = start_settling(fresh)
	quiet.callback()
	assert(#calls.probe == 2, "quiet timer must invoke the probe handler")
	local lost_probe = calls.probe[2]
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"10s watchdog must recover from permanent probe callback loss")
	assert(#calls.apply == 0, "absolute watchdog must reveal with a no-change snapshot")
	lost_probe({ height_changed = false, monitor_changed = false, monitor_valid = true })
	assert(#calls.release == 1, "watchdog must invalidate the lost settling request")
end

-- 持续 invalid snapshot 不再有3.5s 等旧绝对释放；只有 10s watchdog 能终止。
do
	local fresh = fresh_gate()
	local watchdog, quiet = start_settling(fresh)
	quiet.callback()
	local invalid_probe = assert(calls.probe[2], "quiet timer must launch a comparison")
	now = 109
	invalid_probe({ height_changed = false, monitor_changed = false, monitor_valid = false })
	assert(#calls.release == 0, "invalid snapshot before 10s watchdog must stay gated")
	local retry = assert(last_delay(0.3), "invalid snapshot must keep retrying")
	retry.callback()
	assert(#calls.probe == 3 and #calls.release == 0,
		"serialized retry must continue without an absolute probe timeout")
	watchdog.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"10s watchdog must be the sole absolute release")
end

-- 已正常结束的旧会话 watchdog 不能释放随后建立的新会话。
do
	now = 100
	local fresh = fresh_gate()
	local old_watchdog, old_quiet = start_settling(fresh)
	old_quiet.callback()
	local first_probe = assert(calls.probe[#calls.probe], "quiet timer must launch the first comparison")
	first_probe(stable_snapshot)
	assert(last_delay(0.3), "first valid snapshot must schedule a retry").callback()
	local second_probe = assert(calls.probe[#calls.probe], "retry must launch the second comparison")
	second_probe(stable_snapshot)
	assert(#calls.release == 1, "stable pair must end the old session")

	now = 111
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
	local old_watchdog, quiet = start_settling(fresh)
	quiet.callback()
	local first_probe = assert(calls.probe[#calls.probe], "quiet timer must launch the first comparison")
	first_probe(stable_snapshot)
	assert(last_delay(0.3), "first valid snapshot must schedule a retry").callback()
	local second_probe = assert(calls.probe[#calls.probe], "retry must launch the second comparison")
	second_probe(stable_snapshot)
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

-- Startup reveal 已获授权但 fade 尚未结束时若收到新锁/睡事件，
-- 必须立刻转入 runtime hidden；startup completion 不得重置新 FSM/token。
for _, scenario in ipairs({
	{
		name = "lock",
		enter_hidden = function(gate) gate.on_lock() end,
		release_delay = 0.3,
	},
	{
		name = "sleep",
		enter_hidden = function(gate) gate.on_will_sleep() end,
		release_delay = 0.5,
	},
}) do
	startup_lock_callbacks = {}
	local fresh = fresh_gate()
	fresh.begin_startup()
	local authorizations = 0
	fresh.request_startup_reveal(function()
		authorizations = authorizations + 1
	end)
	assert(#startup_lock_callbacks == 1)
	startup_lock_callbacks[1]("unlocked")
	assert(authorizations == 1, "strict unlocked must authorize startup reveal")

	scenario.enter_hidden(fresh)
	assert(#calls.hold == 1 and calls.hold[1].hidden == true and calls.hold[1].no_timeout == true,
		scenario.name .. " during startup fade must enter the runtime hidden gate")
	fresh.finish_startup_reveal()
	fresh.on_unlock()
	local release_timer = assert(last_delay(scenario.release_delay),
		"startup completion must preserve the newer " .. scenario.name .. " runtime state")
	release_timer.callback()
	assert(#calls.release == 1 and calls.release[1].token == 1,
		"preserved runtime gate must release its own token after " .. scenario.name .. " unlock")
end

-- 清醒 settling reveal 后进入 10s 冷却：冷却期内事件不立即 probe/隐藏，
-- 只安排一次到期复核；重复事件更新待复核来源，不叠加定时器。
do
	now = 300
	local fresh = fresh_gate()
	local _, quiet = start_settling(fresh)
	quiet.callback()
	local first_probe = assert(calls.probe[2], "quiet timer must launch the first comparison")
	first_probe(stable_snapshot)
	assert(last_delay(0.3), "first valid snapshot must schedule a retry").callback()
	local second_probe = assert(calls.probe[3], "retry must launch the second comparison")
	second_probe(stable_snapshot)
	assert(#calls.release == 1, "stable pair must end the first session")

	now = 303
	fresh.on_display_event("display_change")
	assert(#calls.probe == 3, "cooldown event must not probe immediately")
	local cooldown_verify = assert(last_delay(7), "cooldown must arm one deferred verify")
	fresh.on_display_event("system_woke")
	assert(count_delays(7) == 1, "repeated cooldown events must reuse the deferred verify")

	now = 310
	cooldown_verify.callback()
	local verify_delay = assert(last_delay(0.3), "cooldown expiry must run the normal verify path")
	verify_delay.callback()
	local verify_probe = assert(calls.probe[4], "cooldown expiry must issue one probe")
	verify_probe({ height_changed = false, monitor_changed = false, monitor_valid = true })
	assert(#calls.hold == 1 and #calls.release == 1,
		"unchanged cooldown verify must not start another settle session")
end

-- 已处于 sleep_hidden 时重复 lock / will_sleep 只更新状态，不再重复隐藏整条 bar。
do
	local fresh = fresh_gate()
	fresh.on_lock()
	assert(#calls.hold == 1, "first lock must hold once")
	fresh.on_lock()
	assert(#calls.hold == 1, "duplicate lock must not re-hold")
	fresh.on_will_sleep()
	assert(#calls.hold == 1, "will_sleep while already hidden must not re-hold")
end

-- 从 settling 转睡眠时必须重新 hold（用 no_timeout 作废旧 12s 超时）。
do
	now = 400
	local fresh = fresh_gate()
	start_settling(fresh)
	assert(#calls.hold == 1, "settling session must hold once")
	fresh.on_will_sleep()
	assert(#calls.hold == 2 and calls.hold[2].no_timeout == true,
		"settling -> sleep transition must re-hold with no_timeout")
end

os.time = real_os_time

print("display_gate_test: ok")
