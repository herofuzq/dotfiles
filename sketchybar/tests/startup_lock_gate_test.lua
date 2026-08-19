local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local calls
local lock_callbacks

package.preload["sketchybar"] = function()
	return {
		delay = function(seconds, callback)
			calls.delay[#calls.delay + 1] = { seconds = seconds, callback = callback }
		end,
		trigger = function(name)
			calls.trigger[#calls.trigger + 1] = name
		end,
	}
end

package.preload["helpers.lock_state"] = function()
	return {
		probe = function(callback)
			lock_callbacks[#lock_callbacks + 1] = callback
		end,
	}
end

package.preload["helpers.enter_animation"] = function()
	return {
		hold = function(options)
			calls.hold[#calls.hold + 1] = options
			return #calls.hold
		end,
		release = function(token, on_complete)
			calls.release[#calls.release + 1] = token
			if on_complete then
				on_complete()
			end
		end,
	}
end

local function fresh_gate()
	calls = { delay = {}, trigger = {}, hold = {}, release = {}, display_probe = {} }
	lock_callbacks = {}
	package.loaded["helpers.display_gate"] = nil
	local gate = require("helpers.display_gate")
	gate.configure({
		probe = function(callback)
			calls.display_probe[#calls.display_probe + 1] = callback
		end,
		apply = function(_, on_complete)
			if on_complete then
				on_complete()
			end
		end,
		close_popups = function() end,
	})
	gate.begin_startup()
	return gate
end

local function delays_with(seconds)
	local found = {}
	for _, entry in ipairs(calls.delay) do
		if entry.seconds == seconds then
			found[#found + 1] = entry
		end
	end
	return found
end

local function last_delay(seconds)
	local found = delays_with(seconds)
	return found[#found]
end

local function request_reveal(gate)
	local authorizations = 0
	gate.request_startup_reveal(function()
		authorizations = authorizations + 1
	end)
	return function()
		return authorizations
	end
end

-- Fresh startup has no explicit lock/sleep evidence: only the second completed
-- unknown probe may use the approved fail-open policy.
do
	local gate = fresh_gate()
	local authorized = request_reveal(gate)
	assert(#lock_callbacks == 1 and authorized() == 0)
	lock_callbacks[1](nil, "timeout")
	assert(authorized() == 0, "first fresh unknown must stay hidden")
	assert(last_delay(0.5), "fresh unknown must schedule the bounded second attempt").callback()
	assert(#lock_callbacks == 2)
	lock_callbacks[2](nil, "invalid")
	assert(authorized() == 1, "second fresh unknown may fail open exactly once")
	lock_callbacks[2]("unlocked")
	assert(authorized() == 1, "late duplicate probe completion must not authorize twice")
end

-- An inherited/isolated unlock notification is not current-session evidence and
-- must not bypass the fresh two-unknown policy.
do
	local gate = fresh_gate()
	gate.on_unlock()
	local authorized = request_reveal(gate)
	assert(authorized() == 0 and #lock_callbacks == 1,
		"isolated startup unlock must not authorize reveal")
	lock_callbacks[1](nil, "timeout")
	assert(authorized() == 0)
	assert(last_delay(0.5), "isolated unlock must leave the fresh retry policy intact").callback()
	lock_callbacks[2](nil, "timeout")
	assert(authorized() == 1, "fresh policy still authorizes only after two unknown probes")
end

-- Explicit lock evidence keeps every unknown fail-closed; strict unlocked is
-- the only probe result that may authorize.
do
	local gate = fresh_gate()
	gate.on_lock()
	assert(#calls.hold == 0, "startup-hidden lock must not create a second runtime hold")
	local authorized = request_reveal(gate)
	lock_callbacks[1](nil, "timeout")
	assert(authorized() == 0)
	assert(last_delay(1.0), "explicit evidence unknown must use fail-closed polling").callback()
	lock_callbacks[2](nil, "invalid")
	assert(authorized() == 0, "repeated unknown after explicit lock must never fail open")
	assert(last_delay(1.0), "explicit evidence unknown must keep polling").callback()
	lock_callbacks[3]("unlocked")
	assert(authorized() == 1, "strict unlocked probe must authorize once")
end

-- system_will_sleep during startup-hidden has the same fail-closed evidence
-- contract as screen lock, but must not create a second runtime hold.
do
	local gate = fresh_gate()
	gate.on_will_sleep()
	assert(#calls.hold == 0, "startup-hidden sleep must not create a second runtime hold")
	local authorized = request_reveal(gate)
	lock_callbacks[1](nil, "timeout")
	assert(authorized() == 0 and last_delay(1.0),
		"startup-hidden sleep must make unknown fail-closed")
end

-- A current startup session unlock notification may expedite reveal only after
-- this Lua session observed lock/sleep/wake evidence.
do
	local gate = fresh_gate()
	gate.on_display_event("system_woke")
	assert(#calls.hold == 0, "startup-hidden wake evidence must not create a runtime hold")
	local authorized = request_reveal(gate)
	assert(authorized() == 0)
	gate.on_unlock()
	assert(authorized() == 1, "current-session unlock notification must authorize once")
	gate.on_unlock()
	assert(authorized() == 1, "repeated unlock notification must remain one-shot")
	lock_callbacks[1]("unlocked")
	assert(authorized() == 1, "late probe after unlock authorization must be stale")
end

-- A newer explicit lock/sleep/wake event invalidates an earlier unlock signal.
-- lock -> unlock -> lock before reveal request must remain fail-closed.
do
	local gate = fresh_gate()
	gate.on_lock()
	gate.on_unlock()
	gate.on_lock()
	local authorized = request_reveal(gate)
	assert(authorized() == 0 and #lock_callbacks == 1,
		"new lock evidence must invalidate an earlier startup unlock signal")
	lock_callbacks[1](nil, "timeout")
	assert(authorized() == 0 and last_delay(1.0),
		"lock-unlock-lock sequence must keep unknown fail-closed")
end

-- A lock arriving after a probe starts invalidates that probe's stale unlocked
-- result and establishes fail-closed evidence for the replacement request.
do
	local gate = fresh_gate()
	local authorized = request_reveal(gate)
	local stale_probe = lock_callbacks[1]
	gate.on_lock()
	stale_probe("unlocked")
	assert(authorized() == 0, "pre-lock probe result must not reveal after a newer lock event")
	assert(last_delay(1.0), "new explicit lock evidence must schedule a fresh probe").callback()
	assert(#lock_callbacks == 2)
	lock_callbacks[2]("unlocked")
	assert(authorized() == 1)
end

-- A startup-hidden display event is recorded without establishing lock evidence,
-- then consumed exactly once through the normal verify-first runtime path after
-- a successful ownership handoff.
do
	local gate = fresh_gate()
	gate.on_display_event("display_change")
	assert(#calls.delay == 0 and #calls.hold == 0,
		"startup-hidden display change must stay hidden without entering runtime gate")
	local authorized = request_reveal(gate)
	lock_callbacks[1]("unlocked")
	assert(authorized() == 1)
	gate.finish_startup_reveal()
	assert(#delays_with(0.3) == 1,
		"handoff must replay one pending display event through normal verify-first logic")
	delays_with(0.3)[1].callback()
	assert(#calls.display_probe == 1, "pending display event must issue one runtime probe")
	gate.finish_startup_reveal()
	assert(#delays_with(0.3) == 1, "startup finish must be idempotent")
end

-- init wiring must establish gate ownership before item configuration and run
-- prepare -> conceal -> reveal -> run exactly once. The gate handoff happens
-- only when startup.reveal's fade completion fires.
do
	local sequence = {}
	local reveal_completion
	local function record(name)
		sequence[#sequence + 1] = name
	end
	local item = { subscribe = function() end }
	local init_sbar = {
		add = function() return item end,
		exec = function() end,
		delay = function() end,
		event_loop = function() record("event_loop") end,
	}
	local init_gate = {
		begin_startup = function() record("begin_startup") end,
		request_startup_reveal = function(callback)
			record("request")
			callback()
		end,
		finish_startup_reveal = function() record("finish") end,
	}
	local init_startup = {
		configure = function(callback)
			record("configure")
			callback()
		end,
		when_ready = function(callback)
			record("when_ready")
			callback(false)
		end,
		reveal_on_unlock = function(callback)
			record("legacy_reveal_on_unlock")
			callback()
		end,
		reveal = function(callback)
			record("reveal")
			reveal_completion = callback
		end,
	}
	local init_animation = {
		install = function() end,
		prepare = function() record("prepare") end,
		conceal = function() record("conceal") end,
		run = function() record("run") end,
	}

	package.loaded["sketchybar"] = init_sbar
	package.loaded["helpers.display_gate"] = init_gate
	package.loaded["helpers.startup"] = init_startup
	package.loaded["helpers.enter_animation"] = init_animation
	package.loaded["appearance"] = {
		install_defaults = function() end,
		build_system_theme_probe_command = function() return "true" end,
		apply_system_theme_probe_result = function() end,
		read_scheme_state = function() return nil, "missing" end,
		switch_scheme = function() end,
	}
	package.loaded["helpers.window_border"] = { install = function() end }
	package.loaded["helpers.utils"] = {
		parse_boot_epoch = function() return nil end,
		tmp_path = function(name) return "/tmp/" .. name end,
	}
	package.loaded["bar"] = nil
	package.loaded["items"] = nil
	package.preload["bar"] = function() return true end
	package.preload["items"] = function() return true end

	local original_popen = io.popen
	io.popen = function()
		return {
			read = function() return "" end,
			close = function() return true end,
		}
	end
	local init_chunk = assert(loadfile(repo_root .. "sketchybar/.config/sketchybar/init.lua"))
	local ok, err = pcall(init_chunk)
	io.popen = original_popen
	assert(ok, err)
	assert(
		table.concat(sequence, ",")
			== "begin_startup,configure,when_ready,request,prepare,conceal,reveal,run,event_loop",
		"init must use the display gate as the single startup visibility owner"
	)
	assert(type(reveal_completion) == "function", "init must pass a fade completion callback")
	reveal_completion()
	assert(sequence[#sequence] == "finish", "gate handoff must happen only after startup fade completion")
end

print("startup_lock_gate_test: ok")
