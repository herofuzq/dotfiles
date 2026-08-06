local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local spaces = read("sketchybar/.config/sketchybar/items/spaces.lua")
assert(spaces:find("helpers.display_gate", 1, true), "spaces must delegate to display_gate")
assert(spaces:find("display_gate.on_display_event", 1, true), "display/wake events must route into display_gate")
assert(spaces:find("display_gate.on_will_sleep", 1, true), "sleep/lock events must route into display_gate")
assert(spaces:find("display_gate.on_unlock", 1, true), "unlock must route into display_gate")
assert(spaces:find('"com.apple.screenIsLocked"', 1, true), "pure screen lock must be subscribed")
assert(spaces:find('root:subscribe("screen_locked"', 1, true), "screen lock must route into the gate")

local gate = read("sketchybar/.config/sketchybar/helpers/display_gate.lua")
assert(gate:find("gate_verify_awake_event = function", 1, true), "awake events must have a verify-first path")
assert(gate:find("display_policy.classify", 1, true), "gate events must be classified by display_policy")
assert(gate:find('action == "verify"', 1, true), "idle events must route to verify")
assert(gate:find("gate_schedule_fast_release", 1, true), "pure lock must use a fast release path")

print("display_gate_wiring_test: ok")
