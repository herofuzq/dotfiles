local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

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

-- 键锚定：其它含 "No"/"Yes" 的键不得误判
assert(lock_state.parse([[      "IOConsoleUsers" = No
]], 0) == nil)

-- ===== detect_sync：消费 close status =====
assert(lock_state.detect_sync("/usr/bin/printf '      \"IOConsoleLocked\" = Yes\\n'") == "locked")
assert(lock_state.detect_sync("/usr/bin/printf '      \"IOConsoleLocked\" = No\\n'") == "unlocked")
assert(lock_state.detect_sync("/usr/bin/false") == nil)

print("lock_state_test: ok")
