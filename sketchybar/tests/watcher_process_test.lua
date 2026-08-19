local watchers = {
	"sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/docker_watch/docker_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/input_method/input_method_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/media_watch/media_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/sys_watch/sys_watch.swift",
}

local function read_source(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

for _, path in ipairs(watchers) do
	local source = read_source(path)
	assert(source:find("sketchybarSend(", 1, true), path .. " must deliver SketchyBar messages over Mach")
	assert(not source:find("launchPath = sketchybar", 1, true), path .. " must not spawn the sketchybar CLI")
	assert(not source:find("fileURLWithPath: sketchybar", 1, true), path .. " must not spawn the sketchybar CLI")
end

local subprocess_watchers = {
	"sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/docker_watch/docker_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/media_watch/media_watch.swift",
}
for _, path in ipairs(subprocess_watchers) do
	local source = read_source(path)
	assert(source:find("func waitForProcess", 1, true), path .. " must provide bounded Process waiting")
	assert(source:find("commandTimeout", 1, true), path .. " must define a command timeout")
	assert(
		source:find("waitForProcess(task, timeout: commandTimeout)", 1, true)
			or source:find("waitForProcess(p, timeout: commandTimeout)", 1, true),
		path .. " must use the timeout for external commands"
	)
end

local mach_c = read_source("sketchybar/.config/sketchybar/helpers/event_providers/sketchybar_mach.c")
assert(mach_c:find('#include "sketchybar.h"', 1, true), "Mach client must use the official sketchybar.h")
assert(mach_c:find("void sketchybar_send_args", 1, true), "Mach client must export argv send")
assert(mach_c:find("mach_send_message", 1, true), "Mach client must send on the bootstrap port")

print("watcher_process_test: ok")
