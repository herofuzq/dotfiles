local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local active
local module_names = {
	"sketchybar",
	"appearance",
	"icons",
	"fonts",
	"helpers.timing",
	"helpers.utils",
	"helpers.find_binary",
	"helpers.git.config",
	"helpers.popup_utils",
	"helpers.startup",
}

package.preload["sketchybar"] = function() return active.sbar end
package.preload["appearance"] = function() return active.appearance end
package.preload["icons"] = function() return { git = "G" } end
package.preload["fonts"] = function()
	return {
		font = { text = "Test", style_map = { Bold = "Bold" } },
		popup = { text = "Test", style_map = { Bold = "Bold" }, size = 12 },
	}
end
package.preload["helpers.timing"] = function() return { STANDARD_DURATION_FRAMES = 1 } end
package.preload["helpers.utils"] = function() return { shell_quote = function(value) return tostring(value) end } end
package.preload["helpers.find_binary"] = function() return { find = function(_, fallback) return fallback end } end
package.preload["helpers.git.config"] = function() return active.config end
package.preload["helpers.popup_utils"] = function() return { defer = function(callback) callback() end } end
package.preload["helpers.startup"] = function() return active.startup end

local function new_harness(options)
	options = options or {}
	local harness = {
		items = {},
		events = {},
		execs = {},
		delays = {},
		ready_count = 0,
		override_home = options.override_home == true,
		home = options.home,
		config = options.config or {
			item = { name = "git_status" },
			repos = {
				{ path = "/repo/alpha", label = "Alpha" },
				{ path = "/repo/beta", label = "Beta" },
			},
		},
	}

	harness.appearance = {
		colors = {
			text = 1,
			surface1 = 2,
			count = 3,
			pill_fg = 4,
			status = { ok = 5, warn = 6 },
		},
		font_icon_bold = function() return {} end,
		popup_bg = function() return { color = 10, border_color = 11 } end,
		with_alpha = function(color) return color end,
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
		delay = function(seconds, callback)
			harness.delays[#harness.delays + 1] = { seconds = seconds, callback = callback }
		end,
		exec = function(command, callback)
			harness.execs[#harness.execs + 1] = { command = command, callback = callback }
		end,
		animate = function(_, _, callback) callback() end,
	}
	return harness
end

local function load_widget()
	for _, name in ipairs(module_names) do package.loaded[name] = nil end
	local real_getenv = os.getenv
	if active.override_home then
		os.getenv = function(name)
			if name == "HOME" then return active.home end
			return real_getenv(name)
		end
	end
	local ok, err = xpcall(function()
		dofile(repo_root .. "sketchybar/.config/sketchybar/items/git.lua")
	end, debug.traceback)
	os.getenv = real_getenv
	if not ok then error(err) end
end

local function fresh_harness(options)
	active = new_harness(options)
	load_widget()
	assert(#active.execs == 1, "widget must launch one initial helper request")
	assert(#active.delays == 1 and active.delays[1].seconds == 8, "widget must arm the initial timeout")
	return active
end

local function valid_snapshot(alpha_status, alpha_dirty)
	alpha_status = alpha_status or "dirty"
	alpha_dirty = alpha_dirty or "2"
	return table.concat({
		table.concat({ "repo", "/repo/alpha", "Alpha", "main", alpha_status, alpha_dirty, "1", "0" }, "\t"),
		table.concat({ "repo", "/repo/beta", "Beta", "dev", "ok", "0", "0", "1" }, "\t"),
	}, "\n") .. "\n"
end

local function snapshot_for(repos)
	local lines = {}
	for _, repo in ipairs(repos) do
		lines[#lines + 1] = table.concat({ "repo", repo.path, repo.label, "main", "ok", "0", "0", "0" }, "\t")
	end
	return table.concat(lines, "\n") .. "\n"
end

local function latest_label(item)
	for index = #item.sets, 1, -1 do
		local label = item.sets[index].label
		if type(label) == "table" and label.string ~= nil then return label.string end
	end
	return nil
end

local function show_cached(harness)
	assert(harness.events["mouse.clicked"], "git item must subscribe to mouse.clicked")
	harness.events["mouse.clicked"]({})
end

local function row_labels(harness)
	return latest_label(harness.items["git_status.popup.repo.1"]), latest_label(harness.items["git_status.popup.repo.2"])
end

local function assert_all_unavailable(harness, message)
	show_cached(harness)
	local alpha, beta = row_labels(harness)
	assert(alpha and alpha:find("unavailable", 1, true), message .. ": alpha must be unavailable")
	assert(beta and beta:find("unavailable", 1, true), message .. ": beta must be unavailable")
	assert(not alpha:find("dirty", 1, true), message .. ": invalid alpha data must not partially apply")
	assert(latest_label(harness.items.git_status) == "0", message .. ": invalid snapshots must not partially update the aggregate")
end

-- Replacing literal HOME boundary checks with an anchored prefix match would
-- collapse sibling paths, while treating empty HOME as a prefix would collapse
-- every absolute path.
local home_path_fixtures = {
	{ name = "exact home", home = "/Users/foo", path = "/Users/foo", expected = "~" },
	{ name = "home child", home = "/Users/foo", path = "/Users/foo/repo", expected = "~/repo" },
	{ name = "home sibling", home = "/Users/foo", path = "/Users/foobar/repo", expected = "/Users/foobar/repo" },
	{ name = "empty home", home = "", path = "/Volumes/repo", expected = "/Volumes/repo" },
	{ name = "missing home", path = "/Volumes/repo", expected = "/Volumes/repo" },
}

for _, fixture in ipairs(home_path_fixtures) do
	local repos = { { path = fixture.path, label = "Fixture" } }
	harness = fresh_harness({
		override_home = true,
		home = fixture.home,
		config = { item = { name = "git_status" }, repos = repos },
	})
	harness.execs[1].callback(snapshot_for(repos), 0)
	show_cached(harness)
	local rendered = latest_label(harness.items["git_status.popup.repo.1"])
	assert(
		rendered and rendered:sub(-#fixture.expected) == fixture.expected,
		fixture.name .. ": expected rendered path suffix " .. fixture.expected .. ", got " .. tostring(rendered)
	)
end

-- Removing exit-code validation would apply the valid-looking dirty row.
harness = fresh_harness()
harness.execs[1].callback(valid_snapshot(), 17)
assert_all_unavailable(harness, "outer nonzero")
assert(harness.ready_count == 1, "outer nonzero must settle readiness once")

-- Removing the shared terminal guard would let the late success replace timeout state.
harness = fresh_harness()
harness.delays[1].callback()
harness.execs[1].callback(valid_snapshot(), 0)
assert_all_unavailable(harness, "timeout then late success")
assert(harness.ready_count == 1, "timeout and late callback must settle readiness once")

local invalid_snapshots = {
	{
		name = "missing configured path",
		output = "repo\t/repo/alpha\tAlpha\tmain\tok\t0\t0\t0\n",
	},
	{
		name = "extra unknown path",
		output = valid_snapshot() .. "repo\t/repo/extra\tExtra\tmain\tok\t0\t0\t0\n",
	},
	{
		name = "duplicate path",
		output = valid_snapshot() .. "repo\t/repo/alpha\tAlpha\tmain\tok\t0\t0\t0\n",
	},
	{
		name = "malformed field count",
		output = "repo\t/repo/alpha\tAlpha\tmain\tdirty\t2\t1\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "malformed blank row",
		output = "repo\t/repo/alpha\tAlpha\tmain\tdirty\t2\t1\t0\n\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "empty path",
		output = "repo\t\tAlpha\tmain\tok\t0\t0\t0\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "wrong configured label",
		output = "repo\t/repo/alpha\tForged\tmain\tdirty\t2\t1\t0\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "unknown status",
		output = "repo\t/repo/alpha\tAlpha\tmain\tunknown\t0\t0\t0\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "ok with dirty files",
		output = valid_snapshot("ok", "2"),
	},
	{
		name = "dirty with zero files",
		output = valid_snapshot("dirty", "0"),
	},
	{
		name = "nonnumeric ahead",
		output = "repo\t/repo/alpha\tAlpha\tmain\tdirty\t2\tx\t0\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "error with data fields",
		output = "repo\t/repo/alpha\tAlpha\t-\terror\t0\t-\t-\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
	{
		name = "missing with data fields",
		output = "repo\t/repo/alpha\tAlpha\tmain\tmissing\t-\t-\t-\n" ..
			"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\t1\n",
	},
}

for _, fixture in ipairs(invalid_snapshots) do
	harness = fresh_harness()
	harness.execs[1].callback(fixture.output, 0)
	assert_all_unavailable(harness, fixture.name)
end

-- A malformed second row must reject the complete snapshot before the first dirty row applies.
harness = fresh_harness()
harness.execs[1].callback(
	"repo\t/repo/alpha\tAlpha\tmain\tdirty\t9\t0\t0\n" ..
	"repo\t/repo/beta\tBeta\tdev\tok\t0\t0\n",
	0
)
assert_all_unavailable(harness, "atomic validation")

-- Exact valid snapshots apply both popup rows and the aggregate together.
harness = fresh_harness()
harness.execs[1].callback(valid_snapshot(), 0)
show_cached(harness)
local alpha, beta = row_labels(harness)
assert(alpha and alpha:find("Alpha", 1, true) and alpha:find("2 dirty", 1, true) and alpha:find("↑1", 1, true))
assert(beta and beta:find("Beta", 1, true) and beta:find("clean", 1, true) and beta:find("↓1", 1, true))
assert(latest_label(harness.items.git_status) == "2", "valid exact snapshot must update aggregate dirty count")

-- Existing popup-only protocol wording stays intact for valid unavailable/missing rows.
harness = fresh_harness()
harness.execs[1].callback(
	"repo\t/repo/alpha\tAlpha\t-\terror\t-\t-\t-\n" ..
	"repo\t/repo/beta\tBeta\t-\tmissing\t-\t-\t-\n",
	0
)
show_cached(harness)
alpha, beta = row_labels(harness)
assert(alpha and alpha:find("unavailable", 1, true), "valid error row must remain popup-only unavailable")
assert(beta and beta:find("missing", 1, true), "valid missing row must retain its existing popup wording")
assert(latest_label(harness.items.git_status) == "0", "unavailable rows must not add a new aggregate state")

print("git_widget_protocol_test: ok")
