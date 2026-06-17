-- ========== Clash TUN 代理状态 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 30,
	padding_left = 0,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = 2,
		padding_right = 2,
		color = colors.surface1,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.pill_fg,
	},
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
})

local function color_for(state)
	if state == "all" then
		return colors.mauve
	end
	if state == "tun" then
		return colors.green
	end
	if state == "sys" then
		return colors.sapphire
	end
	if state == "off" then
		return colors.red
	end
	return colors.surface1
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
		label = { string = label_for(state), color = colors.pill_fg },
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
		label = { color = colors.pill_fg },
	})
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

clash_tun:subscribe("theme_changed", refresh_colors)
