local source_path = "sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift"
local file = assert(io.open(source_path, "r"))
local source = file:read("*a")
file:close()

assert(not source:find("now.typeless.desktop", 1, true), "unused Typeless must not be queried on workspace change")
assert(not source:find("moveTypelessToWorkspace", 1, true), "Typeless must not follow the focused workspace")
assert(
	not source:find('fields[2] == "Status"', 1, true),
	"Typeless Status window must not be moved with focus"
)

print("typeless_watch_test: ok")
