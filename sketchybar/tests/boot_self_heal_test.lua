local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local utils = require("helpers.utils")

assert(utils.parse_boot_epoch("{ sec = 1785589567, usec = 410328 } Sat Aug  1 21:06:07 2026") == 1785589567)
assert(utils.parse_boot_epoch("{ sec = 0, usec = 0 }") == 0)
assert(utils.parse_boot_epoch("") == nil)
assert(utils.parse_boot_epoch(nil) == nil)

print("boot_self_heal_test: ok")
