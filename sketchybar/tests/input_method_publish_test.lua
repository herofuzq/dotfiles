local path = "sketchybar/.config/sketchybar/helpers/event_providers/input_method/input_method_watch.swift"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

local run_pos = assert(source:find("guard (try? task.run()) != nil else { return }", 1, true))
local signature_pos = assert(source:find("lastSignature = signature", 1, true))
assert(signature_pos > run_pos, "lastSignature must be updated only after task.run succeeds")

print("input_method_publish_test: ok")
