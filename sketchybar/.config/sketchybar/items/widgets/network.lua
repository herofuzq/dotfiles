local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

local wifi_icon = "󰖩"
local wifi_down_icon = ""
local wifi_up_icon = ""

	sbar.exec("killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0")

local network = sbar.add("item", "widgets.network", {
	position = "right",
	icon = {
		string = wifi_down_icon,
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = 10.0,
		},
		padding_left = 4,
		padding_right = 1,
	},
	label = {
		string = "  0B " .. wifi_up_icon .. "  0B",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = 10.0,
		},
		padding_left = 0,
		padding_right = 4,
	},
	background = {
		color = colors.tokyo_night.bg1,
		corner_radius = 0,
	},
})

local function fmt_speed(raw)
	if not raw then return "   0B" end
	local val, unit = raw:match("^%s*(%d+)%s*(%a+)$")
	if not val then return "   0B" end
	local num = tonumber(val) or 0
	if unit == "MBps" then
		return string.format("%4dM", num)
	elseif unit == "KBps" then
		return string.format("%4dK", num)
	else
		return string.format("%4dB", num)
	end
end

network:subscribe("network_update", function(env)
	network:set({
		label = {
			string = fmt_speed(env.download) .. " " .. wifi_up_icon .. " " .. fmt_speed(env.upload),
		},
	})
end)
