-- ========== Helper 二进制编译管理 ==========
-- 启动时检查 helpers 下 Swift/C 源码是否比 bin/ 产物新，是则在 **CONFIG_DIR** 下 make。
--
-- 重要：产物必须写在 ~/.config/sketchybar/helpers/**/bin/（运行目录）。
-- 不要在 ~/dotfiles/... 树里 make——那会生成第二份 gitignored 的 bin/，
-- launchd 仍执行 $HOME/.config/.../bin/，等于没更新运行中的 daemon。
-- 详见 README「Pitfall — helper bin/」。

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
require("helpers.startup").hide()

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
			restart_label = "com.fuzhuoqun.aerospace_watch",
			sources = {
				h .. "/event_providers/aerospace_watch/aerospace_watch.swift",
				h .. "/event_providers/aerospace_watch/makefile",
			},
		},
		{
			target = h .. "/event_providers/docker_watch/bin/docker_watch",
			restart_label = "com.fuzhuoqun.docker_watch",
			sources = {
				h .. "/event_providers/docker_watch/docker_watch.swift",
				h .. "/event_providers/docker_watch/makefile",
			},
		},
		{
			target = h .. "/event_providers/input_method/bin/input_method_watch",
			restart_label = "com.fuzhuoqun.input_method_watch",
			sources = {
				h .. "/event_providers/input_method/input_method_watch.swift",
				h .. "/event_providers/input_method/makefile",
			},
		},
		{
			target = h .. "/event_providers/media_watch/bin/media_watch",
			restart_label = "com.fuzhuoqun.media_watch",
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

	-- 只收集「有 restart_label 且 mtime 真变了」的 agent，避免无关 watcher 被连带踢掉。
	local restart_labels = {}
	for _, spec in ipairs(specs) do
		local after = stat_mtime(spec.target)
		if spec.restart_label and before[spec.target] ~= after then
			restart_labels[#restart_labels + 1] = spec.restart_label
		end
	end

	return tonumber(exit_code) or 1, log_path, restart_labels
end

local function restart_event_providers(labels)
	if not labels or #labels == 0 then
		return
	end
	local parts = {}
	for _, label in ipairs(labels) do
		-- label 来自本文件常量，非用户输入
		parts[#parts + 1] = "launchctl kickstart -k gui/$(id -u)/" .. label .. " >/dev/null 2>&1"
	end
	os.execute(table.concat(parts, "; ") .. " &")
end

local cfg = os.getenv("CONFIG_DIR")
if cfg then
	local specs = helper_specs(cfg)
	if needs_make(specs) then
		local exit_code, log_path, restart_labels = run_make(cfg, specs)
		if exit_code ~= 0 then
			io.stderr:write("sketchybar: helper compile failed (exit " .. exit_code .. "), see " .. log_path .. "\n")
		else
			restart_event_providers(restart_labels)
		end
	end
end
