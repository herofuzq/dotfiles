package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

local timing = require("helpers.timing")

assert(timing.FRAMES_PER_SECOND == 60)
assert(timing.STANDARD_DURATION_FRAMES == 6)
assert(timing.ENTER_BAR_FADE_FRAMES == 30)
assert(timing.ENTER_ITEM_FADE_FRAMES == 30)
assert(timing.STARTUP_READY_TIMEOUT_SECONDS == 1.0)
-- 与 spaces.lua 的 REFRESH_TIMEOUT（3.0）耦合：hold 超时必须大于单轮窗口刷新看门狗，
-- 否则会在合法慢查询未结束时提前渐入。这里只能断言下界，无法跨文件读常量。
assert(timing.HOLD_TIMEOUT_SECONDS > 3.0)
assert(math.abs(timing.frames_to_seconds(timing.STANDARD_DURATION_FRAMES) - 0.1) < 0.000001)
assert(math.abs(timing.frames_to_seconds(timing.ENTER_BAR_FADE_FRAMES) - 0.5) < 0.000001)

print("timing_test: ok")
