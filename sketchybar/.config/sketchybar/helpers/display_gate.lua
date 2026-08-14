-- 显示器/睡眠/锁屏可见性门控状态机。
-- spaces.lua 只负责注册 probe/apply 回调，不再直接持有这套状态。
local sbar = require("sketchybar")
local display_policy = require("helpers.display_policy")
local enter_animation = require("helpers.enter_animation")
local lock_state = require("helpers.lock_state")

local M = {}
local handlers = {}

local SETTLE_PROBE_INTERVAL = 0.2
local SETTLE_QUIET_SECONDS = 0.8
local SLEEP_FAILSAFE_SECONDS = 75
local SETTLE_ABSOLUTE_MAX_SECONDS = 10
local GATE_HOLD_TIMEOUT_SECONDS = 12
local REVEAL_GRACE_SECONDS = 3
-- 第一次解锁后只等一个固定短窗口；后续重复 unlock 不再重置，
-- 避免 macOS 分两波投递 screen_unlocked 时把等待拖到 1s 以上。
local LOCK_FAST_RELEASE_DELAY_SECONDS = 0.5
local LOCK_FAST_VERIFY_TIMEOUT_SECONDS = 2.0
-- 纯锁屏安静窗口：每次事件都重置，连续 0.3s 没有新事件才释放；
-- 4s 是兜底，防止事件风暴无限延长隐藏。
local LOCK_QUIET_SECONDS = 0.3
local LOCK_QUIET_MAX_SECONDS = 4
local POST_SLEEP_VERIFY_SECONDS = 12
local STARTUP_LOCK_RECHECK_SECONDS = 1.0
local STARTUP_UNKNOWN_RETRY_SECONDS = 0.5

local gate_state = "idle"
local gate_generation = 0
local gate_session_id = 0
local gate_token = nil
local gate_revealed_at = 0
local gate_had_wake = false
local gate_lock_recheck_request_id = 0
local gate_lock_recheck_active = nil
local gate_lock_session_id = 0
local gate_lock_unknown_streak = 0
local gate_session_from_sleep = false
local gate_post_sleep_verify_until = 0
local gate_aftershock_generation = 0
local gate_fast_release_scheduled = false
local gate_fast_release_generation = 0
local gate_had_display_change = false
local gate_from_system_sleep = false
local gate_cooldown_active = false
local gate_quiet_generation = 0
local gate_quiet_max_generation = 0
local gate_settle_request_id = 0
local gate_settle_active_request = nil
local gate_settle_pending_request = nil
local gate_settle_quiet_generation = 0
local gate_settle_stable_key = nil

-- startup hidden 与 runtime FSM 分开记账：上层已经隐藏 bar 时，
-- 锁/睡事件只记录证据，不创建第二个 enter_animation hold。
local startup_phase = "runtime"
local startup_generation = 0
local startup_explicit_evidence = false
local startup_unlock_evidence = false
local startup_reveal_requested = false
local startup_reveal_authorized = false
local startup_reveal_callback = nil
local startup_reveal_gate_generation = nil
local startup_unknown_count = 0
local startup_probe_request_id = 0
local startup_probe_active = nil
local startup_probe_schedule_generation = 0
local startup_pending_display_event = nil

local gate_issue_settling_probe
local gate_drain_settling_probe
local gate_queue_settling_probe
local gate_schedule_settling_retry
local gate_reveal
local gate_enter_settling
local gate_schedule_fast_release
local gate_schedule_fast_verify
local gate_verify_post_sleep_event
local gate_verify_awake_event
local gate_on_will_sleep
local gate_on_unlock
local gate_schedule_lock_recheck

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

local function invalidate_settling_probe_ownership()
	gate_settle_active_request = nil
	gate_settle_pending_request = nil
end

local function settling_request_is_current(request)
	return gate_state == "settling"
		and request.session_id == gate_session_id
		and request.generation == gate_generation
		and request.quiet_generation == gate_settle_quiet_generation
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

gate_drain_settling_probe = function()
	local pending = gate_settle_pending_request
	gate_settle_pending_request = nil
	if pending and settling_request_is_current(pending) then
		gate_issue_settling_probe(pending)
	end
end

gate_issue_settling_probe = function(request)
	gate_settle_request_id = gate_settle_request_id + 1
	request.request_id = gate_settle_request_id
	gate_settle_active_request = request
	probe(function(snapshot)
		if not gate_settle_active_request
			or gate_settle_active_request.request_id ~= request.request_id
		then
			return
		end

		-- 匹配的回调先释放自己的 owner；旧 generation 也必须让最新 pending 有机会接棒。
		gate_settle_active_request = nil
		if not settling_request_is_current(request) then
			gate_drain_settling_probe()
			return
		end

		if snapshot.monitor_valid then
			local valid_key = tostring(snapshot.height) .. "|" .. snapshot.monitor_signature
				.. "|" .. tostring(snapshot.topology_signature)
			if gate_settle_stable_key == valid_key then
				gate_reveal(snapshot)
				return
			end
			gate_settle_stable_key = valid_key
		else
			gate_settle_stable_key = nil
		end
		gate_schedule_settling_retry(request)
	end)
end

gate_queue_settling_probe = function(session_id, generation, quiet_generation)
	local request = {
		session_id = session_id,
		generation = generation,
		quiet_generation = quiet_generation,
	}
	if not settling_request_is_current(request) then
		return
	end
	if gate_settle_active_request then
		gate_settle_pending_request = request
		return
	end
	gate_issue_settling_probe(request)
end

gate_schedule_settling_retry = function(request)
	sbar.delay(SETTLE_PROBE_INTERVAL, function()
		if not settling_request_is_current(request) then
			return
		end
		gate_queue_settling_probe(
			request.session_id,
			request.generation,
			request.quiet_generation
		)
	end)
end

gate_enter_settling = function()
	if gate_state == "revealing" then
		return
	end
	if gate_state ~= "settling" then
		gate_session_id = gate_session_id + 1
		local session_id = gate_session_id
		sbar.delay(SETTLE_ABSOLUTE_MAX_SECONDS, function()
			if gate_state ~= "settling" or gate_session_id ~= session_id then
				return
			end
			invalidate_settling_probe_ownership()
			gate_settle_quiet_generation = gate_settle_quiet_generation + 1
			gate_settle_stable_key = nil
			gate_generation = gate_generation + 1
			gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
		end)
	end
	gate_state = "settling"
	gate_generation = gate_generation + 1
	gate_token = enter_animation.hold({ hidden = true, timeout = GATE_HOLD_TIMEOUT_SECONDS })
	gate_settle_pending_request = nil
	gate_settle_stable_key = nil
	gate_settle_quiet_generation = gate_settle_quiet_generation + 1
	local session_id = gate_session_id
	local generation = gate_generation
	local quiet_generation = gate_settle_quiet_generation
	sbar.delay(SETTLE_QUIET_SECONDS, function()
		gate_queue_settling_probe(session_id, generation, quiet_generation)
	end)
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
		local terminal = false
		local function finish_fast_verify(snapshot)
			if terminal
				or gate_state ~= "sleep_hidden"
				or gate_fast_release_generation ~= fast_gen
				or not gate_fast_release_scheduled
			then
				return
			end
			terminal = true
			gate_fast_release_scheduled = false
			if not snapshot
				or snapshot.monitor_valid ~= true
				or snapshot.height_changed
				or snapshot.monitor_changed
			then
				gate_session_from_sleep = false
				gate_had_wake = true
				close_popups()
				trigger_transition_begin()
				gate_enter_settling()
			else
				gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
			end
		end
		sbar.delay(LOCK_FAST_VERIFY_TIMEOUT_SECONDS, function()
			finish_fast_verify(nil)
		end)
		probe(finish_fast_verify)
	end)
end

-- 纯锁屏安静窗口：每次事件都重置 0.3s 计时，连续安静后才释放；
-- 4s 兜底保证事件风暴无限延长时也能强制释放。
local function gate_schedule_quiet_release()
	if not gate_cooldown_active then
		gate_cooldown_active = true
		gate_quiet_max_generation = gate_quiet_max_generation + 1
		local max_gen = gate_quiet_max_generation
		sbar.delay(LOCK_QUIET_MAX_SECONDS, function()
			if gate_quiet_max_generation ~= max_gen or not gate_cooldown_active then
				return
			end
			gate_cooldown_active = false
			gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
		end)
	end

	gate_quiet_generation = gate_quiet_generation + 1
	local quiet_gen = gate_quiet_generation
	sbar.delay(LOCK_QUIET_SECONDS, function()
		if not gate_cooldown_active or gate_quiet_generation ~= quiet_gen then
			return
		end
		if gate_state ~= "sleep_hidden" then
			return
		end
		gate_cooldown_active = false
		gate_reveal({ height_changed = false, monitor_changed = false, monitor_valid = true })
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
	if gate_cooldown_active and gate_state == "sleep_hidden" and not gate_from_system_sleep then
		gate_schedule_quiet_release()
		return
	end
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
		if gate_lock_recheck_active and gate_lock_recheck_active.phase == "probing" then
			-- probe 启动后又收到新 wake/display 证据：保留 owner 防并发，
			-- 但该 probe 的 payload 已不再能授权释放。
			gate_lock_recheck_active.invalidated = true
		end
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
		-- 睡眠路径在首次 wake/display 后才武装锁状态复查（纯锁路径在 on_lock 即武装）。
		gate_schedule_lock_recheck()
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
	gate_lock_session_id = gate_lock_session_id + 1
	invalidate_settling_probe_ownership()
	gate_settle_quiet_generation = gate_settle_quiet_generation + 1
	gate_settle_stable_key = nil
	gate_fast_release_generation = gate_fast_release_generation + 1
	gate_fast_release_scheduled = false
	gate_lock_recheck_active = nil
	gate_lock_unknown_streak = 0
	gate_had_wake = false
	gate_had_display_change = false
	gate_from_system_sleep = from_system_sleep == true
	gate_cooldown_active = false
	gate_quiet_generation = gate_quiet_generation + 1
	gate_quiet_max_generation = gate_quiet_max_generation + 1
	gate_session_from_sleep = gate_from_system_sleep
	gate_post_sleep_verify_until = 0
	gate_aftershock_generation = gate_aftershock_generation + 1
	close_popups()
	trigger_transition_begin()
	gate_token = enter_animation.hold({ hidden = true, no_timeout = true })
	if not gate_from_system_sleep then
		-- 纯锁屏：立即武装锁状态复查，不依赖 wake/display 事件。
		gate_schedule_lock_recheck()
	end
end

gate_on_unlock = function()
	if gate_cooldown_active then
		gate_schedule_quiet_release()
		return
	end
	if gate_state == "sleep_hidden" then
		if gate_had_display_change then
			gate_enter_settling()
		elseif not gate_from_system_sleep then
			gate_schedule_quiet_release()
		elseif gate_had_wake then
			gate_schedule_fast_verify()
		else
			gate_schedule_fast_release()
		end
	end
end

-- ========== 锁状态复查（可恢复兜底）==========
-- 锁定/睡眠期间，single notification 丢失不能导致 bar 永久隐藏，但也不能在
-- 仍锁定时 reveal（旧实现直接 force settling，三条 reveal 路径都会在锁屏上
-- 露出 bar）。这里改为每隔 SLEEP_FAILSAFE_SECONDS 复查屏幕锁状态：
--   - unlocked → 走现有 gate_on_unlock()，不直接 settling；
--   - locked   → 继续隐藏并重新排程；
--   - unknown  → 继续隐藏并重新排程，连续 3 次只限频记一次日志。
-- 未知绝不授权释放：只有 unlock 通知或严格 IOConsoleLocked=No 才能放行。
gate_schedule_lock_recheck = function()
	if gate_lock_recheck_active then
		return
	end
	gate_lock_recheck_request_id = gate_lock_recheck_request_id + 1
	local request = {
		request_id = gate_lock_recheck_request_id,
		generation = gate_generation,
		session_id = gate_lock_session_id,
		phase = "timer",
		invalidated = false,
	}
	gate_lock_recheck_active = request
	sbar.delay(SLEEP_FAILSAFE_SECONDS, function()
		if gate_lock_recheck_active ~= request then
			return
		end
		if gate_state ~= "sleep_hidden"
			or gate_generation ~= request.generation
			or gate_lock_session_id ~= request.session_id
		then
			gate_lock_recheck_active = nil
			return
		end
		request.phase = "probing"
		lock_state.probe(function(state)
			if gate_lock_recheck_active ~= request then
				return
			end
			-- owner 覆盖 timer + async probe 全生命周期；terminal 只清自己的槽。
			gate_lock_recheck_active = nil
			if gate_state ~= "sleep_hidden"
				or gate_generation ~= request.generation
				or gate_lock_session_id ~= request.session_id
			then
				return
			end
			if request.invalidated then
				gate_schedule_lock_recheck()
				return
			end
			if state == "unlocked" then
				gate_lock_unknown_streak = 0
				gate_on_unlock()
			else
				if state == "locked" then
					gate_lock_unknown_streak = 0
				else
					gate_lock_unknown_streak = gate_lock_unknown_streak + 1
					if gate_lock_unknown_streak % 3 == 0 then
						io.stderr:write(
							"display_gate: lock recheck unknown (" .. gate_lock_unknown_streak
							.. "x), bar stays hidden, retrying in " .. SLEEP_FAILSAFE_SECONDS .. "s\n"
						)
					end
				end
				gate_schedule_lock_recheck()
			end
		end)
	end)
end

-- ========== 启动期可见性所有权 ==========
-- helpers.startup 只负责执行渐入；是否允许开始渐入由本门控唯一决策。
local startup_schedule_probe

local function invalidate_startup_probe()
	startup_probe_active = nil
	startup_probe_schedule_generation = startup_probe_schedule_generation + 1
end

local function startup_authorize_reveal()
	if startup_phase ~= "hidden"
		or not startup_reveal_requested
		or startup_reveal_authorized
	then
		return
	end
	startup_reveal_authorized = true
	startup_phase = "revealing"
	startup_reveal_gate_generation = gate_generation
	invalidate_startup_probe()
	local callback = startup_reveal_callback
	startup_reveal_callback = nil
	if callback then
		callback()
	end
end

local function startup_start_probe()
	if startup_phase ~= "hidden"
		or not startup_reveal_requested
		or startup_reveal_authorized
		or startup_probe_active
	then
		return
	end
	startup_probe_request_id = startup_probe_request_id + 1
	local request = {
		request_id = startup_probe_request_id,
		generation = startup_generation,
	}
	startup_probe_active = request
	lock_state.probe(function(state)
		if startup_probe_active ~= request then
			return
		end
		startup_probe_active = nil
		if startup_phase ~= "hidden"
			or not startup_reveal_requested
			or startup_generation ~= request.generation
		then
			return
		end
		if state == "unlocked" then
			startup_unknown_count = 0
			startup_authorize_reveal()
		elseif state == "locked" then
			startup_explicit_evidence = true
			startup_unknown_count = 0
			startup_schedule_probe(STARTUP_LOCK_RECHECK_SECONDS)
		elseif startup_explicit_evidence then
			startup_schedule_probe(STARTUP_LOCK_RECHECK_SECONDS)
		else
			startup_unknown_count = startup_unknown_count + 1
			if startup_unknown_count >= 2 then
				io.stderr:write(
					"sketchybar: startup lock state unknown after retry, revealing (fail-open)\n"
				)
				startup_authorize_reveal()
			else
				startup_schedule_probe(STARTUP_UNKNOWN_RETRY_SECONDS)
			end
		end
	end)
end

startup_schedule_probe = function(delay_seconds)
	if startup_phase ~= "hidden"
		or not startup_reveal_requested
		or startup_reveal_authorized
	then
		return
	end
	startup_probe_schedule_generation = startup_probe_schedule_generation + 1
	local schedule_generation = startup_probe_schedule_generation
	local generation = startup_generation
	if not delay_seconds or delay_seconds <= 0 then
		startup_start_probe()
		return
	end
	sbar.delay(delay_seconds, function()
		if startup_phase ~= "hidden"
			or startup_generation ~= generation
			or startup_probe_schedule_generation ~= schedule_generation
		then
			return
		end
		startup_start_probe()
	end)
end

local function startup_record_explicit_evidence()
	if startup_phase ~= "hidden" then
		return
	end
	startup_explicit_evidence = true
	startup_unlock_evidence = false
	startup_unknown_count = 0
	invalidate_startup_probe()
	if startup_reveal_requested then
		startup_schedule_probe(STARTUP_LOCK_RECHECK_SECONDS)
	end
end

function M.configure(options)
	handlers = options or {}
end

function M.begin_startup()
	startup_phase = "hidden"
	startup_generation = startup_generation + 1
	startup_explicit_evidence = false
	startup_unlock_evidence = false
	startup_reveal_requested = false
	startup_reveal_authorized = false
	startup_reveal_callback = nil
	startup_reveal_gate_generation = nil
	startup_unknown_count = 0
	startup_pending_display_event = nil
	invalidate_startup_probe()
end

function M.request_startup_reveal(callback)
	if startup_phase == "runtime" then
		callback()
		return
	end
	if startup_phase ~= "hidden" or startup_reveal_requested then
		return
	end
	startup_reveal_requested = true
	startup_reveal_callback = callback
	if startup_unlock_evidence then
		startup_authorize_reveal()
	else
		startup_schedule_probe(0)
	end
end

function M.finish_startup_reveal()
	if startup_phase ~= "revealing" then
		return
	end
	local pending_display_event = startup_pending_display_event
	local reveal_generation = startup_reveal_gate_generation
	startup_pending_display_event = nil
	startup_phase = "runtime"
	invalidate_startup_probe()
	-- 交接只结束 startup owner，绝不重置 runtime FSM/token。若 fade 期间
	-- 已进入新的锁/睡会话，该会话保持 sleep_hidden，也不重放旧 display 事件。
	if pending_display_event
		and gate_generation == reveal_generation
		and gate_state == "idle"
	then
		gate_on_display_event(pending_display_event)
	end
end

function M.on_display_event(source_event)
	if startup_phase == "hidden" then
		startup_pending_display_event = source_event
		if source_event == "system_woke" then
			startup_record_explicit_evidence()
		end
		return
	end
	gate_on_display_event(source_event)
end

function M.on_will_sleep()
	if startup_phase == "hidden" then
		startup_record_explicit_evidence()
		return
	end
	gate_on_will_sleep(true)
end

function M.on_lock()
	if startup_phase == "hidden" then
		startup_record_explicit_evidence()
		return
	end
	gate_on_will_sleep(false)
end

function M.on_unlock()
	if startup_phase == "hidden" then
		if startup_explicit_evidence then
			startup_unlock_evidence = true
			startup_authorize_reveal()
		end
		return
	end
	gate_on_unlock()
end

return M
