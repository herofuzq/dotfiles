-- ========== Clash TUN 代理状态 ==========
-- 自身不画 pill；背景由 network.lua 的 widgets.system bracket 统一提供。
-- 须在 widgets/init.lua 里先于 network 加载。
local sbar = require("sketchybar")
local icons = require("icons")
local appearance = require("appearance")
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("clash_tun.status")
local settings = require("settings")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 30, -- 与其他外部轮询错峰
	padding_left = 1,
	padding_right = 0,
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
	background = { drawing = false },
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
	startup.after_reveal("clash_tun.status", function()
		clash_tun:set({
			icon = { string = icons.clash.tun, color = color_for(state) },
			label = { string = label_for(state), color = colors.pill_fg },
		})
	end)
end

local last_state

local function check_status()
	sbar.exec("$CONFIG_DIR/helpers/clash_status.sh", function(status)
		status = (status or ""):match("^%s*(.-)%s*$")
		if status == last_state then
			initial_ready()
			return
		end
		last_state = status
		update_display(status)
		initial_ready()
	end)
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()
