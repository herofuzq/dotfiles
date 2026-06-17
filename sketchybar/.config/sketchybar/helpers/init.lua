-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"

-- 仅在 helpers 二进制缺失时才编译，避免每次启动都重新 make
-- 使用 Lua io.open 检查文件，避免不必要的 shell fork
local function file_exists(path)
	local f = io.open(path, "r")
	if f then f:close(); return true end
	return false
end

local cfg = os.getenv("CONFIG_DIR")
if cfg and not (
	file_exists(cfg .. "/helpers/event_providers/cpu_load/bin/cpu_load")
	and file_exists(cfg .. "/helpers/event_providers/input_method/bin/input_method_watch")
	
	and file_exists(cfg .. "/helpers/menus/bin/menus")
	and file_exists(cfg .. "/helpers/bar_height/bin/bar_height")
	and file_exists(cfg .. "/helpers/dock_width/bin/dock_width")
	and file_exists(cfg .. "/helpers/event_providers/media_watch/bin/media_watch")
) then
	local log_path = "/tmp/sketchybar_make.log"
	local f = io.popen("cd \"" .. cfg .. "/helpers\" && make 2>&1 > " .. log_path .. "; echo $?")
	local exit_code = (f:read("*a") or ""):match("(%d+)") or "0"
	f:close()
	if tonumber(exit_code) ~= 0 then
		io.stderr:write("sketchybar: helper compile failed (exit " .. exit_code .. "), see " .. log_path .. "\n")
	end
end
