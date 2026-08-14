local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

-- async lock_state boundary：测试显式决定 callback/timeout 到达顺序。
local lock_callbacks = {}
local lock_probe_count = 0
package.preload["helpers.lock_state"] = function()
	return {
		probe = function(callback)
			lock_probe_count = lock_probe_count + 1
			lock_callbacks[#lock_callbacks + 1] = callback
		end,
	}
end

local calls = {
	hold = {},
	release = {},
	delay = {},
	trigger = {},
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
		if on_complete then
			on_complete()
		end
	end,
	close_popups = function() end,
})

local function fresh_gate()
	calls = { hold = {}, release = {}, delay = {}, trigger = {}, probe = {} }
	lock_callbacks = {}
	lock_probe_count = 0
	package.loaded["helpers.display_gate"] = nil
	local fresh = require("helpers.display_gate")
	fresh.configure({
		probe = function(on_done)
			calls.probe[#calls.probe + 1] = on_done
		end,
		apply = function(snapshot, on_complete)
			if on_complete then
				on_complete()
			end
		end,
		close_popups = function() end,
	})
	return fresh
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

local function fire_last_75()
	local d = delays_with(75)
	assert(#d > 0, "expected an armed 75s recheck")
	return d[#d].callback
end

-- ===== 纯锁在 on_lock 立即武装复查，不依赖 wake/display =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	assert(#delays_with(75) == 1, "pure lock must arm the lock recheck immediately")
end

-- ===== 睡眠路径在 lock 时不武装，首次 wake/display 后才武装 =====
do
	local fresh = fresh_gate()
	fresh.on_will_sleep()
	assert(#delays_with(75) == 0, "system sleep must NOT arm recheck at sleep time")
	fresh.on_display_event("system_woke")
	assert(#delays_with(75) == 1, "first wake after sleep must arm the recheck")
	-- 后续重复 wake/display 不再重复武装
	fresh.on_display_event("display_change")
	assert(#delays_with(75) == 1, "recheck must be armed exactly once per session")
end

-- ===== 复查 found locked → 不 release，重新排程 =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	assert(#calls.release == 0)
	fire_last_75()()
	assert(lock_probe_count == 1 and #lock_callbacks == 1,
		"matching timer must start one async lock probe")
	lock_callbacks[1]("locked")
	assert(#calls.release == 0, "locked recheck must not reveal")
	assert(lock_probe_count == 1, "locked recheck must probe once")
	assert(#delays_with(75) == 2, "locked recheck must re-arm")
end

-- ===== 复查 found unlocked → 走 gate_on_unlock（纯锁 quiet release）==========
do
	local fresh = fresh_gate()
	fresh.on_lock()
	fire_last_75()()
	lock_callbacks[1]("unlocked")
	-- gate_on_unlock 对纯锁走 quiet release：0.3s 安静窗口后 release，而不是直接 settle。
	assert(#calls.release == 0, "unlock via recheck must not release immediately (quiet window)")
	local quiet = assert(delays_with(0.3)[#delays_with(0.3)], "quiet release must be scheduled")
	quiet.callback()
	assert(#calls.release == 1, "quiet release after recheck-unlock must reveal once")
	assert(#delays_with(10) == 0, "unlock via recheck must not enter settling")
end

-- ===== 复查 unknown → 不 release，重新排程且不崩 =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	fire_last_75()()
	lock_callbacks[1](nil, "timeout")
	assert(#calls.release == 0, "unknown recheck must not reveal")
	assert(#delays_with(75) == 2, "unknown recheck must re-arm")
end

-- ===== 连续 unknown 反复重新排程，永不授权释放 =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	for index = 1, 3 do
		fire_last_75()()
		lock_callbacks[index](nil, "invalid")
	end
	assert(#calls.release == 0, "repeated unknown must never reveal")
	assert(#delays_with(75) == 4, "each unknown recheck must re-arm")
end

-- ===== stale recheck 不作用于已离开 sleep_hidden 的会话 =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	local stale = fire_last_75()
	-- 正常 unlock（screen_unlocked 通知路径）先到，quiet release 完成 → idle
	fresh.on_unlock()
	assert(delays_with(0.3)[#delays_with(0.3)], "normal unlock must schedule quiet release").callback()
	assert(#calls.release == 1, "normal unlock must reveal")
	local releases_after_unlock = #calls.release
	stale()
	assert(#calls.release == releases_after_unlock, "stale recheck must not act after session ended")
	assert(lock_probe_count == 0, "stale timer must not start a probe after session ended")
end

-- ===== 旧会话 timer 不得清理新会话的 active owner =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	local old_timer = fire_last_75()
	fresh.on_unlock()
	assert(delays_with(0.3)[#delays_with(0.3)]).callback()
	fresh.on_lock()
	local new_timer = fire_last_75()
	assert(#delays_with(75) == 2, "each lock session must own one recheck timer")

	old_timer()
	assert(lock_probe_count == 0, "old timer must not consume the new owner's slot")
	fresh.on_display_event("display_change")
	assert(#delays_with(75) == 2,
		"an event after the old timer must still observe the new active owner")
	new_timer()
	assert(lock_probe_count == 1 and #lock_callbacks == 1,
		"new session timer must remain active after the old timer fires")
	lock_callbacks[1]("locked")
	assert(#delays_with(75) == 3, "current callback must be able to re-arm its session")
end

-- ===== 旧会话 async callback 迟到时不得释放或破坏新 owner =====
do
	local fresh = fresh_gate()
	fresh.on_lock()
	local old_timer = fire_last_75()
	old_timer()
	local stale_callback = assert(lock_callbacks[1])

	fresh.on_unlock()
	assert(delays_with(0.3)[#delays_with(0.3)]).callback()
	fresh.on_lock()
	local new_timer = fire_last_75()
	stale_callback("unlocked")
	assert(#calls.release == 1, "stale async unlocked result must not release the new session")

	new_timer()
	assert(lock_probe_count == 2, "stale callback must not suppress the new session probe")
	lock_callbacks[2]("locked")
	assert(#delays_with(75) == 3, "new session callback must retain re-arm ownership")
end

-- ===== timer 发火后 owner 必须覆盖整个 async probe 生命周期 =====
-- probe 在途时新到的同会话 display/wake 证据使旧 payload 过期；
-- 迟到 unlocked 不得进入 quiet/settling/reveal，只能重新武装复查。
for _, source_event in ipairs({ "display_change", "system_woke" }) do
	local fresh = fresh_gate()
	fresh.on_lock()
	local timer = fire_last_75()
	timer()
	local in_flight = assert(lock_callbacks[1], "75s timer must start one async probe")
	assert(#delays_with(75) == 1, "in-flight probe must retain the timer owner")

	fresh.on_display_event(source_event)
	assert(#delays_with(75) == 1,
		"same-session " .. source_event .. " must not arm a second timer while probe is active")
	in_flight("unlocked")
	assert(#calls.hold == 1, "stale unlocked must not enter settling")
	assert(#calls.release == 0, "stale unlocked must not reveal")
	assert(#delays_with(10) == 0, "stale unlocked must not arm a settling watchdog")
	assert(#delays_with(0.3) == 0, "stale unlocked must not schedule a quiet release")
	assert(#delays_with(75) == 2, "stale probe completion must re-arm one owned recheck")
end

-- ===== gate_session_from_sleep 仅跟随 from_system_sleep（静态守卫）=====
do
	local f = assert(io.open("sketchybar/.config/sketchybar/helpers/display_gate.lua", "r"))
	local src = f:read("*a")
	f:close()
	assert(src:find("gate_session_from_sleep%s*=%s*gate_from_system_sleep", 1, false),
		"gate_session_from_sleep 必须由 from_system_sleep 派生，而非无条件 true")
	assert(not src:find("gate_session_from_sleep%s*=%s*true", 1, false),
		"gate_session_from_sleep 不得再无条件置 true")
end

print("display_gate_lock_recheck_test: ok")
