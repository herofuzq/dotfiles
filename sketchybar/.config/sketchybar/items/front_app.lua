-- ========== 当前前台应用名 ==========
-- 显示当前活跃窗口的应用名称，两侧用 "ミ...彡" 装饰
-- 点击可以切换到下一个工作区
local fonts = require("fonts")
local sbar = require("sketchybar")
local colors = require("appearance").colors

local front_app = sbar.add("item", "front_app", {
	display = "active", -- 仅在活跃显示器显示
	updates = true,
	position = "right",
	padding_right = 2,
	padding_left = 2,
	icon = { drawing = false },
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 8,
		padding_right = 8,
		align = "center",
		color = colors.active.sep_opaque,
	},
	background = {
		drawing = true,
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.active.item_gradient[1],
		border_width = 2,
		shadow = { drawing = false },
	},
})

-- 前台应用切换时更新名称
front_app:subscribe("front_app_switched", function(env)
	front_app:set({
		label = {
			string = "ミ" .. env.INFO .. "彡", -- 日文片假名装饰
		},
	})
end)

-- 点击切换到下一个工作区
front_app:subscribe("mouse.clicked", function()
	sbar.exec("aerospace workspace next")
end)
