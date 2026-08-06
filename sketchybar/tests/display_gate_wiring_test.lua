local path = "sketchybar/.config/sketchybar/items/spaces.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function gate_verify_awake_event", 1, true), "awake events must have a verify-first path")
assert(source:find("display_policy.classify", 1, true), "gate events must be classified by display_policy")
assert(source:find('action == "verify"', 1, true), "idle events must route to verify")
assert(source:find('"com.apple.screenIsLocked"', 1, true), "pure screen lock must be subscribed")
assert(source:find('root:subscribe("screen_locked"', 1, true), "screen lock must route into the gate")
assert(source:find("gate_schedule_fast_release", 1, true), "pure lock must use a fast release path")

print("display_gate_wiring_test: ok")
