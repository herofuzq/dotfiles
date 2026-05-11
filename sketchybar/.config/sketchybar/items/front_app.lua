local fonts = require("fonts")
local sbar = require("sketchybar")
local colors = require("appearance")

local front_app = sbar.add("item", "front_app", {
	display = "active",
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
		color = colors.colors.active.mauve,
	},
	background = {
		drawing = true,
		color = colors.colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.colors.active.lavender,
		border_width = 2,
		shadow = { drawing = false },
	},
})

-- 在右边新增一个符号 item（无边框）
-- local front_app_suffix = sbar.add("item", "front_app_suffix", {
--	display = "active",
--	position = "left",

-- 无边框/无背景
--	background = { drawing = false },

-- 不需要图标，只显示文字
--	icon = { drawing = false },

--	label = {
--		string = " @i3 ", -- 换成你想要的符号，比如 "􀆊" 等
--		font = {
--			family = fonts.font_gohu.text,
--			style = fonts.font_gohu.style_map["Regular"],
--			size = fonts.font_gohu.size,
--		},
--	},

--	padding_left = 0,
--	padding_right = 2, -- 控制这个符号后面的间距
--})

-- sbar.exec("sketchybar --move front_app after workspace.W̲orkflow")
-- sbar.exec("sketchybar --move front_app_suffix after front_app")

front_app:subscribe("front_app_switched", function(env)
	front_app:set({
		label = {
			string = "ミ " .. env.INFO .. " 彡",
		},
	})
end)

front_app:subscribe("mouse.clicked", function()
	sbar.exec("aerospace workspace next")
end)
