-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

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
	and file_exists(cfg .. "/helpers/menus/bin/menus")
) then
	os.execute("cd \"" .. cfg .. "/helpers\" && make")
end
