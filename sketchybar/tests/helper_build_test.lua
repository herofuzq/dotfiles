local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local helper_build = require("helpers.helper_build")

local specs = {
	{ id = "missing", target = "/tmp/missing", sources = { "/tmp/missing.swift" } },
	{ id = "stale", target = "/tmp/stale", sources = { "/tmp/stale.swift" } },
	{ id = "fresh", target = "/tmp/fresh", sources = { "/tmp/fresh.swift" } },
}
local mtimes = {
	["/tmp/missing.swift"] = 100,
	["/tmp/stale"] = 100,
	["/tmp/stale.swift"] = 200,
	["/tmp/fresh"] = 300,
	["/tmp/fresh.swift"] = 200,
}

local plan = helper_build.plan(specs, mtimes)
assert(#plan.sync == 1 and plan.sync[1].id == "missing", "missing binaries must be built synchronously")
assert(#plan.background == 1 and plan.background[1].id == "stale", "stale binaries should rebuild in background")
assert(#plan.fresh == 1 and plan.fresh[1].id == "fresh", "up-to-date binaries should be skipped")

print("helper_build_test: ok")
