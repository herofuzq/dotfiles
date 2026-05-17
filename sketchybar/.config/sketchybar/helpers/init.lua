-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

-- 仅在 helpers 二进制缺失时才编译，避免每次启动都重新 make
os.execute("if [ ! -f helpers/event_providers/bin/cpu_load ] || [ ! -f helpers/menus/bin/menus ]; then (cd helpers && make); fi")
