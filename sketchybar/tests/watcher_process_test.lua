local watchers = {
	"sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/docker_watch/docker_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/input_method/input_method_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/media_watch/media_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/sys_watch/sys_watch.swift",
}

for _, path in ipairs(watchers) do
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	assert(source:find("func waitForProcess", 1, true), path .. " must provide bounded Process waiting")
	assert(source:find("commandTimeout", 1, true), path .. " must define a command timeout")
	assert(
		source:find("waitForProcess(task, timeout: commandTimeout)", 1, true),
		path .. " must use the timeout for SketchyBar commands"
	)
end

print("watcher_process_test: ok")
