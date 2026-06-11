-- ========== 日期时间显示 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local cal = sbar.add("item", "calendar", {
	icon = {
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = fonts.font.size },
		padding_left = 8, padding_right = 2,
		color = colors.active.sep_opaque,
	},
	label = {
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = fonts.font.size },
		padding_left = 0, padding_right = 14,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg, corner_radius = 10, border_width = 2,
		border_color = colors.active.mauve,
	},
	popup = {
		align = "right",
		horizontal = "on",
		background = {
			color = colors.with_alpha(colors.active.bar_bg, 0.85),
			corner_radius = 12, border_width = 2,
			shadow = { drawing = false },
		},
		blur_radius = 30,
		height = 22,
	},
	position = "right",
	update_freq = 30,
	padding_left = 2, padding_right = 4,
})

local _popup_pinned, _popup_hovering, _exit_gen = false, false, 0

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
	cal:set({ icon = string.format("%d月%d日", t.month, t.day), label = " " .. os.date("%H:%M") })
end)

-- ========== Popup：完整月历 ==========
-- 水平布局 + y_offset 垂直堆叠，文字放 icon（monospace 字体）

local CAL_LINES = 8
local cal_items = {}

for i = 1, CAL_LINES do
	local y = 56 - 16 * (i - 1)
	local item = sbar.add("item", "calendar.cal_" .. i, {
		position = "popup." .. cal.name,
		width = 0,
		y_offset = y,
		icon = {
			string = "",
			font = { family = "Hack Nerd Font Mono", style = fonts.font.style_map["Bold"], size = 12.0 },
			color = colors.active.text,
			padding_left = 16, padding_right = 16,
		},
		label = { drawing = false },
		background = { drawing = false },
	})
	item:subscribe("mouse.entered", function() _exit_gen = _exit_gen + 1; _popup_hovering = true end)
	item:subscribe("mouse.exited", function() _popup_hovering = false; scheduleHide() end)
	cal_items[i] = item
end

local function display_width(s)
	local w = 0
	for _, cp in utf8.codes(s) do
		w = w + (cp >= 0x2000 and 2 or 1)
	end
	return w
end

local function updatePopupContent()
	local t = os.date("*t")
	local today, year, month = t.day, t.year, t.month

	local first_wday = os.date("*t", os.time({ year = year, month = month, day = 1 })).wday
	local dinm = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
	if leap then dinm[2] = 29 end
	local ndays = dinm[month]

	-- 星期头
	local wdays = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
	local header = {}
	for _, wd in ipairs(wdays) do header[#header + 1] = string.format(" %-2s ", wd) end
	local lines = { table.concat(header):gsub("%s+$", "") }

	-- 日期
	local cells, col = {}, first_wday
	for d = 1, ndays do
		cells[#cells + 1] = (d == today) and string.format("[%2d]", d) or string.format(" %2d ", d)
		if col % 7 == 0 or d == ndays then
			local row = table.concat(cells)
			if #lines == 1 then row = string.rep("    ", first_wday - 1) .. row end
			lines[#lines + 1] = row:gsub("%s+$", "")
			cells, col = {}, 1
		else
			col = col + 1
		end
	end
	while #lines < 7 do lines[#lines + 1] = "" end

	-- 第几天
	local doy = today
	for i = 1, month - 1 do doy = doy + dinm[i] end
	local total = leap and 366 or 365
	local stat = string.format("第 %d / %d 天", doy, total)

	local max_w = 0
	for i = 1, 7 do if lines[i] and #lines[i] > max_w then max_w = #lines[i] end end
	local pad = math.floor((max_w - display_width(stat)) / 2)
	lines[8] = (pad > 0 and string.rep(" ", pad) or "") .. stat

	for i = 1, CAL_LINES do
		cal_items[i]:set({ icon = lines[i] or "" })
	end
end

cal:subscribe("mouse.entered", function()
	_exit_gen = _exit_gen + 1
	updatePopupContent()
	cal:set({ popup = { drawing = true } })
end)

cal:subscribe("mouse.exited", function() scheduleHide() end)

cal:subscribe("mouse.clicked", function()
	_popup_pinned = not _popup_pinned
	updatePopupContent()
	cal:set({ popup = { drawing = "toggle" } })
end)

cal:subscribe("mouse.exited.global", function()
	_exit_gen = _exit_gen + 1
	if not _popup_pinned then cal:set({ popup = { drawing = false } }) end
end)
