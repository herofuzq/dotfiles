-- ========== Apple Logo 按钮（最左侧） ==========
-- icon 宽度 = Dock 可见宽度，随 Dock 内容/隐藏状态自适应
-- 如需调整边框粗细，改下面的 border_width 即可，icon padding 会自动重算
local sbar = require("sketchybar")
local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")

local border_width = 2      -- ← 边框粗细在这改，icon_padding 自动联动
local icon_width = 6        -- ← SF Symbol Apple logo 在 13pt 下的实际宽度

local dock_w, dock_hidden = settings.detect_dock_width()

local icon_pad
if dock_hidden == 1 then
	icon_pad = 15            -- Dock 隐藏时的固定 fallback
else
	-- icon_padding = (dock 实际宽度 - 图标宽度 - 两侧边框) / 2
	icon_pad = math.floor((dock_w - icon_width - 2 * border_width) / 2)
end

local apple = sbar.add("item", "apple", {
	padding_left = 5,
	padding_right = 5,
	icon = {
		padding_left = icon_pad,
		padding_right = icon_pad,
		string = icons.apple,
		color = colors.active.red,
	},
	label = { drawing = false },
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = border_width,
	},
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
