-- ========== 日期时间显示 ==========
local sbar = require("sketchybar")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local colors = appearance.colors

local cal = sbar.add("item", "calendar", {
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 5,
	icon = {
		font = appearance.font_label_bold(13.0),
		padding_left = 2,
		padding_right = 2,
		color = colors.pill_fg,
	},
	label = {
		font = appearance.font_label_bold(13.0),
		padding_left = 0,
		padding_right = 14,
		color = colors.pill_fg,
	},
	background = {
		drawing = false,
	},
	popup = {
		align = "right",
		background = appearance.popup_bg(),
		blur_radius = 30,
		height = 30,
	},
})

local popup_utils = require("helpers.popup_utils")
local popup_visible = false
local cal_popup

cal_popup = popup_animation.new(cal, {
	background_color = function()
		return appearance.popup_bg().color
	end,
})

-- ========== Popup：完整月历 ==========

local CAL_LINES = 9
local CAL_LABEL_WIDTH = 292
local CAL_GRID_PAD = 20
local CAL_GRID_WIDTH = CAL_LABEL_WIDTH - CAL_GRID_PAD * 2
local CAL_FONT = { family = "Menlo", style = "Bold", size = 15.0 }
local cal_items = {}
local cal_line_kinds = {} -- 每行的颜色角色（month/hdr/grid/doy），主题切换时按角色重涂

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
		{ string = string.format("%d年%d月", year, month), color = colors.identity.calendar_month, kind = "month" },
		{ string = table.concat(hdr):gsub("%s+$", ""), grid = true, color = colors.subtext1, kind = "hdr" },
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
			lines[#lines + 1] = { string = table.concat(cells):gsub("%s+$", ""), grid = true, color = colors.text, kind = "grid" }
			cells = {}
		end
	end

	local doy = today
	for i = 1, month - 1 do
		doy = doy + dinm[i]
	end
	local total = leap and 366 or 365
	lines[#lines + 1] = { string = string.format("第 %d / %d 天", doy, total), color = colors.subtext1, kind = "doy" }

	for i = 1, CAL_LINES do
		local line = lines[i]
		if line and line.string ~= "" then
			cal_line_kinds[i] = line.kind
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
			cal_line_kinds[i] = nil
			cal_items[i]:set({ drawing = false })
		end
	end
end

cal:subscribe(
	{ "forced", "routine", "system_woke", "mouse.clicked" },
	function(env)
		local s = env.SENDER
		if s == "forced" or s == "routine" or s == "system_woke" then
			local t = os.date("*t")
			popup_utils.defer(function()
				cal:set({ icon = string.format("%d月%d日", t.month, t.day), label = string.format(" %02d:%02d", t.hour, t.min) })
			end)
		elseif s == "mouse.clicked" then
			popup_visible = not popup_visible
			local visible = popup_visible
			popup_utils.defer(function()
				if popup_visible ~= visible then return end
				if visible then
					updatePopupContent()
					cal_popup:show()
				else
					cal_popup:hide()
				end
			end)
		end
	end
)

-- 显示器拓扑变化渐入前统一关闭 popup（popup 不参与 alpha 遮罩）
cal:subscribe("display_transition_begin", function()
	if popup_visible then
		popup_visible = false
		cal_popup:hide()
	end
end)

-- ========== 主题热换色：按缓存的行角色重涂 ==========
local function apply_colors(C)
	local popup_bg = appearance.popup_bg()
	cal:set({
		icon = { color = C.pill_fg },
		label = { color = C.pill_fg },
		popup = { background = { color = popup_bg.color, border_color = popup_bg.border_color } },
	})
	-- 未生成过月历内容时 cal_line_kinds 为空，此循环为 no-op
	for i = 1, CAL_LINES do
		local kind = cal_line_kinds[i]
		if kind then
			local line_color = kind == "month" and C.identity.calendar_month
				or (kind == "grid" and C.text or C.subtext1)
			cal_items[i]:set({ label = { color = line_color } })
		end
	end
end
apply_colors(colors)
appearance.register_colors("calendar", apply_colors)
