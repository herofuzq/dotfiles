local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local exec_calls = {}
local delays = {}
package.preload["sketchybar"] = function()
	return {
		exec = function(command, callback)
			exec_calls[#exec_calls + 1] = { command = command, callback = callback }
		end,
		delay = function(seconds, callback)
			delays[#delays + 1] = { seconds = seconds, callback = callback }
		end,
	}
end

local lock_state = require("helpers.lock_state")

-- ===== parse：严格三态 =====
assert(lock_state.parse([[      "IOConsoleLocked" = Yes
]], 0) == "locked")
assert(lock_state.parse([[      "IOConsoleLocked" = No
]], 0) == "unlocked")

-- 非零退出 = unknown（部分 stdout 也不可信）
assert(lock_state.parse([[      "IOConsoleLocked" = No
]], 1) == nil)
assert(lock_state.parse([[      "IOConsoleLocked" = No
]], 143) == nil)

-- 输出缺失 / 类型错误 = unknown
assert(lock_state.parse(nil, 0) == nil)
assert(lock_state.parse("", 0) == nil)
assert(lock_state.parse(nil, nil) == nil)

-- 属性缺失 / 其它属性不干扰 = unknown / 正确判定
assert(lock_state.parse([[      "IOClass" = "AppleS5L8960X"
]], 0) == nil)
assert(lock_state.parse(
	[[      "IOClass" = "AppleS5L8960X"
      "IOConsoleLocked" = No
      "Whatever" = Yes
]], 0) == "unlocked")

-- 冲突（同现 Yes 与 No）= unknown
assert(lock_state.parse(
	[[      "IOConsoleLocked" = Yes
      "IOConsoleLocked" = No
	]], 0) == nil)

-- 同值重复也不是「唯一一条完整证据」。
assert(lock_state.parse(
	[[      "IOConsoleLocked" = Yes
      "IOConsoleLocked" = Yes
	]], 0) == nil)

-- 属性行必须完整；部分 token 不得命中。
assert(lock_state.parse([[      "IOConsoleLocked" = Y
]], 0) == nil)
assert(lock_state.parse([[      "IOConsoleLocked" = Yes trailing
]], 0) == nil)

-- 键锚定：其它含 "No"/"Yes" 的键不得误判
assert(lock_state.parse([[      "IOConsoleUsers" = No
]], 0) == nil)

local function reset_probe()
	exec_calls = {}
	delays = {}
end

local function start_probe()
	local observed = {}
	lock_state.probe(function(state, reason)
		observed[#observed + 1] = { state = state, reason = reason }
	end)
	assert(#exec_calls == 1, "each probe must launch exactly one ioreg request")
	assert(exec_calls[1].command == lock_state.build_probe_command())
	assert(#delays == 1 and delays[1].seconds == 2.0, "each probe must arm one exact 2s timeout")
	return observed, exec_calls[1].callback, delays[1].callback
end

-- ===== probe：exec callback 先完成，timeout 随后必须 no-op =====
do
	reset_probe()
	local observed, callback, timeout = start_probe()
	callback([[      "IOConsoleLocked" = No
]], 0)
	assert(#observed == 1 and observed[1].state == "unlocked" and observed[1].reason == nil)
	timeout()
	assert(#observed == 1, "callback-first must make the timeout a no-op")
end

-- ===== probe：timeout 先完成，迟到 exec callback 不得二次通知 =====
do
	reset_probe()
	local observed, callback, timeout = start_probe()
	timeout()
	assert(#observed == 1 and observed[1].state == nil and observed[1].reason == "timeout")
	callback([[      "IOConsoleLocked" = Yes
]], 0)
	assert(#observed == 1, "timeout-first must make the late callback a no-op")
end

-- ===== probe：严格 locked 与失败边界 =====
do
	reset_probe()
	local observed, callback = start_probe()
	callback([[      "IOConsoleLocked" = Yes
]], 0)
	assert(#observed == 1 and observed[1].state == "locked" and observed[1].reason == nil)
end

do
	reset_probe()
	local observed, callback = start_probe()
	callback([[      "IOConsoleLocked" = Yes
]], 7)
	assert(#observed == 1 and observed[1].state == nil and observed[1].reason == "invalid")
end

for _, malformed in ipairs({
	[[      "IOConsoleLocked" = Yes
      "IOConsoleLocked" = Yes
]],
	[[      "IOConsoleLocked" = Yes
      "IOConsoleLocked" = No
]],
	[[      "IOConsoleLocked" = Y
]],
	[[      "IOClass" = "AppleS5L8960X"
]],
}) do
	reset_probe()
	local observed, callback = start_probe()
	callback(malformed, 0)
	assert(#observed == 1 and observed[1].state == nil and observed[1].reason == "invalid")
end

print("lock_state_test: ok")
