-- 显示器/睡眠/锁屏可见性门控状态机。
-- spaces.lua 只负责注册 probe/apply 回调，不再直接持有这套状态。
local sbar = require("sketchybar")
local display_policy = require("helpers.display_policy")
local enter_animation = require("helpers.enter_animation")

local M = {}
local handlers = {}

local SETTLE_PROBE_INTERVAL = 0.2
local SETTLE_QUIET_PROBES = 4
local SETTLE_MAX_SECONDS = 3.5
local SLEEP_FAILSAFE_SECONDS = 75
local SETTLE_ABSOLUTE_MAX_SECONDS = 10
local GATE_HOLD_TIMEOUT_SECONDS = 12
local REVEAL_GRACE_SECONDS = 3
-- 第一次解锁后只等一个固定短窗口；后续重复 unlock 不再重置，
-- 避免 macOS 分两波投递 screen_unlocked 时把等待拖到 1s 以上。
local LOCK_FAST_RELEASE_DELAY_SECONDS = 0.5
local POST_SLEEP_VERIFY_SECONDS = 12

local gate_state = "idle"
local gate_generation = 0
local gate_token = nil
local gate_probes_since_event = 0
local gate_last_valid_key = nil
local gate_settling_started = 0
local gate_session_started = 0
local gate_revealed_at = 0
local gate_had_wake = false
local gate_failsafe_armed = false
local gate_session_from_sleep = false
local gate_post_sleep_verify_until = 0
local gate_aftershock_generation = 0
local gate_fast_release_scheduled = false
local gate_fast_release_generation = 0
local gate_had_display_change = false
local gate_from_system_sleep = false

local gate_probe
local gate_reveal
local gate_enter_settling
local gate_schedule_fast_release
local gate_schedule_fast_verify
local gate_verify_post_sleep_event
local gate_verify_awake_event
local gate_on_will_sleep
local gate_on_unlock

local function close_popups()
	if handlers.close_popups then
		handlers.close_popups()
	end
end

local function probe(on_done)
	if handlers.probe then
		handlers.probe(on_done)
	end
end

local function apply(snapshot, on_complete)
	if handlers.apply then
		handlers.apply(snapshot, on_complete)
	end
end

local function trigger_transition_begin()
	sbar.trigger("display_transition_begin")
end

local function trigger_topology_change()
	if handlers.on_topology_change then
		handlers.on_topology_change()
	else
		sbar.trigger("display_topology_change")
	end
end

gate_reveal = function(snapshot)
	gate_state = "revealing"
	local reveal_generation = gate_generation
	local reveal_token = gate_token
	local reveal_from_sleep = gate_session_from_sleep
	if not snapshot.monitor_valid then
		snapshot.monitor_changed = false
	end
	local function on_reveal_complete()
		if gate_generation ~= reveal_generation or gate_state ~= "revealing" then
			return
		end
		gate_revealed_at = os.time()
		gate_post_sleep_verify_until = reveal_from_sleep
			and (gate_revealed_at + POST_SLEEP_VERIFY_SECONDS)
			or 0
		gate_session_from_sleep = false
		gate_state = "idle"
	end
	if snapshot.height_changed or snapshot.monitor_changed then
		if gate_had_wake then
			trigger_topology_change()
		end
		apply(snapshot, function()
			enter_animation.release(reveal_token, on_reveal_complete)
		end)
	else
		enter_animation.release(reveal_token, on_reveal_complete)
	end
end

gate_probe = function(gen)
	sbar.delay(SETTLE_PROBE_INTERVAL, function()
		if gen ~= gate_generation or gate_state ~= "settling" then
			return
		end
		probe(function(snapshot)
			if gen ~= gate_generation or gate_state ~= "settling" then
				return
			end
			gate_probes_since_event = gate_probes_since_event + 1
			local timed_out = (os.time() - gate_settling_started) >= SETTLE_MAX_SECONDS
				or (os.time() - gate_session_started) >= SETTLE_ABSOLUTE_MAX_SECONDS
			if snapshot.monitor_valid and not timed_out then
				local valid_key = tostring(snapshot.height) .. "|" .. snapshot.monitor_signature
					.. "|" .. tostring(snapshot.topology_signature)
				local stable = gate_last_valid_key == valid_key
				gate_last_valid_key = valid_key
				if not stable or gate_probes_since_event < SETTLE_QUIET_PROBES then
					gate_probe(gen)
					return
				end
			elseif not timed_out then
				gate_probe(gen)
				return
			end
			gate_reveal(snapshot)
		end)
	end)
end

gate_enter_settling = function()
	if gate_state == "revealing" then
		return
	end
	if gate_state ~= "settling" then
		gate_session_started = os.time()
	end
	gate_state = "settling"
	gate_generation = gate_generation + 1
	gate_token = enter_animation.hold({ hidden = true, timeout = GATE_HOLD_TIMEOUT_SECONDS })
	gate_probes_since_event = 0
	gate_last_valid_key = nil
	gate_settling_started = os.time()
	gate_probe(gate_generation)
end

gate_schedule_fast_release = function()
	if gate_fast_release_scheduled then
		return
	end
	gate_fast_release_generation = gate_fast_release_generation + 1
	local fast_gen = gate_fast_release_generation
	gate_fast_release_scheduled = true
	sbar.delay(LOCK_FAST_RELEASE_DELAY_SECONDS, function()
		if gate_state ~= "sleep_hidden" or gate_fast_release_generation ~= fast_gen then
			return
		end
		gate_fast_release_scheduled = false
		gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
	end)
end

gate_schedule_fast_verify = function()
	if gate_fast_release_scheduled then
		return
	end
	gate_fast_release_generation = gate_fast_release_generation + 1
	local fast_gen = gate_fast_release_generation
	gate_fast_release_scheduled = true
	sbar.delay(LOCK_FAST_RELEASE_DELAY_SECONDS, function()
		if gate_state ~= "sleep_hidden" or gate_fast_release_generation ~= fast_gen then
			return
		end
		gate_fast_release_scheduled = false
		probe(function(snapshot)
			if gate_state ~= "sleep_hidden" or gate_fast_release_generation ~= fast_gen then
				return
			end
			if snapshot.height_changed or snapshot.monitor_changed then
				gate_session_from_sleep = false
				gate_had_wake = true
				close_popups()
				trigger_transition_begin()
				gate_enter_settling()
			else
				gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
			end
		end)
	end)
end

gate_verify_post_sleep_event = function(source_event)
	gate_aftershock_generation = gate_aftershock_generation + 1
	local verify_generation = gate_aftershock_generation
	sbar.delay(SETTLE_PROBE_INTERVAL, function()
		if verify_generation ~= gate_aftershock_generation or gate_state ~= "idle" then
			return
		end
		probe(function(snapshot)
			if verify_generation ~= gate_aftershock_generation or gate_state ~= "idle" then
				return
			end
			if snapshot.height_changed or snapshot.monitor_changed then
				gate_post_sleep_verify_until = 0
				gate_session_from_sleep = false
				gate_had_wake = source_event == "system_woke"
				close_popups()
				trigger_transition_begin()
				gate_enter_settling()
			end
		end)
	end)
end

gate_verify_awake_event = function(source_event)
	gate_aftershock_generation = gate_aftershock_generation + 1
	local verify_generation = gate_aftershock_generation
	sbar.delay(SETTLE_PROBE_INTERVAL, function()
		if verify_generation ~= gate_aftershock_generation or gate_state ~= "idle" then
			return
		end
		probe(function(snapshot)
			if verify_generation ~= gate_aftershock_generation or gate_state ~= "idle" then
				return
			end
			if not snapshot.height_changed and not snapshot.monitor_changed then
				return
			end
			gate_session_from_sleep = false
			gate_post_sleep_verify_until = 0
			gate_had_wake = source_event == "system_woke"
			close_popups()
			trigger_transition_begin()
			gate_enter_settling()
		end)
	end)
end

local function gate_on_display_event(source_event)
	local action = display_policy.classify(
		gate_state,
		os.time(),
		gate_revealed_at,
		gate_post_sleep_verify_until,
		REVEAL_GRACE_SECONDS
	)
	if action == "ignore" or action == "absorb" then
		return
	end
	if action == "absorb_wake" then
		gate_had_wake = true
		if source_event == "display_change" then
			gate_had_display_change = true
		end
		if gate_fast_release_scheduled and gate_had_display_change then
			gate_fast_release_scheduled = false
			gate_fast_release_generation = gate_fast_release_generation + 1
			gate_enter_settling()
			return
		end
		if not gate_failsafe_armed then
			gate_failsafe_armed = true
			local gen = gate_generation
			sbar.delay(SLEEP_FAILSAFE_SECONDS, function()
				if gate_state == "sleep_hidden" and gate_generation == gen then
					io.stderr:write("display_gate: 75s failsafe fired, force settling\n")
					gate_enter_settling()
				end
			end)
		end
		return
	end
	if action == "verify_post_sleep" then
		gate_verify_post_sleep_event(source_event)
		return
	end
	if action == "renew" then
		gate_had_wake = gate_had_wake or source_event == "system_woke"
		gate_enter_settling()
		return
	end
	if action == "verify" then
		gate_verify_awake_event(source_event)
		return
	end
end

gate_on_will_sleep = function(from_system_sleep)
	gate_state = "sleep_hidden"
	gate_generation = gate_generation + 1
	gate_fast_release_generation = gate_fast_release_generation + 1
	gate_fast_release_scheduled = false
	gate_failsafe_armed = false
	gate_had_wake = false
	gate_had_display_change = false
	gate_from_system_sleep = from_system_sleep == true
	gate_session_from_sleep = true
	gate_post_sleep_verify_until = 0
	gate_aftershock_generation = gate_aftershock_generation + 1
	close_popups()
	trigger_transition_begin()
	gate_token = enter_animation.hold({ hidden = true, no_timeout = true })
end

gate_on_unlock = function()
	if gate_state == "sleep_hidden" then
		if gate_had_display_change then
			gate_enter_settling()
		elseif not gate_from_system_sleep then
			gate_schedule_fast_release()
		elseif gate_had_wake then
			gate_schedule_fast_verify()
		else
			gate_schedule_fast_release()
		end
	end
end

function M.configure(options)
	handlers = options or {}
end

function M.on_display_event(source_event)
	gate_on_display_event(source_event)
end

function M.on_will_sleep()
	gate_on_will_sleep(true)
end

function M.on_lock()
	gate_on_will_sleep(false)
end

function M.on_unlock()
	gate_on_unlock()
end

return M
