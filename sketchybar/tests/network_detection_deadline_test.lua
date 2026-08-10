local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local active
local module_names = {
	"sketchybar",
	"icons",
	"appearance",
	"helpers.widget_parsers",
	"helpers.find_binary",
	"helpers.utils",
	"helpers.startup",
}

package.preload["sketchybar"] = function() return active.sbar end
package.preload["icons"] = function()
	return { network = { offline = "offline", wifi = "wifi", ethernet = "ethernet" } }
end
package.preload["appearance"] = function() return active.appearance end
package.preload["helpers.widget_parsers"] = function()
	return {
		network_kind = function(port)
			return port == "Wi-Fi" and "wifi" or "ethernet"
		end,
	}
end
package.preload["helpers.find_binary"] = function()
	return { find = function() return "/test/ifstat" end }
end
package.preload["helpers.utils"] = function()
	return { shell_quote = function(value) return tostring(value) end }
end
package.preload["helpers.startup"] = function() return active.startup end

local function new_harness(now)
	local harness = {
		now = now,
		events = {},
		execs = {},
		delays = {},
		items = {},
		ready_count = 0,
	}

	harness.appearance = {
		colors = {
			identity = { network = 1, network_hotspot = 2 },
			status = { error = 3 },
			pill_fg = 4,
			pill_bg = 5,
			border = 6,
		},
		font_label_bold = function() return {} end,
		font_icon_bold = function() return {} end,
		pill_bg = function() return {} end,
		register_pill = function() end,
		register_colors = function() end,
	}
	harness.startup = {
		track = function()
			local done = false
			return function()
				if not done then
					done = true
					harness.ready_count = harness.ready_count + 1
				end
			end
		end,
		after_reveal = function(_, callback) callback() end,
	}
	harness.sbar = {
		add = function(_, name, initial)
			local item = { name = name, initial = initial, sets = {}, subscriptions = {} }
			function item:set(props)
				item.sets[#item.sets + 1] = props
			end
			function item:subscribe(events, callback)
				if type(events) ~= "table" then events = { events } end
				for _, event in ipairs(events) do
					item.subscriptions[event] = callback
					harness.events[event] = callback
				end
			end
			harness.items[name] = item
			return item
		end,
		set = function() end,
		delay = function(seconds, callback)
			harness.delays[#harness.delays + 1] = { seconds = seconds, callback = callback }
		end,
		exec = function(command, callback)
			local kind = command:find("route get default", 1, true) and "detect" or "sample"
			harness.execs[#harness.execs + 1] = { kind = kind, command = command, callback = callback }
		end,
	}
	return harness
end

local function load_widget(now)
	active = new_harness(now)
	for _, name in ipairs(module_names) do package.loaded[name] = nil end
	dofile(repo_root .. "sketchybar/.config/sketchybar/items/widgets/network.lua")
	return active
end

local function execs_of_kind(harness, kind)
	local matches = {}
	for _, request in ipairs(harness.execs) do
		if request.kind == kind then matches[#matches + 1] = request end
	end
	return matches
end

local function detect_requests(harness)
	return execs_of_kind(harness, "detect")
end

local function sample_requests(harness)
	return execs_of_kind(harness, "sample")
end

local function valid_output(iface)
	iface = iface or "en0"
	return table.concat({
		"route to: default",
		"interface: " .. iface,
		"---SERVICES---",
		"(1) Wi-Fi",
		"(Hardware Port: Wi-Fi, Device: " .. iface .. ")",
		"---NWI---",
		"Network interfaces: " .. iface,
	}, "\n")
end

local function offline_output()
	return table.concat({
		"route to: default",
		"---SERVICES---",
		"(1) Wi-Fi",
		"(Hardware Port: Wi-Fi, Device: en0)",
		"---NWI---",
		"Network interfaces: en0",
	}, "\n")
end

local function fire(harness, event)
	assert(harness.events[event], "network widget must subscribe to " .. event)
	harness.events[event]({})
end

local function assert_deadline_from_completion(result, exit_code, completion, wait_seconds, message)
	local harness = load_widget(completion - 30)
	local request = assert(detect_requests(harness)[1], "initial detection must launch")
	harness.now = completion
	request.callback(result, exit_code)
	harness.now = completion + wait_seconds - 1
	fire(harness, "routine")
	assert(#detect_requests(harness) == 1, message .. " must not retry before its completion deadline")
	harness.now = completion + wait_seconds
	fire(harness, "routine")
	assert(#detect_requests(harness) == 2, message .. " must retry exactly at its completion deadline")
	return harness
end

local real_os_time = os.time
os.time = function() return active.now end

-- Moving this deadline back to request launch time would retry 30 seconds too early.
assert_deadline_from_completion(valid_output(), 0, 130, 60, "valid detection")
assert_deadline_from_completion(offline_output(), 0, 230, 15, "offline detection")
assert_deadline_from_completion("malformed", 0, 330, 15, "malformed detection")
assert_deadline_from_completion(valid_output(), 17, 430, 15, "failed detection")

-- Timeout is a terminal completion at timer fire time, not request launch time.
do
	local harness = load_widget(500)
	local timeout = assert(harness.delays[1], "initial detection must arm a timeout")
	assert(timeout.seconds == 5, "interface detection timeout must remain 5 seconds")
	harness.now = 530
	timeout.callback()
	harness.now = 544
	fire(harness, "routine")
	assert(#detect_requests(harness) == 1, "timed-out detection must not retry before completion plus 15 seconds")
	harness.now = 545
	fire(harness, "routine")
	assert(#detect_requests(harness) == 2, "timed-out detection must retry at completion plus 15 seconds")
end

-- A forced event bypasses an unexpired valid deadline.
do
	local harness = load_widget(600)
	harness.now = 630
	detect_requests(harness)[1].callback(valid_output(), 0)
	harness.now = 631
	fire(harness, "wifi_change")
	assert(#detect_requests(harness) == 2, "forced detection must bypass the current deadline")
end

-- A pending force discards each older result before interface/sample/deadline apply.
-- Replaying generation 1 must neither clear generation 2 nor consume its pending force.
do
	local harness = load_widget(700)
	local generation_1 = detect_requests(harness)[1]
	harness.now = 710
	fire(harness, "wifi_change")
	assert(#detect_requests(harness) == 1, "one in-flight detection may merge only a pending force")

	harness.now = 720
	generation_1.callback(valid_output("en0"), 0)
	local generation_2 = assert(detect_requests(harness)[2], "pending force must start generation 2")
	assert(#sample_requests(harness) == 0, "generation 1 result must be discarded before sampling")

	harness.now = 721
	generation_1.callback(valid_output("en9"), 0)
	harness.now = 722
	fire(harness, "system_woke")
	assert(#detect_requests(harness) == 2, "late generation 1 callback must not clear generation 2 ownership")
	assert(#sample_requests(harness) == 0, "late generation 1 callback must not apply its interface")

	harness.now = 730
	generation_2.callback(valid_output("en1"), 0)
	local generation_3 = assert(detect_requests(harness)[3], "generation 2 must retain and drain its pending force")
	assert(#sample_requests(harness) == 0, "generation 2 result must be discarded before sampling")

	harness.now = 740
	generation_3.callback(valid_output("en2"), 0)
	assert(#sample_requests(harness) == 1, "only the newest accepted detection may launch a sample")
	assert(sample_requests(harness)[1].command:find("en2", 1, true), "newest interface must own the sample")
end

os.time = real_os_time
print("network_detection_deadline_test: ok")
