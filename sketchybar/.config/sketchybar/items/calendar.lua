-- ========== 日期时间显示 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local cal = sbar.add("item", "calendar", {
	icon = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 8,
		padding_right = 2,
		color = colors.active.sep_opaque,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = 14,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.active.mauve,
	},
	popup = {
		align = "right",
		background = {
			color = colors.with_alpha(colors.active.bar_bg, 0.85),
			corner_radius = 12,
			border_width = 2,
			shadow = { drawing = false },
		},
		blur_radius = 30,
		height = 22,
	},
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 4,
})

local _popup_pinned = false
local _popup_hovering = false
local _exit_gen = 0

local function scheduleHide()
	if _popup_pinned then return end
	_exit_gen = _exit_gen + 1
	local gen = _exit_gen
	sbar.delay(0.2, function()
		if _exit_gen ~= gen then return end
		if _popup_hovering or _popup_pinned then return end
		cal:set({ popup = { drawing = false } })
	end)
end

cal:subscribe({ "forced", "routine", "system_woke" }, function()
	local t = os.date("*t")
	cal:set({
		icon = string.format("%d月%d日", t.month, t.day),
		label = " " .. os.date("%H:%M"),
	})
end)

-- ========== Popup：完整月历 ==========
-- 8 行：星期头 + 6 行日期 + 1 行统计（跳过 cal 的月份标题行）

local CAL_LINES = 8
local cal_items = {}
for i = 1, CAL_LINES do
	local item = sbar.add("item", "calendar.cal_" .. i, {
		position = "popup." .. cal.name,
		icon = { drawing = false },
		label = {
			string = "",
			font = {
				family = "Hack Nerd Font Mono",
				style = fonts.font.style_map["Bold"],
				size = 12.0,
			},
			color = colors.active.text,
			padding_left = 2,
			padding_right = 2,
		},
		background = { drawing = false },
	})
	item:subscribe("mouse.entered", function()
		_exit_gen = _exit_gen + 1
		_popup_hovering = true
	end)
	item:subscribe("mouse.exited", function()
		_popup_hovering = false
		scheduleHide()
	end)
	cal_items[i] = item
end

-- 计算字符串在等宽字体下的显示宽度（CJK 字符 = 2 列，ASCII = 1 列）
local function display_width(s)
	local w = 0
	for _, cp in utf8.codes(s) do
		if cp >= 0x2000 then w = w + 2 else w = w + 1 end
	end
	return w
end

local function updatePopupContent()
	local t = os.date("*t")
	local today = t.day
	local year, month = t.year, t.month

	local first_wday = os.date("*t", os.time({ year = year, month = month, day = 1 })).wday
	local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
	if leap then days_in_month[2] = 29 end
	local ndays = days_in_month[month]

	local lines = {}
	lines[1] = "Su Mo Tu We Th Fr Sa"

	local cells, col = {}, first_wday
	for d = 1, ndays do
		cells[#cells + 1] = (d == today)
			and string.format("[%2d]", d)
			or string.format(" %2d ", d)
		if col % 7 == 0 or d == ndays then
			local row = table.concat(cells)
			if #lines == 1 then
				row = string.rep("    ", first_wday - 1) .. row
			end
			lines[#lines + 1] = row:gsub("%s+$", "")
			cells, col = {}, 1
		else
			col = col + 1
		end
	end

	while #lines < 7 do
		lines[#lines + 1] = ""
	end

	local doy = today
	for i = 1, month - 1 do doy = doy + days_in_month[i] end
	local total = leap and 366 or 365
	local stat = string.format("第 %d / %d 天", doy, total)

	local max_w = 0
	for i = 1, 7 do
		if lines[i] and #lines[i] > max_w then max_w = #lines[i] end
	end
	local stat_w = display_width(stat)
	local pad = math.floor((max_w - stat_w) / 2)
	lines[8] = (pad > 0 and string.rep(" ", pad) or "") .. stat

	for i = 1, CAL_LINES do
		cal_items[i]:set({ label = lines[i] or "" })
	end
end

cal:subscribe("mouse.entered", function()
	_exit_gen = _exit_gen + 1
	updatePopupContent()
	cal:set({ popup = { drawing = true } })
end)

cal:subscribe("mouse.exited", function()
	scheduleHide()
end)

cal:subscribe("mouse.clicked", function()
	_popup_pinned = not _popup_pinned
	updatePopupContent()
	cal:set({ popup = { drawing = "toggle" } })
end)

cal:subscribe("mouse.exited.global", function()
	_exit_gen = _exit_gen + 1
	if not _popup_pinned then
		cal:set({ popup = { drawing = false } })
	end
end)
