local path = "sketchybar/.config/sketchybar/items/services.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

assert(source:find("visible_rows", 1, true), "services render_popup must track visible rows")
assert(source:find("entry.item:set({ drawing = false })", 1, true), "services render_popup must hide missing rows")

print("services_popup_cleanup_test: ok")
