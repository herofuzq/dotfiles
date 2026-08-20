local path = "sketchybar/.config/sketchybar/helpers/event_providers/input_method/input_method_watch.swift"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

local send_pos = assert(source:find("guard sketchybarSend([", 1, true))
local signature_pos = assert(source:find("lastSignature = signature", 1, true))
assert(signature_pos > send_pos, "lastSignature must be updated only after a successful Mach send")
assert(source:find("else { return }", send_pos, true), "failed Mach send must not record lastSignature")

print("input_method_publish_test: ok")
