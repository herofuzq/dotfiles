local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local utils = require("helpers.utils")

assert(utils.parse_boot_epoch("{ sec = 1785589567, usec = 410328 } Sat Aug  1 21:06:07 2026") == 1785589567)
assert(utils.parse_boot_epoch("{ sec = 0, usec = 0 }") == 0)
assert(utils.parse_boot_epoch("") == nil)
assert(utils.parse_boot_epoch(nil) == nil)

-- 排程门槛不得依赖「开机后 120s 内」：风暴只发生在登录后，与开机时间无关，
-- 用户开机后很久才登录时必须仍能自愈。排程的唯一闸门是 per-boot marker。
do
	local f = assert(io.open("sketchybar/.config/sketchybar/init.lua", "r"))
	local src = f:read("*a")
	f:close()
	assert(src:find("if boot_epoch then", 1, true), "boot self-heal must gate on boot_epoch alone")
	assert(not src:find("boot_epoch) < 120", 1, true), "boot self-heal must not require login within 120s of boot")
	assert(src:find("sketchybar_boot_selfheal.", 1, true), "boot self-heal must keep a per-boot marker")
end

print("boot_self_heal_test: ok")
