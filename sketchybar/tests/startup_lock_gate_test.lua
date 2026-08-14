local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

-- "_UNKNOWN_" 哨兵：真实 lock_state 对未知返回 nil；序列里不能放内部 nil。
local UNKNOWN = "_UNKNOWN_"
local lock_results = {}
local lock_probe_count = 0
package.preload["helpers.lock_state"] = function()
	return {
		detect_sync = function()
			lock_probe_count = lock_probe_count + 1
			local value = table.remove(lock_results, 1)
			if value == UNKNOWN then
				return nil
			end
			return value
		end,
	}
end

local delayed = {}
package.preload["sketchybar"] = function()
	return {
		bar = function() end,
		delay = function(seconds, callback)
			delayed[#delayed + 1] = { seconds = seconds, callback = callback }
		end,
	}
end

local startup = require("helpers.startup")

local function push(...)
	for _, value in ipairs({ ... }) do
		lock_results[#lock_results + 1] = value
	end
end

local function reset()
	delayed = {}
	lock_results = {}
	lock_probe_count = 0
end

local function delays_with(seconds)
	local found = {}
	for _, entry in ipairs(delayed) do
		if entry.seconds == seconds then
			found[#found + 1] = entry
		end
	end
	return found
end

-- ===== unlocked → 立即回调，零探测延迟 =====
do
	reset()
	push("unlocked")
	local released = false
	startup.reveal_on_unlock(function() released = true end)
	assert(released, "unlocked must reveal immediately")
	assert(#delayed == 0, "unlocked must not schedule any recheck")
end

-- ===== locked → fail-closed，轮询到显式 No 才回调 =====
do
	reset()
	push("locked", UNKNOWN, "locked", "unlocked")
	local released = false
	startup.reveal_on_unlock(function() released = true end)
	assert(not released, "locked must defer reveal")
	assert(lock_probe_count == 1, "first probe must be consumed at gate time")

	assert(#delays_with(1.0) == 1, "locked must arm a 1s poll")
	delays_with(1.0)[1].callback() -- unknown
	assert(not released, "locked→unknown must keep deferring")
	assert(#delays_with(1.0) == 2, "unknown during fail-closed must re-arm")

	delays_with(1.0)[2].callback() -- locked
	assert(not released, "locked→locked must keep deferring")

	delays_with(1.0)[3].callback() -- unlocked
	assert(released, "explicit unlocked must release the deferred reveal")
end

-- ===== unknown → 0.5s 重试一次；仍 unknown → fail-open =====
do
	reset()
	push(UNKNOWN, UNKNOWN)
	local released = false
	startup.reveal_on_unlock(function() released = true end)
	assert(not released, "first unknown must not reveal")
	assert(#delays_with(0.5) == 1, "first unknown must arm a 0.5s retry")
	delays_with(0.5)[1].callback()
	assert(released, "second consecutive unknown must fail-open")
end

-- ===== unknown → 重试发现 locked → 转入 fail-closed =====
do
	reset()
	push(UNKNOWN, "locked", "unlocked")
	local released = false
	startup.reveal_on_unlock(function() released = true end)
	delays_with(0.5)[1].callback()
	assert(not released, "unknown→locked must NOT fail-open")
	assert(#delays_with(1.0) == 1, "unknown→locked must transition to fail-closed polling")
	delays_with(1.0)[1].callback()
	assert(released, "fail-closed poll must release on explicit unlocked")
end

-- ===== unknown → 重试发现 unlocked → 正常 reveal =====
do
	reset()
	push(UNKNOWN, "unlocked")
	local released = false
	startup.reveal_on_unlock(function() released = true end)
	delays_with(0.5)[1].callback()
	assert(released, "unknown→unlocked must reveal")
end

print("startup_lock_gate_test: ok")
