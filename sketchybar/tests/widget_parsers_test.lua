local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local parsers = require("helpers.widget_parsers")

assert(parsers.parse_ioreg_integer("18446744073709531616") == -20000, "wrapped uint64 should decode as signed")
assert(parsers.network_kind("Wi-Fi", "en0") == "wifi", "Wi-Fi port should be recognized")

local charging = parsers.parse_battery([[
  "CurrentCapacity" = 50
  "MaxCapacity" = 100
  "ExternalConnected" = Yes
  "IsCharging" = Yes
  "SystemPowerIn" = 42000
  "AvgTimeToEmpty" = 100
]])
assert(charging and charging.percent == 50, "battery percentage should be derived from capacities")
assert(charging.ac and charging.charging, "power and charging flags should be parsed")
assert(charging.current_watts == 42, "system input power should be converted from mW to W")
assert(charging.min_left == 100, "valid time remaining should be preserved")

local discharging = parsers.parse_battery([[
  "CurrentCapacity" = 75
  "MaxCapacity" = 100
  "ExternalConnected" = No
  "IsCharging" = No
  "BatteryPower" = -25000
  "AvgTimeToEmpty" = 65535
]])
assert(discharging and not discharging.ac and not discharging.charging, "discharging flags should be parsed")
assert(discharging.current_watts == 25, "battery power magnitude should be converted to W")
assert(discharging.min_left == nil, "sentinel time remaining should be discarded")

assert(parsers.parse_battery('"CurrentCapacity" = 50') == nil, "missing max capacity should be rejected")
assert(parsers.parse_battery('"CurrentCapacity" = 50\n"MaxCapacity" = 0') == nil, "zero max capacity should be rejected")

print("widget_parsers_test: ok")
