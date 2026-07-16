-- ========== Helper binary build coordinator ==========
-- One batched stat classifies targets before startup:
-- missing binaries build synchronously; stale binaries rebuild in background.
-- Builds always run in CONFIG_DIR (the live ~/.config tree), never in dotfiles.

local shell_quote = require("helpers.utils").shell_quote
local tmp_path = require("helpers.utils").tmp_path

local M = {}

function M.specs(cfg)
	local h = cfg .. "/helpers"
	local swift_mk = h .. "/swift.mk"
	return {
		{
			id = "cpu_load",
			target = h .. "/event_providers/cpu_load/bin/cpu_load",
			build_dir = h .. "/event_providers/cpu_load",
			sources = {
				h .. "/event_providers/cpu_load/cpu_load.c",
				h .. "/event_providers/cpu_load/cpu.h",
				h .. "/event_providers/sketchybar.h",
				h .. "/event_providers/cpu_load/makefile",
			},
		},
		{
			id = "aerospace_watch",
			target = h .. "/event_providers/aerospace_watch/bin/aerospace_watch",
			build_dir = h .. "/event_providers/aerospace_watch",
			restart_label = "com.fuzhuoqun.aerospace_watch",
			sources = {
				h .. "/event_providers/aerospace_watch/aerospace_watch.swift",
				h .. "/event_providers/aerospace_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "docker_watch",
			target = h .. "/event_providers/docker_watch/bin/docker_watch",
			build_dir = h .. "/event_providers/docker_watch",
			restart_label = "com.fuzhuoqun.docker_watch",
			sources = {
				h .. "/event_providers/docker_watch/docker_watch.swift",
				h .. "/event_providers/docker_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "input_method_watch",
			target = h .. "/event_providers/input_method/bin/input_method_watch",
			build_dir = h .. "/event_providers/input_method",
			restart_label = "com.fuzhuoqun.input_method_watch",
			sources = {
				h .. "/event_providers/input_method/input_method_watch.swift",
				h .. "/event_providers/input_method/makefile",
				swift_mk,
			},
		},
		{
			id = "media_watch",
			target = h .. "/event_providers/media_watch/bin/media_watch",
			build_dir = h .. "/event_providers/media_watch",
			restart_label = "com.fuzhuoqun.media_watch",
			sources = {
				h .. "/event_providers/media_watch/media_watch.swift",
				h .. "/event_providers/media_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "sys_watch",
			target = h .. "/event_providers/sys_watch/bin/sys_watch",
			build_dir = h .. "/event_providers/sys_watch",
			sources = {
				h .. "/event_providers/sys_watch/sys_watch.swift",
				h .. "/event_providers/sys_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "menus",
			target = h .. "/menus/bin/menus",
			build_dir = h .. "/menus",
			sources = { h .. "/menus/menus.c", h .. "/menus/makefile" },
		},
		{
			id = "bar_height",
			target = h .. "/bar_height/bin/bar_height",
			build_dir = h .. "/bar_height",
			sources = { h .. "/bar_height/main.swift", h .. "/bar_height/makefile", swift_mk },
		},
		{
			id = "dock_width",
			target = h .. "/dock_width/bin/dock_width",
			build_dir = h .. "/dock_width",
			sources = { h .. "/dock_width/main.swift", h .. "/dock_width/makefile", swift_mk },
		},
	}
end

local function all_paths(specs)
	local paths, seen = {}, {}
	for _, spec in ipairs(specs) do
		local candidates = { spec.target }
		for _, source in ipairs(spec.sources) do
			candidates[#candidates + 1] = source
		end
		for _, path in ipairs(candidates) do
			if not seen[path] then
				seen[path] = true
				paths[#paths + 1] = path
			end
		end
	end
	return paths
end

function M.read_mtimes(specs)
	local quoted = {}
	for _, path in ipairs(all_paths(specs)) do
		quoted[#quoted + 1] = shell_quote(path)
	end
	if #quoted == 0 then return {} end

	local pipe = io.popen("stat -L -f '%m\t%N' " .. table.concat(quoted, " ") .. " 2>/dev/null")
	if not pipe then return {} end
	local mtimes = {}
	for line in pipe:lines() do
		local mtime, path = line:match("^(%d+)\t(.*)$")
		if mtime and path then mtimes[path] = tonumber(mtime) end
	end
	pipe:close()
	return mtimes
end

function M.plan(specs, mtimes)
	local plan = { sync = {}, background = {}, fresh = {} }
	for _, spec in ipairs(specs) do
		local target_mtime = mtimes[spec.target]
		if not target_mtime then
			plan.sync[#plan.sync + 1] = spec
		else
			local stale = false
			for _, source in ipairs(spec.sources) do
				local source_mtime = mtimes[source]
				if not source_mtime or source_mtime > target_mtime then
					stale = true
					break
				end
			end
			local bucket = stale and plan.background or plan.fresh
			bucket[#bucket + 1] = spec
		end
	end
	return plan
end

local function restart_event_providers(specs)
	local commands = {}
	for _, spec in ipairs(specs) do
		if spec.restart_label then
			commands[#commands + 1] = "launchctl kickstart -k gui/$(id -u)/"
				.. spec.restart_label .. " >/dev/null 2>&1"
		end
	end
	if #commands > 0 then os.execute(table.concat(commands, "; ") .. " &") end
end

local function run_sync(spec, log_path)
	local command = "make -C " .. shell_quote(spec.build_dir)
		.. " >> " .. shell_quote(log_path) .. " 2>&1; printf '\n%s' \"$?\""
	local pipe = io.popen(command)
	if not pipe then return false end
	local output = pipe:read("*a") or ""
	pipe:close()
	return tonumber(output:match("(%d+)%s*$") or "1") == 0
end

local function build_missing(specs, log_path)
	local succeeded = {}
	for _, spec in ipairs(specs) do
		if run_sync(spec, log_path) then
			succeeded[#succeeded + 1] = spec
		else
			io.stderr:write("sketchybar: helper compile failed: " .. spec.id .. ", see " .. log_path .. "\n")
		end
	end
	restart_event_providers(succeeded)
end

local function build_stale(specs, log_path)
	if #specs == 0 then return end
	local script = {}
	for index, spec in ipairs(specs) do
		script[#script + 1] = "if make -C " .. shell_quote(spec.build_dir)
			.. " >> " .. shell_quote(log_path)
			.. " 2>&1; then printf 'OK " .. index
			.. "\\n'; else printf 'FAIL " .. index .. "\\n'; fi"
	end

	require("sketchybar").exec(table.concat(script, "\n"), function(output)
		local succeeded = {}
		for index in (output or ""):gmatch("OK%s+(%d+)") do
			local spec = specs[tonumber(index)]
			if spec then succeeded[#succeeded + 1] = spec end
		end
		restart_event_providers(succeeded)
		if (output or ""):find("FAIL ", 1, true) then
			io.stderr:write("sketchybar: background helper compile failed, see " .. log_path .. "\n")
		end
	end)
end

function M.ensure(cfg)
	local specs = M.specs(cfg)
	local plan = M.plan(specs, M.read_mtimes(specs))
	if #plan.sync == 0 and #plan.background == 0 then return end

	local log_path = tmp_path("sketchybar_make.log")
	local log = io.open(log_path, "w")
	if log then log:close() end
	if #plan.sync > 0 then
		build_missing(plan.sync, log_path)
	end
	build_stale(plan.background, log_path)
end

return M
