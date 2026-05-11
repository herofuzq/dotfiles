local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")


local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 5,
	padding_left = 2,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = settings.padding.icon_label_item.icon.padding_right,
		color = colors.tokyo_night.bg3_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.label.padding_left,
		padding_right = settings.padding.icon_label_item.label.padding_right,
		color = colors.tokyo_night.bg3_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.overlay0,
		border_width = 2,
	},
})

local function update_display(tun_on)
	local color = tun_on and colors.green or colors.tokyo_night.peach
	clash_tun:set({
		icon = {
			string = icons.clash.tun,
			color = color,
		},
		label = {
			string = tun_on and "TUN" or "OFF",
			color = color,
		},
	})
end

local function check_status()
	sbar.exec(
		"curl -s --max-time 2 --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/configs 2>/dev/null | python3 -c \"import sys,json; print('on' if json.load(sys.stdin)['tun']['enable'] else 'off')\" 2>/dev/null || echo 'off'",
		function(status)
			update_display(status:match("on") ~= nil)
		end
	)
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

clash_tun:subscribe("mouse.clicked", function()
	sbar.exec("osascript -e 'tell application \"System Events\" to keystroke \"d\" using {command down, control down, option down}'")
end)
