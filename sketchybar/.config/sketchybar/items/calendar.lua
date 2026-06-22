-- ========== 日期时间显示 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local enter_animation = require("helpers.enter_animation")
local colors = appearance.colors

local cal = sbar.add("item", "calendar", {
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 5,
	icon = {
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 13.0 },
		padding_left = 2,
		padding_right = 2,
		color = colors.pill_fg,
	},
	label = {
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 13.0 },
		padding_left = 0,
		padding_right = 14,
		color = colors.pill_fg,
	},
	background = {
		drawing = false,
	},
	popup = {
		align = "right",
		background = {
			color = appearance.with_alpha(colors.pill_bg, 0.85),
			corner_radius = 12,
			border_width = 2,
			border_color = colors.border,
			shadow = { drawing = false },
		},
		blur_radius = 30,
		height = 30,
	},
})

local popup_utils = require("helpers.popup_utils")
local popup_state = popup_utils.new_state()
local cal_popup

local function scheduleHide()
	popup_utils.schedule_hide(popup_state, function()
		cal_popup:hide(true)
	end)
end

cal_popup = popup_animation.new(cal, {
	background_color = function()
		return appearance.with_alpha(colors.pill_bg, 0.85)
	end,
})

-- ========== Popup：完整月历 ==========

local CAL_LINES = 9
local CAL_LABEL_WIDTH = 292
local CAL_GRID_PAD = 20
local CAL_GRID_WIDTH = CAL_LABEL_WIDTH - CAL_GRID_PAD * 2
local CAL_FONT = { family = "Menlo", style = "Bold", size = 15.0 }
local cal_items = {}

for i = 1, CAL_LINES do
	local item = sbar.add("item", "calendar.cal_" .. i, {
		position = "popup." .. cal.name,
		width = CAL_LABEL_WIDTH,
		icon = { drawing = false },
		label = {
			string = "",
			font = CAL_FONT,
			align = "center",
			color = colors.text,
			padding_left = 0,
			padding_right = 0,
			width = CAL_LABEL_WIDTH,
		},
		background = { drawing = false },
	})
	item:subscribe("mouse.entered", function()
		popup_state.exit_gen = popup_state.exit_gen + 1
		popup_state.hovering = true
	end)
	item:subscribe("mouse.exited", function()
		popup_state.hovering = false
		scheduleHide()
	end)
	cal_items[i] = item
end

local function updatePopupContent()
	local t = os.date("*t")
	local today, year, month = t.day, t.year, t.month

	local first_wday = os.date("*t", os.time({ year = year, month = month, day = 1 })).wday
	local dinm = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
	if leap then
		dinm[2] = 29
	end
	local ndays = dinm[month]

	local wdays = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
	local hdr = {}
	for _, wd in ipairs(wdays) do
		hdr[#hdr + 1] = string.format(" %-2s ", wd)
	end
	local lines = {
		{ string = string.format("%d年%d月", year, month), color = colors.mauve },
		{ string = table.concat(hdr):gsub("%s+$", ""), grid = true, color = colors.subtext1 },
	}

	local cells = {}
	for skip = 1, first_wday - 1 do
		cells[#cells + 1] = "    "
	end
	for d = 1, ndays do
		cells[#cells + 1] = (d == today) and string.format("[%2d]", d) or string.format(" %2d ", d)
		if #cells == 7 or d == ndays then
			while #cells < 7 do
				cells[#cells + 1] = "    "
			end
			lines[#lines + 1] = { string = table.concat(cells):gsub("%s+$", ""), grid = true, color = colors.text }
			cells = {}
		end
	end

	local doy = today
	for i = 1, month - 1 do
		doy = doy + dinm[i]
	end
	local total = leap and 366 or 365
	lines[#lines + 1] = { string = string.format("第 %d / %d 天", doy, total), color = colors.subtext1 }

	for i = 1, CAL_LINES do
		local line = lines[i]
		if line and line.string ~= "" then
			cal_items[i]:set({
				drawing = true,
				label = {
					string = line.string,
					align = line.grid and "left" or "center",
					color = line.color,
					padding_left = line.grid and CAL_GRID_PAD or 0,
					padding_right = line.grid and CAL_GRID_PAD or 0,
					width = line.grid and CAL_GRID_WIDTH or CAL_LABEL_WIDTH,
				},
			})
		else
			cal_items[i]:set({ drawing = false })
		end
	end
end

cal:subscribe(
	{ "forced", "routine", "system_woke", "mouse.entered", "mouse.exited", "mouse.clicked", "mouse.exited.global" },
	function(env)
		local s = env.SENDER
		if s == "forced" or s == "routine" or s == "system_woke" then
			local t = os.date("*t")
			cal:set({ icon = string.format("%d月%d日", t.month, t.day), label = string.format(" %02d:%02d", t.hour, t.min) })
		elseif s == "mouse.entered" then
			popup_state.exit_gen = popup_state.exit_gen + 1
			updatePopupContent()
			cal_popup:show()
		elseif s == "mouse.exited" then
			scheduleHide()
		elseif s == "mouse.clicked" then
			popup_state.pinned = not popup_state.pinned
			updatePopupContent()
			if popup_state.pinned then
				cal_popup:show()
			else
				cal_popup:hide(true)
			end
		elseif s == "mouse.exited.global" then
			popup_state.exit_gen = popup_state.exit_gen + 1
			if not popup_state.pinned then
				cal_popup:hide(true)
			end
		end
	end
)

enter_animation.register("calendar")
