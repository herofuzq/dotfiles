local path = "sketchybar/.config/sketchybar/helpers/menus/menus.c"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

assert(source:find("pos_error != kAXErrorSuccess", 1, true), "menus.c must check AX position copy errors")
assert(source:find("size_error != kAXErrorSuccess", 1, true), "menus.c must check AX size copy errors")
assert(source:find("!AXValueGetValue(position_ref", 1, true), "menus.c must check AXValueGetValue results")

print("menus_ax_check_test: ok")
