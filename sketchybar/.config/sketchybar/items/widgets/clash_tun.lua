-- ========== Clash TUN 代理状态 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 30,
	padding_left = 4,
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

local function color_for(state)
	if state == "all" then
		return colors.active.mauve
	end
	if state == "tun" then
		return colors.active.green
	end
	if state == "sys" then
		return colors.active.sapphire
	end
	if state == "off" then
		return colors.active.red
	end
	return colors.active.bg3_opaque
end

local function label_for(state)
	if state == "all" then
		return "ALL"
	end
	if state == "tun" then
		return "TUN"
	end
	if state == "sys" then
		return "SYS"
	end
	if state == "off" then
		return "OFF"
	end
	return "—"
end

local function update_display(state)
	clash_tun:set({
		icon = { string = icons.clash.tun, color = color_for(state) },
		label = { string = label_for(state), color = colors.active.sep_opaque },
	})
end

local last_state = "off"

local function check_status()
	sbar.exec("$CONFIG_DIR/helpers/clash_status.sh", function(status)
		status = (status or ""):match("^%s*(.-)%s*$")
		last_state = status
		update_display(status)
	end)
end

local function refresh_colors()
	clash_tun:set({
		icon = { color = color_for(last_state) },
		label = { color = colors.active.sep_opaque },
	})
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

clash_tun:subscribe("theme_changed", refresh_colors)
