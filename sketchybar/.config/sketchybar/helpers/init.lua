-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"

-- 立即加载 sketchybar 并把 bar 设为完全透明:
-- sketchybarrc 启动时(冷启动)到 init.lua 跑之间有一段 ~100ms 窗口,
-- bar 默认会用 internal default (红色边框纯黑) 显示。
-- 在 helpers init 阶段(最早的代码)就把它设成透明,缩短 default 状态窗口。
require("sketchybar").bar({
	color = 0x00000000,
	border_color = 0x00000000,
	border_width = 0,
})

local function shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- bin 位于实际 CONFIG_DIR，不由 stow 管理；这里直接调 make，让 Makefile
-- 自己判断 stale (mtime up-to-date 时 make noop，< 50ms)。新增 helper 只需：
--   1. 在顶层 helpers/makefile 加 $(MAKE) -C <dir>
--   2. 在 <dir>/makefile 里写编译规则
-- 不再需要在本文件维护 target/source 清单。
--
-- 历史方案：needs_make() 用 Lua 表手工枚举 7 个 helper 的 target + source，
-- 每次新增 helper 要同时改源码、makefile 和这个表。Codex review 后删除。
local function run_make(cfg)
	local log_path = "/tmp/sketchybar_make.log"

	local targets = {
		-- 新增 helper binary 时需要同步更新此列表。
		-- makefile 会处理编译，这里只负责比较 mtime 决定是否 restart service。
		cfg .. "/helpers/event_providers/cpu_load/bin/cpu_load",
		cfg .. "/helpers/event_providers/input_method/bin/input_method_watch",
		cfg .. "/helpers/event_providers/media_watch/bin/media_watch",
		cfg .. "/helpers/event_providers/sys_watch/bin/sys_watch",
		cfg .. "/helpers/menus/bin/menus",
		cfg .. "/helpers/bar_height/bin/bar_height",
		cfg .. "/helpers/dock_width/bin/dock_width",
	}
	local before = {}
	for _, t in ipairs(targets) do
		local f = io.open(t)
		if f then
			before[t] = f:seek("end")
			f:close()
		end
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

	local changed = false
	for _, t in ipairs(targets) do
		local f2 = io.open(t)
		if f2 then
			local after = f2:seek("end")
			f2:close()
			if (before[t] or 0) ~= after then
				changed = true
				break
			end
		elseif before[t] then
			changed = true
			break
		end
	end

	return tonumber(exit_code) or 1, log_path, changed
end

local function restart_event_providers()
	os.execute(
		"launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.input_method_watch >/dev/null 2>&1; "
			.. "launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.media_watch >/dev/null 2>&1 &"
	)
end

local cfg = os.getenv("CONFIG_DIR")
if cfg then
	local exit_code, log_path, changed = run_make(cfg)
	if exit_code ~= 0 then
		io.stderr:write("sketchybar: helper compile failed (exit " .. exit_code .. "), see " .. log_path .. "\n")
	elseif changed then
		restart_event_providers()
	end
end
