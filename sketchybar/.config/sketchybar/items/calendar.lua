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
				size = 13.0,
			},
			color = colors.active.text,
			padding_left = 4,
			padding_right = 4,
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
	local f = io.popen("LC_ALL=en_US.UTF-8 cal")
	if not f then return end
	local raw = {}
	for line in f:lines() do
		raw[#raw + 1] = line:gsub("%s+$", "")
	end
	f:close()

	-- 跳过第 1 行（月份标题），取 2~8 行（星期 + 6 日期行）
	local lines = {}
	for i = 2, 8 do
		lines[#lines + 1] = raw[i] or ""
	end

	-- 高亮今天（日期行 2~7，即 raw 的 3~8）
	for i = 2, 7 do
		if lines[i] then
			local ts = string.format("%2d", today)
			local text = " " .. lines[i] .. " "
			text = text:gsub(" " .. ts .. " ", "[" .. today .. "]")
			lines[i] = text:sub(2, -2)
		end
	end

	-- 今年第几天（第 8 行）
	local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local leap = (t.year % 4 == 0 and t.year % 100 ~= 0) or (t.year % 400 == 0)
	if leap then days[2] = 29 end
	local doy = today
	for i = 1, t.month - 1 do doy = doy + days[i] end
	local total = leap and 366 or 365
	local stat = string.format("第 %d / %d 天", doy, total)

	-- 居中末行（基于 CJK 感知的显示宽度）
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
