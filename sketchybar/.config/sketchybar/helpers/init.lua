-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"

local function shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- bin 位于实际 CONFIG_DIR，不由 stow 管理；这里只在缺失或源码更新时编译。
local function needs_make(cfg)
	local helpers = cfg .. "/helpers"
	local targets = {
		{
			target = helpers .. "/event_providers/cpu_load/bin/cpu_load",
			sources = {
				helpers .. "/event_providers/cpu_load/cpu_load.c",
				helpers .. "/event_providers/cpu_load/cpu.h",
				helpers .. "/event_providers/sketchybar.h",
				helpers .. "/event_providers/cpu_load/makefile",
			},
		},
		{
			target = helpers .. "/event_providers/input_method/bin/input_method_watch",
			sources = {
				helpers .. "/event_providers/input_method/input_method_watch.swift",
				helpers .. "/event_providers/input_method/makefile",
			},
		},
		{
			target = helpers .. "/event_providers/media_watch/bin/media_watch",
			sources = {
				helpers .. "/event_providers/media_watch/media_watch.swift",
				helpers .. "/event_providers/media_watch/makefile",
			},
		},
		{
			target = helpers .. "/menus/bin/menus",
			sources = {
				helpers .. "/menus/menus.c",
				helpers .. "/menus/makefile",
			},
		},
		{
			target = helpers .. "/bar_height/bin/bar_height",
			sources = {
				helpers .. "/bar_height/main.swift",
				helpers .. "/bar_height/makefile",
			},
		},
		{
			target = helpers .. "/dock_width/bin/dock_width",
			sources = {
				helpers .. "/dock_width/main.swift",
				helpers .. "/dock_width/makefile",
			},
		},
	}
	local checks = {}
	for _, item in ipairs(targets) do
		local target = shell_quote(item.target)
		checks[#checks + 1] = "[ ! -x " .. target .. " ]"
		for _, source in ipairs(item.sources) do
			checks[#checks + 1] = "[ " .. shell_quote(source) .. " -nt " .. target .. " ]"
		end
	end
	local cmd = "if " .. table.concat(checks, " || ") .. "; then printf 1; else printf 0; fi"
	local f = io.popen(cmd)
	if not f then
		return true
	end
	local stale = f:read("*a") == "1"
	f:close()
	return stale
end

local function run_make(cfg)
	local log_path = "/tmp/sketchybar_make.log"
	local cmd = "cd "
		.. shell_quote(cfg .. "/helpers")
		.. " && make > "
		.. shell_quote(log_path)
		.. " 2>&1; printf '\\n%s' \"$?\""
	local f = io.popen(cmd)
	local exit_code = "1"
	if f then
		exit_code = (f:read("*a") or ""):match("(%d+)%s*$") or "1"
		f:close()
	end
	return tonumber(exit_code) or 1, log_path
end

local function restart_event_providers()
	os.execute(
		"launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.input_method_watch >/dev/null 2>&1; "
			.. "launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.media_watch >/dev/null 2>&1 &"
	)
end

local cfg = os.getenv("CONFIG_DIR")
if cfg and needs_make(cfg) then
	local exit_code, log_path = run_make(cfg)
	if exit_code ~= 0 then
		io.stderr:write("sketchybar: helper compile failed (exit " .. exit_code .. "), see " .. log_path .. "\n")
	else
		restart_event_providers()
	end
end
