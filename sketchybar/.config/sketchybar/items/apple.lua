-- ========== Apple Logo 按钮（最左侧） ==========
-- icon 宽度 = Dock 可见宽度，随 Dock 内容/隐藏状态自适应
-- 如需调整边框粗细，改下面的 border_width 即可，icon padding 会自动重算
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")
local enter_animation = require("helpers.enter_animation")

local border_width = 0 -- 无背景无边框
local icon_width = 15

local function compute_icon_pad(force)
	local dock_w, dock_hidden = settings.detect_dock_width(force)
	if dock_hidden == 1 then
		return 15, 15
	else
		local pad = math.floor((dock_w - icon_width - 2 * border_width - 4) / 2)
		return pad + 0, pad - 0
	end
end

local icon_pad_left, icon_pad_right = compute_icon_pad()

local dock_x = 5

local apple = sbar.add("item", "apple", {
	padding_left = dock_x,
	padding_right = 5,
	icon = {
		string = icons.apple,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = 18.0,
		},
		padding_left = icon_pad_left,
		padding_right = icon_pad_right,
		color = colors.green,
		y_offset = 1,
	},
	label = { drawing = false },
	background = { drawing = false },
})

apple:subscribe("mouse.clicked", function()
	-- 反馈类:@120Hz 下 8 帧 = 67ms,跟手
	sbar.animate("tanh", 8, function()
		apple:set({
			background = { shadow = { distance = 0 } },
			y_offset = -4,
		})
		apple:set({
			background = { shadow = { distance = 4 } },
			y_offset = 1,
		})
	end)
	sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
end)

-- 显示器切换时重新检测 Dock 宽度，动态调整 icon padding
apple:subscribe({ "display_change", "system_woke" }, function()
	local pl, pr = compute_icon_pad(true)
	apple:set({ icon = { padding_left = pl, padding_right = pr } })

	-- 同时重新检测 bar height: 内外屏切换时 notch / menubar 状态可能不同
	-- settings.detect_bar_height() 内部会清掉跨屏遗留的 stale cache
	local new_h = settings.detect_bar_height()
	if new_h and new_h ~= settings.height then
		sbar.bar({ height = new_h })
		-- 同步更新 sketchybar-toggle 的 trigger zone (menu_bar_height = bar_h + 5)
		settings.ensure_toggle(new_h)
		settings.height = new_h
	end
end)

enter_animation.register("apple")
