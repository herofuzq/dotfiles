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

-- 纯锁屏：立即 hidden，解锁后走快速释放，不 probe。
gate.on_lock()
assert(#calls.hold == 1 and calls.hold[1].hidden == true and calls.hold[1].no_timeout == true)
assert(calls.close_popups == 1)
assert(calls.trigger[#calls.trigger] == "display_transition_begin")

gate.on_unlock()
local fast_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.25 then
		fast_callback = entry.callback
	end
end
assert(fast_callback, "pure lock must schedule a fast release")
fast_callback()
assert(#calls.release == 1, "pure lock fast release must release once")
assert(#calls.probe == 1, "pure lock fast release must not add a probe")

-- system_woke 单独出现不算真实显示器变化，不取消快速释放；
-- display_change 才算真实变化，必须转完整 settling。
gate.on_lock()
gate.on_unlock()
gate.on_display_event("system_woke")
assert(#calls.hold == 2, "system_woke alone must not cancel fast release")
gate.on_display_event("display_change")
assert(#calls.hold == 3, "display_change during fast window must enter settling")
assert(#calls.release == 1, "display_change during fast window must cancel the fast release")

-- 真睡眠：system_will_sleep 后解锁走单次快速 probe，无变化再释放。
gate.on_will_sleep()
gate.on_display_event("system_woke")
gate.on_unlock()
local sleep_verify_callback
for _, entry in ipairs(calls.delay) do
	if entry.seconds == 0.25 then
		sleep_verify_callback = entry.callback
	end
end
assert(sleep_verify_callback, "system sleep unlock must schedule fast verify")
sleep_verify_callback()
assert(#calls.probe == 2, "system sleep fast verify must probe once")
calls.probe[2]({ height_changed = false, monitor_changed = false, monitor_valid = true })
assert(#calls.release == 2, "system sleep no-change fast verify must release")

print("display_gate_test: ok")
