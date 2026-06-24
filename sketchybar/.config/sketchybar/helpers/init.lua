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

local shell_quote = require("helpers.utils").shell_quote

-- bin 位于实际 CONFIG_DIR，不由 stow 管理；这里直接调 make，让 Makefile
-- 自己判断 stale (mtime up-to-date 时 make noop，< 50ms)。新增 helper 只需：
--   1. 在顶层 helpers/makefile 加 $(MAKE) -C <dir>
--   2. 在 <dir>/makefile 里写编译规则
-- 不再需要在本文件维护 target/source 清单。
--
-- 历史方案：needs_make() 用 Lua 表手工枚举 7 个 helper 的 target + source，
-- 每次新增 helper 要同时改源码、makefile 和这个表。Codex review 后删除。
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
		before[t] = stat_mtime(t)
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
	local changed = false
	for _, t in ipairs(targets) do
		local after = stat_mtime(t)
		if before[t] ~= after then
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
