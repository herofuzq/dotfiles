local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local delayed = {}
local bar_updates = {}
package.preload["sketchybar"] = function()
	return {
		bar = function(props) bar_updates[#bar_updates + 1] = props end,
		begin_config = function() end,
		end_config = function() end,
		animate = function(_, _, callback) callback() end,
		delay = function(seconds, callback)
			delayed[#delayed + 1] = { seconds = seconds, callback = callback }
		end,
	}
end
package.preload["appearance"] = function()
	return {
		colors = { bar_bg = 0xff111111, border = 0xff222222 },
		with_alpha = function(color, alpha)
			return (color & 0x00ffffff) | (math.floor(alpha * 255) * 0x1000000)
		end,
	}
end
package.preload["settings"] = function()
	return {
		height = 30,
		refresh_bar_height = function(callback) callback(31) end,
	}
end

local startup = require("helpers.startup")
local applied = {}
local initial_ready = startup.track("slow.status")
startup.after_reveal("status", function() applied[#applied + 1] = "old" end)
startup.after_reveal("status", function() applied[#applied + 1] = "latest" end)
local timed_out
startup.when_ready(function(timeout)
	timed_out = timeout
	startup.reveal()
end)

assert(#applied == 0 and timed_out == nil, "readiness barrier must keep the bar hidden")
local timeout_callback
for _, entry in ipairs(delayed) do
	if entry.seconds == 1.0 then timeout_callback = entry.callback end
end
assert(type(timeout_callback) == "function", "barrier must install a one-second fallback")
timeout_callback()
assert(timed_out == true, "fallback must report a readiness timeout")
assert(#applied == 1 and applied[1] == "latest", "latest state must be primed before reveal")

local finish_callback
for _, entry in ipairs(delayed) do
	if entry.seconds == 0.5 then finish_callback = entry.callback end
end
assert(type(finish_callback) == "function", "reveal must schedule completion")
finish_callback()
assert(#applied == 2 and applied[2] == "latest", "latest keyed update should finish the fade")
assert(bar_updates[#bar_updates].height == 31, "bar-height correction should run after reveal")

initial_ready() -- late completion after timeout must be harmless

startup.after_reveal("immediate", function() applied[#applied + 1] = "immediate" end)
assert(applied[#applied] == "immediate", "updates after reveal should run immediately")

print("startup_test: ok")
