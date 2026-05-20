-- ========== 当前输入法显示 ==========
-- ABC 系统输入法 / fcitx5 中英状态
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local FCITX_REMOTE = "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"

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
        border_width = 2,
    },
})

local function update_display(im_id, fcitx_mode)
	if im_id == "com.apple.keylayout.ABC" then
		input_method:set({
			icon = { string = "⌨", color = colors.active.blue },
			label = { string = "ABC", color = colors.active.sep_opaque },
		})
	elseif im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
		if fcitx_mode == "2" then
			-- fcitx 中文模式
			input_method:set({
				icon = { string = "⌨", color = colors.active.mauve },
				label = { string = "中州韵(ZH)", color = colors.active.sep_opaque },
			})
		else
			-- fcitx 英文模式
			input_method:set({
				icon = { string = "⌨", color = colors.active.mauve },
				label = { string = "中州韵(EN)", color = colors.active.sep_opaque },
			})
		end
	else
		-- 未知输入法
		input_method:set({
			icon = { string = "⌨", color = colors.active.bg3_opaque },
			label = { string = im_id:match("[^.]+$") or "?", color = colors.active.sep_opaque },
		})
	end
end

local function check_status()
	sbar.exec("macism", function(im_id)
		im_id = im_id:match("^%s*(.-)%s*$")
		if im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
			sbar.exec("'" .. FCITX_REMOTE .. "'", function(mode)
				update_display(im_id, mode and mode:match("^%s*(.-)%s*$"))
			end)
		else
			update_display(im_id)
		end
	end)
end

input_method:subscribe("input_method_change", check_status)
input_method:subscribe("system_woke", check_status)
check_status()
