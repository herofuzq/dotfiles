local function read_source(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local function count_plain(source, needle)
	local n, pos = 0, 1
	while true do
		local found = source:find(needle, pos, true)
		if not found then
			return n
		end
		n = n + 1
		pos = found + #needle
	end
end

local spaces = read_source("sketchybar/.config/sketchybar/items/spaces.lua")
assert(
	count_plain(spaces, "aerospace list-workspaces --focused") == 2,
	"startup must not issue a third focused-workspace query"
)
assert(not spaces:find("-- 初始 focus", 1, true), "startup must reuse withWindows for the first focus")

local probe_start = assert(spaces:find("local function probeDisplayState", 1, true))
local probe_end = assert(spaces:find("local function applySnapshot", probe_start, true))
local probe = spaces:sub(probe_start, probe_end)
assert(probe:find("maybe_done", 1, true), "display probe must join height and monitor results")
assert(probe:find("settings.refresh_bar_height", 1, true), "display probe must still measure bar height")
assert(probe:find("queryMonitorSnapshot", 1, true), "display probe must still query AeroSpace monitors")

local fs_start = assert(spaces:find('root:subscribe("aerospace_fullscreen_change"', 1, true))
local fs_end = assert(spaces:find("local function set_mode_visibility", fs_start, true))
assert(
	spaces:sub(fs_start, fs_end):find("scheduleUpdateWindows(0)", 1, true),
	"fullscreen refresh must share the window-update coalescer"
)

local watch = read_source(
	"sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift"
)
local created = assert(watch:find('case "window-detected":', 1, true))
local binding = assert(watch:find('case "binding-triggered":', created, true))
assert(
	not watch:sub(created, binding):find("scheduleFullscreenStateCheck", 1, true),
	"window-detected must not run a second list-windows for fullscreen"
)
assert(watch:find("scheduleFullscreenStateCheck()", 1, true), "focus/binding/workspace still check fullscreen")

print("spaces_query_coalesce_test: ok")
