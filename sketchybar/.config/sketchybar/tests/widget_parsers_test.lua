package.path = "./?.lua;" .. package.path

local parsers = require("helpers.widget_parsers")

local function expect(actual, expected, name)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", name, tostring(expected), tostring(actual)))
	end
end

expect(parsers.parse_ioreg_integer(nil), nil, "missing integer")
expect(parsers.parse_ioreg_integer("42"), 42, "positive integer")
expect(parsers.parse_ioreg_integer("-9250"), -9250, "signed negative integer")
expect(parsers.parse_ioreg_integer("18446744073709542366"), -9250, "wrapped battery power")
expect(parsers.parse_ioreg_integer("18446744073709550858"), -758, "wrapped amperage")
expect(parsers.parse_ioreg_integer("18446744073709551615"), -1, "wrapped negative one")

expect(parsers.network_kind("Wi-Fi", "en0"), "wifi", "Wi-Fi")
expect(parsers.network_kind("AirPort", "en0"), "wifi", "legacy Wi-Fi")
expect(parsers.network_kind("iPhone USB", "en7"), "hotspot", "iPhone tethering")
expect(parsers.network_kind("Cellular", "en8"), "hotspot", "cellular tethering")
expect(parsers.network_kind("USB 10/100/1000 LAN", "en7"), "ethernet", "USB Ethernet")
expect(parsers.network_kind("Thunderbolt Bridge", "bridge0"), "ethernet", "bridge")
expect(parsers.network_kind(nil, "en0"), "wifi", "Wi-Fi fallback")
expect(parsers.network_kind(nil, "en7"), "ethernet", "Ethernet fallback")
expect(parsers.network_kind(nil, "utun3"), "unknown", "unknown interface")

print("widget parser tests: ok")
