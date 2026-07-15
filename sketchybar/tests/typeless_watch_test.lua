local source_path = "sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift"
local file = assert(io.open(source_path, "r"))
local source = file:read("*a")
file:close()

assert(
	source:find('"%{window-id}|%{workspace}|%{window-title}"', 1, true),
	"Typeless query must include the window title"
)
assert(source:find('fields[2] == "Status"', 1, true), "only the Typeless Status window may follow focus")

print("typeless_watch_test: ok")
