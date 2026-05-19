-- ========== 当前输入法显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local im_map = {
	["com.apple.keylayout.ABC"] = { label = "ABC", color = colors.active.blue },
	["im.rime.inputmethod.Squirrel.Hans"] = { label = "鼠须管", color = colors.active.mauve },
}

-- 输入法切换顺序（新增输入法时在此追加即可）
local im_order = {
	"com.apple.keylayout.ABC",
	"im.rime.inputmethod.Squirrel.Hans",
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
        border_width = 2,
    },
})

local function update_display(im_id)
	local im = im_map[im_id] or { label = im_id:match("[^.]+$") or "?", color = colors.active.bg3_opaque }
	input_method:set({
		icon = { string = icons.input_method.keyboard, color = im.color },
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
        -- 在 im_order 中查找当前输入法，切换到下一个（循环）
        local next_id
        for i, id in ipairs(im_order) do
            if id == current_id then
                next_id = im_order[i % #im_order + 1]
                break
            end
        end
        if not next_id then
            next_id = im_order[1]  -- 未匹配时回退到第一个
        end
        sbar.exec("macism " .. next_id)
    end)
end)
