local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local active

package.preload["sketchybar"] = function()
	return active.sbar
end
package.preload["fonts"] = function()
	return { font = { text = "test", style_map = { Semibold = "Regular" }, size = 12 } }
end
package.preload["appearance"] = function()
	return active.appearance
end
package.preload["helpers.timing"] = function()
	return { STANDARD_DURATION_FRAMES = 1, frames_to_seconds = function() return 0 end }
end
package.preload["helpers.textwidth"] = function()
	return { chars_within_width = function(value) return #value end }
end
package.preload["helpers.find_binary"] = function()
	return { find = function(_, fallback) return fallback end }
end
package.preload["helpers.utils"] = function()
	return { shell_quote = function(value) return value end }
end
package.preload["helpers.startup"] = function()
	return active.startup
end

local function new_harness()
	local harness = { events = {}, execs = {}, items = {}, sets = {}, launches = 0 }
	local startup = { pending = {}, pending_order = {}, waiters = {}, waiter_count = 0 }

	function startup.after_reveal(key, callback)
		if startup.revealed then
			callback()
			return
		end
		if startup.pending[key] == nil then
			startup.pending_order[#startup.pending_order + 1] = key
		end
		startup.pending[key] = callback
	end

	function startup.track(key)
		if startup.waiters[key] ~= nil then
			return function() end
		end
		startup.waiters[key] = false
		startup.waiter_count = startup.waiter_count + 1
		local done = false
		return function()
			if done then
				return
			end
			done = true
			if startup.waiters[key] == false then
				startup.waiters[key] = true
				startup.waiter_count = startup.waiter_count - 1
			end
			if startup.waiter_count == 0 and startup.ready_callback then
				local callback = startup.ready_callback
				startup.ready_callback = nil
				callback(false)
			end
		end
	end

	function startup.prime_pending()
		for _, key in ipairs(startup.pending_order) do
			local callback = startup.pending[key]
			if callback then
				callback()
			end
		end
	end

	function startup.when_ready(callback)
		local launched = false
		local function launch(timed_out)
			if launched then
				return
			end
			launched = true
			startup.prime_pending()
			callback(timed_out)
		end
		if startup.waiter_count == 0 then
			launch(false)
		else
			startup.ready_callback = launch
		end
	end

	function startup.finish_reveal()
		startup.revealed = true
		startup.prime_pending()
		startup.pending = {}
		startup.pending_order = {}
	end

	harness.startup = startup
	harness.appearance = {
		colors = {
			identity = { music_text = 0xffeeeeee, music_icon = 0xffdddddd },
			pill_fg = 0xffcccccc,
			press = 0xffbbbbbb,
		},
		font_icon_bold = function() return {} end,
		with_alpha = function(color) return color end,
		register_colors = function() end,
	}
	harness.sbar = {
		add = function(_, name)
			local item = { name = name, subscriptions = {} }
			function item:set(props)
				item.last_set = props
			end
			function item:subscribe(event, callback)
				item.subscriptions[event] = callback
				harness.events[event] = callback
			end
			function item:query()
				return { icon = { value = "\u{f04b}" } }
			end
			harness.items[name] = item
			return item
		end,
		set = function(name, props)
			harness.sets[#harness.sets + 1] = { name = name, props = props }
		end,
		exec = function(command, callback)
			harness.execs[#harness.execs + 1] = { command = command, callback = callback }
		end,
		animate = function(_, _, callback) callback() end,
		delay = function(_, callback) callback() end,
		trigger = function() end,
	}
	return harness
end

local function load_media()
	for _, module in ipairs({
		"sketchybar",
		"fonts",
		"appearance",
		"helpers.timing",
		"helpers.textwidth",
		"helpers.find_binary",
		"helpers.utils",
		"helpers.startup",
	}) do
		package.loaded[module] = nil
	end
	dofile(repo_root .. "sketchybar/.config/sketchybar/items/widgets/media.lua")
end

local function media_state(title)
	return { title = title, artist = title .. " Artist", album = title .. " Album", playing = true }
end

local function label_text(harness)
	local props = harness.items["widgets.media_label"].last_set
	return props and props.label and props.label.string
end

local function arm_startup(harness)
	harness.startup.when_ready(function()
		harness.launches = harness.launches + 1
		harness.label_at_launch = label_text(harness)
	end)
end

-- A removed generation bump would let initial Q1 overwrite authoritative B.
active = new_harness()
load_media()
arm_startup(active)
local q1 = active.execs[1].callback
active.events.media_update({ TITLE = "B", ARTIST = "B Artist", ALBUM = "B Album", PLAYING = "1" })
q1(media_state("Q1"))
active.startup.finish_reveal()
assert(label_text(active) == "B - B Artist - B Album", "authoritative B must win over late initial Q1")
assert(active.label_at_launch == "B - B Artist - B Album", "authoritative state must be primed before startup launch")
assert(active.launches == 1, "authoritative B must launch the startup barrier exactly once")

-- A refresh query must be allowed to replace Q1 and complete the readiness barrier itself.
active = new_harness()
load_media()
arm_startup(active)
q1 = active.execs[1].callback
active.events.media_update({})
local q2 = active.execs[2].callback
q2(media_state("Q2"))
q1(media_state("Q1"))
active.startup.finish_reveal()
assert(label_text(active) == "Q2 - Q2 Artist - Q2 Album", "fieldless Q2 must win over late Q1")
assert(active.label_at_launch == "Q2 - Q2 Artist - Q2 Album", "fieldless Q2 state must be primed before startup launch")
assert(active.launches == 1, "winning fieldless Q2 must launch the startup barrier once")

-- A partial event is not a state snapshot; it must request a complete query instead.
active = new_harness()
load_media()
arm_startup(active)
active.events.media_update({ TITLE = "Partial" })
assert(#active.execs == 2, "partial media_update must launch a fallback query")
active.execs[2].callback(media_state("Queried"))
active.startup.finish_reveal()
assert(label_text(active) == "Queried - Queried Artist - Queried Album", "partial event must not clear absent media fields")
assert(active.label_at_launch == "Queried - Queried Artist - Queried Album", "query state must be primed before startup launch")
assert(active.launches == 1, "winning query must launch the startup barrier once")

print("media_arbitration_test: ok")
