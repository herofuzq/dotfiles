local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local dingtalk = sbar.add("item", "widgets.dingtalk", {
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = ":dingtalk:",
		font = "sketchybar-app-font:Regular:14.0",
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.tokyo_night.blue,
	},
	label = {
		string = "0",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = settings.padding.icon_label_item.label.padding_right,
		color = colors.tokyo_night.sep_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.overlay1,
		border_width = 2,
	},
})

local function update_display(count)
	local label = count:match("^%s*(.-)%s*$") or ""
	if label == "" or not tonumber(label) then
		label = "0"
	end
	local num = tonumber(label)
	dingtalk:set({
		icon = { color = num > 0 and colors.peach or colors.tokyo_night.blue },
		label = { string = label, color = num > 0 and colors.peach or colors.tokyo_night.sep_opaque },
	})
end

local function check_status()
	sbar.exec("lsappinfo -all info -only StatusLabel com.alibaba.DingTalkMac | sed -n 's/.*\"label\"=\"\\([^\"]*\\)\".*/\\1/p'", update_display)
end

dingtalk:subscribe({ "routine", "system_woke" }, check_status)
check_status()
