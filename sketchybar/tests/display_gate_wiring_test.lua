local path = "sketchybar/.config/sketchybar/items/spaces.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function gate_verify_awake_event", 1, true), "awake events must have a verify-first path")
assert(source:find("display_policy.classify", 1, true), "gate events must be classified by display_policy")
assert(source:find('action == "verify"', 1, true), "idle events must route to verify")

print("display_gate_wiring_test: ok")
