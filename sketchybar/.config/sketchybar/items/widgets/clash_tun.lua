-- ========== Clash TUN 代理状态 ==========
-- background 由 network.lua 统一管理（widgets.system bracket）。
-- 这里设置的 background 在 network.lua 加载后被 drawing=false 覆盖，
-- 仅作为 network.lua 尚未 require 时的 fallback 初始值。
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 30, -- 与其他外部轮询错峰
	padding_left = 0,
	padding_right = 2,
	icon = {
		font = appearance.font_icon_bold(),
		padding_left = 2,
		padding_right = 2,
		color = colors.surface1,
	},
	label = {
		font = appearance.font_label_bold(),
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.pill_fg,
	},
	background = appearance.pill_bg(),
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

local last_state

local function check_status()
	sbar.exec("$CONFIG_DIR/helpers/clash_status.sh", function(status)
		status = (status or ""):match("^%s*(.-)%s*$")
		if status == last_state then
			return
		end
		last_state = status
		update_display(status)
	end)
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()
