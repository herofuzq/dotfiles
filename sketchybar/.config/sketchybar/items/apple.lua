-- ========== Apple Logo 按钮（最左侧） ==========
-- icon 宽度 = Dock 可见宽度，随 Dock 内容/隐藏状态自适应
-- 如需调整边框粗细，改下面的 border_width 即可，icon padding 会自动重算
local sbar = require("sketchybar")
local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")

local border_width = 0 -- 无背景无边框
local icon_width = 15

local function compute_icon_pad()
	local dock_w, dock_hidden, dock_x = settings.detect_dock_width()
	if dock_hidden == 1 then
		return 15, 15
	else
		local pad = math.floor((dock_w - icon_width - 2 * border_width) / 2)
		return pad + 2, pad - 2
	end
end

local icon_pad_left, icon_pad_right = compute_icon_pad()

-- item 左 padding = 固定 5px 偏移
local dock_x = 5

local apple = sbar.add("item", "apple", {
	padding_left = dock_x,
	padding_right = 5,
	icon = {
		font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
		padding_left = icon_pad_left,
		padding_right = icon_pad_right,
		string = icons.apple,
		color = colors.active.green,
		y_offset = 0,
	},
	label = { drawing = false },
	background = { drawing = false },
})

apple:subscribe("mouse.clicked", function()
	sbar.animate("tanh", 0.15, function()
		apple:set({
			background = { shadow = { distance = 0 } },
			y_offset = -4,
		})
	end)
	sbar.delay(0.15, function()
		sbar.animate("tanh", 0.15, function()
			apple:set({
				background = { shadow = { distance = 4 } },
				y_offset = 2,
			})
		end)
	end)
	sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
end)

-- 显示器切换时重新检测 Dock 宽度，动态调整 icon padding
apple:subscribe("display_change", function()
	local pl, pr = compute_icon_pad()
	local _, _, dx = settings.detect_dock_width()
	apple:set({ padding_left = dx, icon = { padding_left = pl, padding_right = pr } })
end)
