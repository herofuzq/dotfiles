local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local window_filter = require("helpers.window_filter")

assert(not window_filter.should_show("Typeless", "Status"), "Typeless Status should stay hidden")
assert(window_filter.should_show("Typeless", "Settings"), "normal Typeless windows should stay visible")
assert(window_filter.should_show("Other App", "Status"), "other apps named Status should stay visible")

print("window_filter_test: ok")
