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
		padding_right = 14, -- 右侧留白
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.active.mauve, -- 初始值，borders.distribute() 随后覆盖
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

local CAL_LINES = 9
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
				size = 15.0,
			},
			color = colors.active.text,
			padding_left = 10,
			padding_right = 10,
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

local function updatePopupContent()
	local t = os.date("*t")
	local today = t.day
	local f = io.popen("LC_ALL=en_US.UTF-8 cal")
	if not f then return end
	local lines = {}
	for line in f:lines() do
		lines[#lines + 1] = line:gsub("%s+$", "")
	end
	f:close()

	-- 居中标题行（日期行中找最大宽度，不含末行统计）
	local max_w = 0
	for i = 2, 8 do
		if lines[i] and #lines[i] > max_w then max_w = #lines[i] end
	end
	local pad = math.floor((max_w - #lines[1]) / 2)
	if pad > 0 then
		lines[1] = string.rep(" ", pad) .. lines[1]
	end

	-- 计算今年第几天
	local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local is_leap = (t.year % 4 == 0 and t.year % 100 ~= 0) or (t.year % 400 == 0)
	if is_leap then days_in_month[2] = 29 end
	local doy = today
	for i = 1, t.month - 1 do doy = doy + days_in_month[i] end
	local total = is_leap and 366 or 365
	lines[9] = string.format("第 %d / %d 天", doy, total)

	for i = 1, CAL_LINES do
		local text = lines[i] or ""
		if i >= 3 and i <= 8 then
			local ts = string.format("%2d", today)
			text = " " .. text .. " "
			text = text:gsub(" " .. ts .. " ", "[" .. today .. "]")
			text = text:sub(2, -2)
		end
		cal_items[i]:set({ label = text })
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
