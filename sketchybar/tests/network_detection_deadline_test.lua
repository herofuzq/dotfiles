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

local function delays_of_seconds(harness, seconds)
	local matches = {}
	for _, request in ipairs(harness.delays) do
		if request.seconds == seconds then matches[#matches + 1] = request end
	end
	return matches
end

local function current_label(harness, item_name)
	local item = assert(harness.items[item_name], "missing item " .. item_name)
	local value = item.initial.label and item.initial.label.string
	for _, props in ipairs(item.sets) do
		if type(props.label) == "string" then
			value = props.label
		elseif type(props.label) == "table" and props.label.string ~= nil then
			value = props.label.string
		end
	end
	return value
end

local function current_icon(harness)
	local item = assert(harness.items["widgets.network_down"])
	local value = item.initial.icon and item.initial.icon.string
	for _, props in ipairs(item.sets) do
		if type(props.icon) == "table" and props.icon.string ~= nil then
			value = props.icon.string
		end
	end
	return value
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

-- Wi-Fi reset and wake fresh-sample intents merge by flags, not last-event wins.
-- In either order, Wi-Fi resets the old failure epoch and wake still causes one fresh sample.
for _, order in ipairs({
	{ "system_woke", "wifi_change" },
	{ "wifi_change", "system_woke" },
}) do
	local harness = load_widget(800)
	harness.now = 810
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("malformed", 0)

	harness.now = 811
	fire(harness, order[1])
	harness.now = 812
	fire(harness, order[2])
	assert(current_label(harness, "widgets.network_up") == "↑ —", "Wi-Fi must clear upload immediately in either event order")
	assert(current_icon(harness) == "wifi", "Wi-Fi reset must retain the detected interface icon")

	harness.now = 813
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 1, "superseded detection must not sample")
	harness.now = 814
	detect_requests(harness)[3].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 2, "merged wake intent must cause one fresh sample")
	sample_requests(harness)[2].callback("malformed", 0)
	harness.now = 816
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "Wi-Fi reset must make the new epoch's first failure wait 3 seconds")
	harness.now = 817
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "Wi-Fi must win over wake without inheriting the old failure count")
end

-- A same-interface Wi-Fi change immediately invalidates the old epoch, clears values,
-- retains its icon, and accepts only a fresh post-detection sample.
do
	local harness = load_widget(900)
	harness.now = 910
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 913
	fire(harness, "routine")
	local old_sample = assert(sample_requests(harness)[2])

	harness.now = 914
	fire(harness, "wifi_change")
	assert(current_label(harness, "widgets.network_up") == "↑ —", "Wi-Fi must clear upload before detection completes")
	assert(current_label(harness, "widgets.network_down") == "↓ —", "Wi-Fi must clear download before detection completes")
	assert(current_icon(harness) == "wifi", "Wi-Fi must retain the current interface-kind icon during detection")
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	old_sample.callback("300 400", 0)
	assert(current_label(harness, "widgets.network_up") == "↑ —", "pre-Wi-Fi sample must not update the reset epoch")
	assert(#sample_requests(harness) == 3, "same-interface Wi-Fi detection must drain exactly one fresh sample")
	sample_requests(harness)[3].callback("500 600", 0)
	assert(current_label(harness, "widgets.network_up") == "↑600K", "fresh Wi-Fi epoch sample must apply")
end

-- Wake invalidates an active sample without clearing its last displayed value. Its accepted
-- same-interface detection discards that current result and drains exactly one forced sample.
do
	local harness = load_widget(1000)
	harness.now = 1010
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 1013
	fire(harness, "routine")
	local pre_wake_sample = assert(sample_requests(harness)[2])

	harness.now = 1014
	fire(harness, "system_woke")
	assert(current_label(harness, "widgets.network_up") == "↑200K", "wake must not clear the last accepted sample")
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 2, "wake must merge a forced sample while the old request owns the slot")
	pre_wake_sample.callback("300 400", 0)
	assert(current_label(harness, "widgets.network_up") == "↑200K", "pre-wake callback must be discarded")
	assert(#sample_requests(harness) == 3, "wake must drain one forced sample after old ownership terminates")
	sample_requests(harness)[3].callback("500 600", 0)
	assert(current_label(harness, "widgets.network_up") == "↑600K", "post-wake sample must apply")
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "accepted wake detection must not duplicate its fresh sample")
end

-- Wake does not reset failure/backoff state when its accepted interface is unchanged.
do
	local harness = load_widget(1100)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("malformed", 0)
	harness.now = 1101
	fire(harness, "system_woke")
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 2, "wake fresh sample must bypass the old backoff")
	sample_requests(harness)[2].callback("malformed", 0)
	harness.now = 1106
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "second consecutive failure after wake must wait 6 seconds")
	harness.now = 1107
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "wake must preserve the unchanged interface's failure sequence")
end

-- A timed-out wake detection retains its fresh-sample intent through an accepted offline
-- result until a non-nil interface, schedules retries from completion, and never samples old A.
do
	local harness = load_widget(1200)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 1201
	fire(harness, "system_woke")
	local wake_timeout = assert(delays_of_seconds(harness, 5)[2], "wake detection must arm its own timeout")
	harness.now = 1206
	wake_timeout.callback()
	assert(#sample_requests(harness) == 1, "wake timeout must not consume intent by sampling the old interface")
	harness.now = 1220
	fire(harness, "routine")
	assert(#detect_requests(harness) == 2, "wake timeout retry must wait 15 seconds from completion")
	harness.now = 1221
	fire(harness, "routine")
	assert(#detect_requests(harness) == 3, "wake timeout must retry exactly at 15 seconds")
	detect_requests(harness)[3].callback(offline_output(), 0)
	assert(#sample_requests(harness) == 1, "accepted offline detection must retain intent without sampling old A")
	harness.now = 1235
	fire(harness, "routine")
	assert(#detect_requests(harness) == 3, "accepted offline retry must wait 15 seconds from completion")
	harness.now = 1236
	fire(harness, "routine")
	assert(#detect_requests(harness) == 4, "accepted offline result must retry at its completion deadline")
	detect_requests(harness)[4].callback(valid_output("en1"), 0)
	assert(#sample_requests(harness) == 2, "next accepted detection must consume retained wake intent once")
	assert(sample_requests(harness)[2].command:find("en1", 1, true), "retained wake intent must sample only the newly accepted interface")
end

-- Interface A-to-B transition starts a clean sample epoch. Failures back off 3/6/12/15
-- seconds, two failures clear values, and a success resets the sequence to 3 seconds.
do
	local harness = load_widget(1300)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	local stale_a = sample_requests(harness)[1]
	harness.now = 1360
	fire(harness, "routine")
	detect_requests(harness)[2].callback(valid_output("en1"), 0)
	assert(current_label(harness, "widgets.network_up") == "↑ —", "A-to-B transition must clear stale upload")
	stale_a.callback("100 200", 0)
	assert(current_label(harness, "widgets.network_up") == "↑ —", "A callback must not update interface B's epoch")
	assert(sample_requests(harness)[2].command:find("en1", 1, true), "new epoch sample must capture interface B")

	sample_requests(harness)[2].callback("malformed", 0)
	harness.now = 1362
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "B first failure must wait 3 seconds")
	harness.now = 1363
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "B first failure must retry at 3 seconds")
	sample_requests(harness)[3].callback("malformed", 0)
	assert(current_label(harness, "widgets.network_down") == "↓ —", "two B failures must mark samples unavailable")
	harness.now = 1368
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "B second failure must wait 6 seconds")
	harness.now = 1369
	fire(harness, "routine")
	assert(#sample_requests(harness) == 4, "B second failure must retry at 6 seconds")
	sample_requests(harness)[4].callback("malformed", 0)
	harness.now = 1380
	fire(harness, "routine")
	assert(#sample_requests(harness) == 4, "B third failure must wait 12 seconds")
	harness.now = 1381
	fire(harness, "routine")
	assert(#sample_requests(harness) == 5, "B third failure must retry at 12 seconds")
	sample_requests(harness)[5].callback("malformed", 0)
	harness.now = 1395
	fire(harness, "routine")
	assert(#sample_requests(harness) == 5, "B fourth failure must wait capped 15 seconds")
	harness.now = 1396
	fire(harness, "routine")
	assert(#sample_requests(harness) == 6, "B fourth failure must retry at capped 15 seconds")
	sample_requests(harness)[6].callback("malformed", 0)
	harness.now = 1411
	fire(harness, "routine")
	assert(#sample_requests(harness) == 7, "B backoff must remain capped at 15 seconds")
	sample_requests(harness)[7].callback("300 400", 0)
	harness.now = 1414
	fire(harness, "routine")
	assert(#sample_requests(harness) == 8, "success must restore the regular 3-second interval")
	sample_requests(harness)[8].callback("malformed", 0)
	harness.now = 1417
	fire(harness, "routine")
	assert(#sample_requests(harness) == 9, "first post-success failure must restart backoff at 3 seconds")
end

-- Routine requests are dropped during logical single-flight. A forced pending request
-- discards the current result, and callback/timeout completion is first-wins by request id.
do
	local harness = load_widget(1500)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	local request_1 = sample_requests(harness)[1]
	fire(harness, "routine")
	assert(#sample_requests(harness) == 1, "routine tick must be dropped while a sample owns the slot")
	fire(harness, "system_woke")
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	delays_of_seconds(harness, 1.5)[1].callback()
	assert(current_label(harness, "widgets.network_up") == "↑ —", "timed-out result must be discarded before forced pending drain")
	local request_2 = assert(sample_requests(harness)[2], "forced pending sample must drain once")
	local request_2_timeout = assert(delays_of_seconds(harness, 1.5)[2], "each sample must arm a 1.5-second timeout")
	harness.now = 1502
	request_2_timeout.callback()
	harness.now = 1504
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "discarded pending timeout must not make the fresh timeout failure number two")
	harness.now = 1505
	fire(harness, "routine")
	local request_3 = assert(sample_requests(harness)[3], "timed-out sample must release ownership for its retry")
	request_2.callback("300 400", 0)
	fire(harness, "routine")
	assert(#sample_requests(harness) == 3, "late callback must not clear the newer request's ownership")
	request_3.callback("500 600", 0)
	assert(current_label(harness, "widgets.network_up") == "↑600K", "new owner callback must apply after stale late callback")

	harness.now = 1508
	fire(harness, "routine")
	local request_4 = assert(sample_requests(harness)[4])
	request_4.callback("700 800", 0)
	harness.now = 1511
	fire(harness, "routine")
	local request_5 = assert(sample_requests(harness)[5])
	delays_of_seconds(harness, 1.5)[4].callback()
	fire(harness, "routine")
	assert(#sample_requests(harness) == 5, "timeout after callback must not clear the next request")
	request_5.callback("900 1000", 0)
	assert(current_label(harness, "widgets.network_up") == "↑1.0M", "callback-first completion must leave subsequent ownership intact")
end

-- Parseable stdout with a nonzero exit is still a sample failure.
do
	local harness = load_widget(1600)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 7)
	assert(current_label(harness, "widgets.network_up") == "↑ —", "nonzero ifstat exit must not publish parseable stdout")
	harness.now = 1602
	fire(harness, "routine")
	assert(#sample_requests(harness) == 1, "nonzero ifstat exit must enter first-failure backoff")
	harness.now = 1603
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "nonzero ifstat exit must retry after 3 seconds")
end

-- An accepted A-to-nil transition starts an offline epoch which a stale A callback
-- cannot resurrect. Interface detection alone never marks speed samples available.
do
	local harness = load_widget(1700)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	local stale_a = sample_requests(harness)[1]
	assert(current_label(harness, "widgets.network_up") == "↑ —", "valid detection must not claim speed availability")
	assert(current_icon(harness) == "wifi", "valid detection must publish interface kind independently")
	harness.now = 1760
	fire(harness, "routine")
	detect_requests(harness)[2].callback(offline_output(), 0)
	assert(current_icon(harness) == "offline", "A-to-nil transition must publish offline interface kind")
	assert(current_label(harness, "widgets.network_down") == "↓ —", "A-to-nil transition must clear speeds")
	stale_a.callback("900 1000", 0)
	assert(current_icon(harness) == "offline", "stale A callback must not resurrect the offline interface")
	assert(current_label(harness, "widgets.network_up") == "↑ —", "stale A callback must not resurrect offline speeds")
	assert(#sample_requests(harness) == 1, "offline transition must never sample the old interface")
end

-- Detection command failures and malformed accepted output are offline transitions;
-- only the 5-second no-callback timer is a non-applying timeout that retains old state.
for _, failure in ipairs({
	{ output = valid_output("en0"), exit_code = 17, name = "nonzero detection" },
	{ output = "malformed", exit_code = 0, name = "malformed detection" },
}) do
	local harness = load_widget(1800)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 1860
	fire(harness, "routine")
	detect_requests(harness)[2].callback(failure.output, failure.exit_code)
	assert(current_icon(harness) == "offline", failure.name .. " must apply an A-to-nil transition")
	assert(current_label(harness, "widgets.network_up") == "↑ —", failure.name .. " must clear stale speeds")
	assert(#sample_requests(harness) == 1, failure.name .. " must not sample old interface A")
end

-- Wi-Fi timeout carries the same fresh-sample intent as wake: suppress old-interface
-- routine samples until the 15-second retry accepts a non-nil interface.
do
	local harness = load_widget(1900)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 1901
	fire(harness, "wifi_change")
	local wifi_timeout = assert(delays_of_seconds(harness, 5)[2])
	harness.now = 1906
	wifi_timeout.callback()
	harness.now = 1920
	fire(harness, "routine")
	assert(#sample_requests(harness) == 1, "Wi-Fi timeout must not sample old A before retry deadline")
	harness.now = 1921
	fire(harness, "routine")
	detect_requests(harness)[3].callback(valid_output("en1"), 0)
	assert(#sample_requests(harness) == 2, "Wi-Fi timeout intent must force one sample after accepted retry")
	assert(sample_requests(harness)[2].command:find("en1", 1, true), "Wi-Fi timeout intent must sample only accepted interface B")
end

-- A routine interface refresh on the unchanged interface respects an active sample
-- backoff; only wake/Wi-Fi fresh intent or a real interface transition may bypass it.
do
	local harness = load_widget(2000)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	harness.now = 2059
	sample_requests(harness)[1].callback("malformed", 0)
	harness.now = 2060
	fire(harness, "routine")
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 1, "routine same-interface detection must not bypass sample backoff")
	harness.now = 2061
	fire(harness, "routine")
	assert(#sample_requests(harness) == 1, "routine same-interface detection must wait until sample deadline")
	harness.now = 2062
	fire(harness, "routine")
	assert(#sample_requests(harness) == 2, "routine same-interface detection must sample at the existing deadline")
end

-- A routine detection timer timeout preserves Step 6 behavior: keep old interface A
-- and immediately attempt its ordinary sample when the sample deadline is already due.
do
	local harness = load_widget(2100)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	sample_requests(harness)[1].callback("100 200", 0)
	harness.now = 2160
	fire(harness, "routine")
	local routine_timeout = assert(delays_of_seconds(harness, 5)[2])
	harness.now = 2165
	routine_timeout.callback()
	assert(#sample_requests(harness) == 2, "routine detection timeout must continue due sampling on old interface A")
	assert(sample_requests(harness)[2].command:find("en0", 1, true), "routine detection timeout must retain old interface A")
end

-- Superseded initial samples cannot satisfy startup readiness. Their matching terminal
-- may release ownership and drain the forced request, but only that fresh sample's
-- terminal is allowed to complete the one-shot readiness token.
for _, scenario in ipairs({
	{ event = "system_woke", terminal = "callback" },
	{ event = "wifi_change", terminal = "timeout" },
}) do
	local harness = load_widget(2200)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	local stale_initial = assert(sample_requests(harness)[1])
	assert(harness.ready_count == 0, "initial sample must own readiness before " .. scenario.event)

	harness.now = 2201
	fire(harness, scenario.event)
	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(#sample_requests(harness) == 1, "fresh sample must wait for stale initial ownership")
	if scenario.terminal == "callback" then
		stale_initial.callback("100 200", 0)
	else
		delays_of_seconds(harness, 1.5)[1].callback()
	end
	assert(harness.ready_count == 0, scenario.event .. " stale " .. scenario.terminal .. " must not complete readiness")
	local fresh = assert(sample_requests(harness)[2], "stale terminal must drain one fresh sample")
	fresh.callback("300 400", 0)
	assert(harness.ready_count == 1, scenario.event .. " fresh sample terminal must complete readiness once")
end

-- The no-pending stale branch has the same readiness rule. If the invalidated initial
-- sample terminates before fresh detection completes, it releases only its own slot;
-- detection and the subsequent fresh sample still own startup completion.
for _, scenario in ipairs({
	{ event = "system_woke", terminal = "callback" },
	{ event = "wifi_change", terminal = "timeout" },
}) do
	local harness = load_widget(2300)
	detect_requests(harness)[1].callback(valid_output("en0"), 0)
	local stale_initial = assert(sample_requests(harness)[1])
	harness.now = 2301
	fire(harness, scenario.event)
	if scenario.terminal == "callback" then
		stale_initial.callback("100 200", 0)
	else
		delays_of_seconds(harness, 1.5)[1].callback()
	end
	assert(harness.ready_count == 0, scenario.event .. " no-pending stale " .. scenario.terminal .. " must not complete readiness")
	assert(#sample_requests(harness) == 1, "stale terminal before detection must not sample the old interface")

	detect_requests(harness)[2].callback(valid_output("en0"), 0)
	assert(harness.ready_count == 0, "accepted fresh detection must leave readiness to its sample")
	local fresh = assert(sample_requests(harness)[2], "accepted fresh detection must launch one sample")
	fresh.callback("300 400", 0)
	assert(harness.ready_count == 1, scenario.event .. " no-pending fresh sample must complete readiness once")
end

os.time = real_os_time
print("network_detection_deadline_test: ok")
