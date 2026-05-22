-- ========== 日期时间显示 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local cal = sbar.add("item", "calendar", {
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
		padding_right = 17, -- 右侧留白，使日历 item 与右侧 bar 边缘保持间距
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
	shadow = "on",
	popup = {
		align = "center",
		background = {
			color = colors.with_alpha(colors.active.bar_bg, 0.85),
			corner_radius = 12,
			border_width = 0,
			shadow = { drawing = false },
		},
		blur_radius = 30,
	},
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 11,
})

cal:subscribe({ "forced", "routine", "system_woke" }, function()
	local t = os.date("*t")
	cal:set({
		icon = string.format("%d月%d日", t.month, t.day),
		label = " " .. os.date("%H:%M"),
	})
end)

-- ========== Popup：今年第几天 ==========

-- 闰年判断
local function is_leap(year)
	return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

sbar.add("item", "calendar.doy", {
	position = "popup." .. cal.name,
	icon = { drawing = false },
	label = {
		string = "",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = 14.0,
		},
		color = colors.active.text,
		padding_left = 12,
		padding_right = 12,
	},
	background = { drawing = false },
})

sbar.add("item", "calendar.remaining", {
	position = "popup." .. cal.name,
	icon = { drawing = false },
	label = {
		string = "",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = 12.0,
		},
		color = colors.active.subtext0,
		padding_left = 12,
		padding_right = 12,
	},
	background = { drawing = false },
})

cal:subscribe("mouse.clicked", function()
	local t = os.date("*t")
	local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if is_leap(t.year) then
		days_in_month[2] = 29
	end

	local doy = t.day
	for i = 1, t.month - 1 do
		doy = doy + days_in_month[i]
	end

	local total = is_leap(t.year) and 366 or 365
	local remaining = total - doy

	sbar.set("calendar.doy", { label = string.format("今年第 %d 天", doy) })
	sbar.set("calendar.remaining", { label = string.format("共 %d 天 · 剩余 %d 天", total, remaining) })
	cal:set({ popup = { drawing = "toggle" } })
end)

cal:subscribe("mouse.exited.global", function()
	cal:set({ popup = { drawing = false } })
end)
