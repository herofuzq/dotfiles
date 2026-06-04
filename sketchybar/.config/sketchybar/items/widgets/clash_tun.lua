-- ========== Clash TUN 代理状态 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

	local clash_tun = sbar.add("item", "widgets.clash_tun", {
		position = "right",
		update_freq = 30,
		padding_left = 2,
		padding_right = 2,
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.active.bg3_opaque,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

local function update_display(tun_on)
	local icon_color = tun_on and colors.active.green or colors.active.red
	clash_tun:set({
		icon = { string = icons.clash.tun, color = icon_color },
		label = { string = tun_on and "TUN" or "OFF", color = colors.active.sep_opaque },
	})
end

local last_tun_on = false

local function check_status()
	sbar.exec("$CONFIG_DIR/helpers/clash_status.sh", function(status)
		last_tun_on = (status or ""):match("on") ~= nil
		update_display(last_tun_on)
	end)
end

local function refresh_colors()
	clash_tun:set({
		icon = { color = last_tun_on and colors.active.green or colors.active.red },
		label = { color = colors.active.sep_opaque },
	})
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

clash_tun:subscribe("theme_changed", refresh_colors)

