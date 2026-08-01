local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local watchers = {
	"sketchybar/.config/sketchybar/helpers/event_providers/media_watch/media_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/aerospace_watch/aerospace_watch.swift",
	"sketchybar/.config/sketchybar/helpers/event_providers/sys_watch/sys_watch.swift",
}

for _, path in ipairs(watchers) do
	local source = read(path)
	assert(source:find("dataBuffer.append(data)", 1, true), path .. " must buffer raw Data before decoding")
	assert(source:find("firstIndex(of: 0x0A)", 1, true), path .. " must split lines on newline bytes")
end

local media = read("sketchybar/.config/sketchybar/helpers/event_providers/media_watch/media_watch.swift")
assert(
	not media:find("guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {", 1, true),
	"media_watch must not exit on an invalid UTF-8 chunk"
)

print("swift_stream_decoding_test: ok")
