-- ========== Helper 二进制编译管理 ==========
-- 启动时检查 helpers/event_providers/ 下各 Swift/C helper 源码是否比编译产物新，
-- 是的话跑 make 重建。bin/ 不在 dotfiles 里 stow（避免每次 make 都触发 git diff）。

local home = os.getenv("HOME")
local config_dir = os.getenv("CONFIG_DIR") or (home and (home .. "/.config/sketchybar")) or "."

-- Lua modules should resolve from the live SketchyBar config directory, not
-- from whatever working directory launchd / sketchybar happens to use.
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path
if home then
	package.cpath = package.cpath .. ";" .. home .. "/.local/share/sketchybar_lua/?.so"
end

-- 最早把 bar 藏起来，并把 height 压到 0：
-- reload 后 internal default 常用错误高度（如 25/32）先画一帧，再被配置改掉，
-- 看起来就是「先闪一条高度不对的 bar」。hidden + height=0 把这条默认条掐掉。
require("sketchybar").bar({
	hidden = "on",
	height = 0,
	color = 0x00000000,
	border_color = 0x00000000,
	border_width = 0,
	blur_radius = 0,
})

local shell_quote = require("helpers.utils").shell_quote
local tmp_path = require("helpers.utils").tmp_path

-- bin 位于实际 CONFIG_DIR，不由 stow 管理。启动时先用 mtime 快速判断
-- helper 是否 stale；只有缺 binary 或源码更新时才同步跑 make。
local function stat_mtime(path)
	-- BSD stat: -f %m 输出 mtime epoch。文件不存在时输出空，tonumber 返回 nil。
	local f = io.popen("stat -f %m " .. shell_quote(path) .. " 2>/dev/null")
	if not f then
		return nil
	end
	local s = f:read("*l")
	f:close()
	return tonumber(s)
end

local function helper_specs(cfg)
	local h = cfg .. "/helpers"
	return {
		{
			target = h .. "/event_providers/cpu_load/bin/cpu_load",
			sources = {
				h .. "/event_providers/cpu_load/cpu_load.c",
				h .. "/event_providers/cpu_load/cpu.h",
				h .. "/event_providers/sketchybar.h",
				h .. "/event_providers/cpu_load/makefile",
			},
		},
		{
			target = h .. "/event_providers/aerospace_watch/bin/aerospace_watch",
			restart = true,
			sources = {
				h .. "/event_providers/aerospace_watch/aerospace_watch.swift",
				h .. "/event_providers/aerospace_watch/makefile",
			},
		},
		{
			target = h .. "/event_providers/docker_watch/bin/docker_watch",
			restart = true,
			sources = {
				h .. "/event_providers/docker_watch/docker_watch.swift",
				h .. "/event_providers/docker_watch/makefile",
			},
		},
		{
			target = h .. "/event_providers/input_method/bin/input_method_watch",
			restart = true,
			sources = {
				h .. "/event_providers/input_method/input_method_watch.swift",
				h .. "/event_providers/input_method/makefile",
			},
		},
		{
			target = h .. "/event_providers/media_watch/bin/media_watch",
			restart = true,
			sources = {
				h .. "/event_providers/media_watch/media_watch.swift",
				h .. "/event_providers/media_watch/makefile",
			},
		},
		{
			target = h .. "/event_providers/sys_watch/bin/sys_watch",
			sources = {
				h .. "/event_providers/sys_watch/sys_watch.swift",
				h .. "/event_providers/sys_watch/makefile",
			},
		},
		{
			target = h .. "/menus/bin/menus",
			sources = {
				h .. "/menus/menus.c",
				h .. "/menus/makefile",
			},
		},
		{
			target = h .. "/bar_height/bin/bar_height",
			sources = {
				h .. "/bar_height/main.swift",
				h .. "/bar_height/makefile",
			},
		},
		{
			target = h .. "/dock_width/bin/dock_width",
			sources = {
				h .. "/dock_width/main.swift",
				h .. "/dock_width/makefile",
			},
		},
	}
end

local function needs_make(specs)
	local tests = {}
	for _, spec in ipairs(specs) do
		local target = shell_quote(spec.target)
		table.insert(tests, "[ ! -e " .. target .. " ]")
		for _, source in ipairs(spec.sources) do
			table.insert(tests, "[ ! -e " .. shell_quote(source) .. " ]")
			table.insert(tests, "[ " .. shell_quote(source) .. " -nt " .. target .. " ]")
		end
	end

	local f = io.popen("if " .. table.concat(tests, " || ") .. "; then printf 1; else printf 0; fi")
	if not f then
		return true
	end
	local stale = f:read("*a") == "1"
	f:close()
	return stale
end

local function run_make(cfg, specs)
	local log_path = tmp_path("sketchybar_make.log")
	local before = {}
	for _, spec in ipairs(specs) do
		before[spec.target] = stat_mtime(spec.target)
	end

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

	-- 重建后任一 binary 的 mtime 变了 → 视为 changed（触发 event provider restart）。
	-- mtime 粒度到秒，几乎不存在"重建后 mtime 完全相同"的边界 case。
	local restart_needed = false
	for _, spec in ipairs(specs) do
		local after = stat_mtime(spec.target)
		if spec.restart and before[spec.target] ~= after then
			restart_needed = true
			break
		end
	end

	return tonumber(exit_code) or 1, log_path, restart_needed
end

local function restart_event_providers()
	os.execute(
		"launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.aerospace_watch >/dev/null 2>&1; "
			.. "launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.docker_watch >/dev/null 2>&1; "
			.. "launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.input_method_watch >/dev/null 2>&1; "
			.. "launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.media_watch >/dev/null 2>&1 &"
	)
end

local cfg = os.getenv("CONFIG_DIR")
if cfg then
	local specs = helper_specs(cfg)
	if needs_make(specs) then
		local exit_code, log_path, restart_needed = run_make(cfg, specs)
		if exit_code ~= 0 then
			io.stderr:write("sketchybar: helper compile failed (exit " .. exit_code .. "), see " .. log_path .. "\n")
		elseif restart_needed then
			restart_event_providers()
		end
	end
end
