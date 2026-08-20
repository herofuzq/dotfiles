local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
if repo_root == "" then
	local pwd = assert(io.popen("pwd"))
	repo_root = assert(pwd:read("*l")) .. "/"
	pwd:close()
end
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local helper_build = require("helpers.helper_build")

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

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

-- Changing the shared compiler wrapper must mark every helper target stale.
local cfg = "/tmp/helper_build_specs"
local production_specs = helper_build.specs(cfg)
assert(#production_specs == 9, "expected all nine helper specs")
local wrapper = cfg .. "/helpers/helper_compile.sh"
local wrapper_mtimes = { [wrapper] = 200 }
for _, production_spec in ipairs(production_specs) do
	wrapper_mtimes[production_spec.target] = 100
	local saw_wrapper = false
	for _, source_path in ipairs(production_spec.sources) do
		if source_path == wrapper then saw_wrapper = true end
		if wrapper_mtimes[source_path] == nil then wrapper_mtimes[source_path] = 90 end
	end
	assert(saw_wrapper, production_spec.id .. " must depend on helper_compile.sh")
end
local wrapper_plan = helper_build.plan(production_specs, wrapper_mtimes)
assert(#wrapper_plan.background == 9, "a helper_compile.sh edit must rebuild every helper")

-- The generated make recipes must delegate publication to helper_compile.sh;
-- `make -n` executes no compiler and creates no helper output.
local make_specs = {
	{ id = "cpu_load", dir = "helpers/event_providers/cpu_load", target = "bin/cpu_load",
		sources = { "cpu_load.c", "cpu.h", "../sketchybar.h", "makefile", "../../helper_compile.sh" } },
	{ id = "aerospace_watch", dir = "helpers/event_providers/aerospace_watch", target = "bin/aerospace_watch",
		sources = { "aerospace_watch.swift", "../sketchybar_mach.swift", "../sketchybar_mach.c", "../sketchybar.h", "makefile", "../../swift.mk", "../../helper_compile.sh" } },
	{ id = "docker_watch", dir = "helpers/event_providers/docker_watch", target = "bin/docker_watch",
		sources = { "docker_watch.swift", "../sketchybar_mach.swift", "../sketchybar_mach.c", "../sketchybar.h", "makefile", "../../swift.mk", "../../helper_compile.sh" } },
	{ id = "input_method_watch", dir = "helpers/event_providers/input_method", target = "bin/input_method_watch",
		sources = { "input_method_watch.swift", "../sketchybar_mach.swift", "../sketchybar_mach.c", "../sketchybar.h", "makefile", "../../swift.mk", "../../helper_compile.sh" } },
	{ id = "media_watch", dir = "helpers/event_providers/media_watch", target = "bin/media_watch",
		sources = { "media_watch.swift", "../sketchybar_mach.swift", "../sketchybar_mach.c", "../sketchybar.h", "makefile", "../../swift.mk", "../../helper_compile.sh" } },
	{ id = "sys_watch", dir = "helpers/event_providers/sys_watch", target = "bin/sys_watch",
		sources = { "sys_watch.swift", "../sketchybar_mach.swift", "../sketchybar_mach.c", "../sketchybar.h", "makefile", "../../swift.mk", "../../helper_compile.sh" } },
	{ id = "menus", dir = "helpers/menus", target = "bin/menus",
		sources = { "menus.c", "makefile", "../helper_compile.sh" } },
	{ id = "bar_height", dir = "helpers/bar_height", target = "bin/bar_height",
		sources = { "main.swift", "makefile", "../swift.mk", "../helper_compile.sh" } },
	{ id = "dock_width", dir = "helpers/dock_width", target = "bin/dock_width",
		sources = { "main.swift", "makefile", "../swift.mk", "../helper_compile.sh" } },
}
local config_root = repo_root .. "sketchybar/.config/sketchybar/"
for index, make_spec in ipairs(make_specs) do
	assert(#production_specs[index].sources == #make_spec.sources,
		make_spec.id .. " Lua spec and make recipe must hash the same source count")
	local command = "make -Bnp -C " .. shell_quote(config_root .. make_spec.dir)
		.. " SKETCHYBAR_SWIFTC=/usr/bin/true 2>&1"
	local pipe = assert(io.popen(command))
	local output = pipe:read("*a") or ""
	pipe:close()
	local recipe
	for line in output:gmatch("[^\n]+") do
		if line:find("helper_compile.sh " .. make_spec.id .. " ", 1, true) then
			recipe = line
			break
		end
	end
	assert(recipe, make_spec.id .. " make recipe must use helper_compile.sh and pass its spec id")
	assert(not recipe:find(".new", 1, true), make_spec.id .. " make recipe must not use a shared fixed .new path")
	local recipe_tokens = {}
	for token in recipe:gmatch("%S+") do recipe_tokens[#recipe_tokens + 1] = token end
	local wrapper_index
	for token_index, token in ipairs(recipe_tokens) do
		if token:match("helper_compile%.sh$") then wrapper_index = token_index break end
	end
	assert(wrapper_index, make_spec.id .. " recipe must invoke the wrapper")
	assert(recipe_tokens[wrapper_index + 1] == make_spec.id, make_spec.id .. " wrapper id mismatch")
	assert(recipe_tokens[wrapper_index + 2] == make_spec.target, make_spec.id .. " wrapper target mismatch")
	assert(recipe_tokens[wrapper_index + 3] == tostring(#make_spec.sources), make_spec.id .. " wrapper source count mismatch")
	for source_index, source_path in ipairs(make_spec.sources) do
		assert(recipe_tokens[wrapper_index + 3 + source_index] == source_path,
			make_spec.id .. " wrapper source order mismatch at " .. source_path)
	end
	assert(recipe_tokens[wrapper_index + 4 + #make_spec.sources] == "--",
		make_spec.id .. " wrapper source list must terminate with --")

	local escaped_target = make_spec.target:gsub("([^%w])", "%%%1")
	local prerequisites = output:match("\n" .. escaped_target .. ": ([^\n]+)")
	assert(prerequisites, make_spec.id .. " target prerequisites must be present in make's database")
	for _, source_path in ipairs(make_spec.sources) do
		assert(prerequisites:find(source_path, 1, true),
			make_spec.id .. " make prerequisites must include " .. source_path)
	end
end

print("helper_build_test: ok")
