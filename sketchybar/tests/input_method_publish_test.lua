local path = "sketchybar/.config/sketchybar/helpers/event_providers/input_method/input_method_watch.swift"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

local send_pos = assert(source:find("sketchybarSend([", 1, true))
local signature_pos = assert(source:find("lastSignature = signature", 1, true))
assert(signature_pos > send_pos, "lastSignature must be updated only after the Mach send")
assert(not source:find("guard (try? task.run()) != nil else { return }", 1, true),
	"input method must not spawn sketchybar to publish")

print("input_method_publish_test: ok")
