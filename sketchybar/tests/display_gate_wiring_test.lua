local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local spaces = read("sketchybar/.config/sketchybar/items/spaces.lua")

local function subscription_body(source, event_name, next_event_name)
	local marker = 'pi:subscribe("' .. event_name .. '", function()'
	local next_marker = 'pi:subscribe("' .. next_event_name .. '", function()'
	local start_at = assert(source:find(marker, 1, true), event_name .. " subscription must exist")
	local end_at = assert(source:find(next_marker, start_at + #marker, true), next_event_name .. " subscription must follow " .. event_name)
	return source:sub(start_at, end_at - 1)
end

local function assert_hover_deferred(body, event_name)
	local callback_body = body:match("popup_utils%.defer%(%s*function%s*%(%s*%)(.-)%s*end%s*%)")
	assert(callback_body, event_name .. " must defer its UI mutation (#794)")
	assert(callback_body:find("pi:set(", 1, true), event_name .. " must run pi:set inside the deferred callback")
end

assert(spaces:find("helpers.display_gate", 1, true), "spaces must delegate to display_gate")
assert(spaces:find("display_gate.on_display_event", 1, true), "display/wake events must route into display_gate")
assert(spaces:find("display_gate.on_will_sleep", 1, true), "sleep/lock events must route into display_gate")
assert(spaces:find("display_gate.on_unlock", 1, true), "unlock must route into display_gate")
assert(spaces:find("display_gate.on_lock", 1, true), "pure screen lock must route into display_gate.on_lock")
assert(spaces:find('"com.apple.screenIsLocked"', 1, true), "pure screen lock must be subscribed")
assert(spaces:find('root:subscribe("screen_locked"', 1, true), "screen lock must route into the gate")
assert_hover_deferred(subscription_body(spaces, "mouse.entered", "mouse.exited"), "mouse.entered")
assert_hover_deferred(subscription_body(spaces, "mouse.exited", "mouse.clicked"), "mouse.exited")

local gate = read("sketchybar/.config/sketchybar/helpers/display_gate.lua")
assert(gate:find("gate_verify_awake_event = function", 1, true), "awake events must have a verify-first path")
assert(gate:find("display_policy.classify", 1, true), "gate events must be classified by display_policy")
assert(gate:find('action == "verify"', 1, true), "idle events must route to verify")
assert(gate:find("gate_schedule_fast_release", 1, true), "pure lock must use a fast release path")

print("display_gate_wiring_test: ok")
