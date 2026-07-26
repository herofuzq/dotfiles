local function read(path)
	local file = assert(io.open(path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local cpu_header = read("sketchybar/.config/sketchybar/helpers/event_providers/cpu_load/cpu.h")
assert(cpu_header:find("cpu->user_load = 0;", 1, true), "cpu_init must initialize user_load")
assert(cpu_header:find("cpu->sys_load = 0;", 1, true), "cpu_init must initialize sys_load")
assert(cpu_header:find("cpu->total_load = 0;", 1, true), "cpu_init must initialize total_load")

local sys_source = read("sketchybar/.config/sketchybar/items/widgets/sys.lua")
local subscribe_pos = assert(sys_source:find('sys:subscribe("cpu_update"', 1, true))
local deferred_start_pos = assert(
	sys_source:find("sbar.delay(0, restart_cpu_provider)", 1, true),
	"CPU provider must start from the event loop"
)
assert(
	deferred_start_pos > subscribe_pos,
	"CPU provider must start only after the cpu_update subscription is registered"
)

local provider_source = read("sketchybar/.config/sketchybar/helpers/event_providers/cpu_load/cpu_load.c")
local loop_pos = assert(provider_source:find("for (;;) {", 1, true))
local warmup_pos = assert(provider_source:find("cpu_update(&cpu);", 1, true))
assert(warmup_pos < loop_pos, "CPU provider must warm up before publishing its first sample")

print("cpu_provider_test: ok")
