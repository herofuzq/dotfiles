-- ========== Apple Logo 按钮（最左侧） ==========
-- icon 宽度 = Dock 可见宽度，随 Dock 内容/隐藏状态自适应
-- 如需调整边框粗细，改下面的 border_width 即可，icon padding 会自动重算
local sbar = require("sketchybar")
local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")

local border_width = 0 -- 无背景无边框
local icon_width = 18

local function compute_icon_pad()
	local dock_w, dock_hidden = settings.detect_dock_width()
	if dock_hidden == 1 then
		return 15 -- Dock 隐藏时的固定 fallback
	else
		-- icon_padding = (dock 实际宽度 - 图标宽度 - 两侧边框) / 2
		return math.floor((dock_w - icon_width - 2 * border_width) / 2)
	end
end

local icon_pad = compute_icon_pad()

local apple = sbar.add("item", "apple", {
	padding_left = 5,
	padding_right = 5,
	icon = {
		font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
		padding_left = icon_pad,
		padding_right = icon_pad,
		string = icons.apple,
		color = 0xffa6e3a1,
		y_offset = 2,
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
				y_offset = 0,
			})
		end)
	end)
	sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
end)

-- 显示器切换时重新检测 Dock 宽度，动态调整 icon padding
apple:subscribe("display_change", function()
	apple:set({ icon = { padding_left = compute_icon_pad(), padding_right = compute_icon_pad() } })
end)
