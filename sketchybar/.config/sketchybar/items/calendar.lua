-- ========== 日期时间显示 ==========
-- 格式：X月X日 HH:MM（图标显示日期，标签显示时间）
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local cal = sbar.add("item", {
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 8,
		padding_right = 2,
		color = colors.active.sep_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = 17,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.active.item_gradient[8],
		border_width = 2,
	},
	position = "right",
	update_freq = 30, -- 每 30 秒刷新一次
	padding_left = 2,
	padding_right = 11,
})

-- 强制刷新、定时刷新、系统唤醒时更新日期时间
cal:subscribe({ "forced", "routine", "system_woke" }, function()
	local t = os.date("*t") -- 获取本地日期表
	cal:set({
		icon = string.format("%d月%d日", t.month, t.day),
		label = " " .. os.date("%H:%M"), -- 前面加一个空格，与日期间隔
	})
end)
