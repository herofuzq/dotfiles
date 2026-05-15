-- ========== 当前输入法显示 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local im_map = {
	["com.apple.keylayout.ABC"] = { label = "ABC", color = colors.blue },
	["com.tencent.inputmethod.wetype.pinyin"] = { label = "拼音", color = colors.green },
	["im.rime.inputmethod.Squirrel.Hans"] = { label = "鼠须管", color = colors.active.mauve },
}

local input_method = sbar.add("item", "widgets.input_method", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.active.deep_blue,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = settings.padding.icon_label_item.label.padding_right,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.active.item_gradient[2],
		border_width = 2,
	},
})

local function update_display(im_id)
	local im = im_map[im_id] or { label = im_id:match("[^.]+$") or "?", color = colors.active.bg3_opaque }
	input_method:set({
		icon = { string = "⌨", color = im.color },
		label = { string = im.label, color = colors.active.sep_opaque },
	})
end

local function check_status()
	sbar.exec("macism", function(im_id)
		update_display(im_id:match("^%s*(.-)%s*$"))
	end)
end

input_method:subscribe("input_method_change", check_status)
input_method:subscribe("system_woke", check_status)
check_status()

input_method:subscribe("mouse.clicked", function()
	sbar.exec("macism", function(current_id)
		current_id = current_id:match("^%s*(.-)%s*$")
		local next_id = (current_id == "com.apple.keylayout.ABC") and "im.rime.inputmethod.Squirrel.Hans"
			or "com.apple.keylayout.ABC"
		sbar.exec("macism " .. next_id)
	end)
end)
