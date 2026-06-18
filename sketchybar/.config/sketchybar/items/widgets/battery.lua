-- ========== 电池电量显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors

local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	update_freq = 180,
	padding_left = 4,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = 8,
		padding_right = 2,
		color = colors.pill_fg,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = 8,
		color = colors.pill_fg,
	},
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
	popup = {
		align = "center",
		background = {
			color = require("appearance").with_alpha(colors.pill_bg, 0.85),
			corner_radius = 12,
			border_width = 2,
			border_color = colors.border,
			shadow = { drawing = false },
		},
		blur_radius = 30,
		height = 30,
	},
})

-- ========== 电池信息 popup 子项 ==========
local batt_info = sbar.add("item", "widgets.battery.info", {
	position = "popup.widgets.battery",
	drawing = false,
	icon = { drawing = false },
	label = {
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 13.0 },
		color = colors.pill_fg,
		padding_left = 10,
		padding_right = 10,
	},
	background = { drawing = false },
})

local _popup_pinned, _popup_hovering, _exit_gen = false, false, 0

local function scheduleHide()
	if _popup_pinned then return end
	_exit_gen = _exit_gen + 1
	local gen = _exit_gen
	sbar.delay(0.2, function()
		if _exit_gen ~= gen then return end
		if _popup_hovering or _popup_pinned then return end
		batt_info:set({ drawing = false })
		battery:set({ popup = { drawing = false } })
	end)
end

	local function updateBattInfo()
	sbar.exec("ioreg -rn AppleSmartBattery", function(raw)
		local ext = raw and raw:match('"ExternalConnected"%s*=%s*%w+') or ""
		local ac = ext:find("Yes") ~= nil
		local cur_raw = (raw or ""):match('"CurrentCapacity"%s*=%s*(%d+)')
		local max_raw = (raw or ""):match('"MaxCapacity"%s*=%s*(%d+)')
		if not cur_raw or not max_raw then
			batt_info:set({ label = "电池信息不可用" })
			return
		end
		local cur = tonumber(cur_raw) or 0
		local max_cap = tonumber(max_raw) or 1
		local min_left = tonumber((raw or ""):match('"AvgTimeToEmpty"%s*=%s*(%d+)'))
		local pct = math.floor(cur * 100 / max_cap + 0.5)
		local status = ac and "⚡ 电源" or "🔋 电池"
		local info = string.format("%s  %d%%", status, pct)
		if not ac and min_left then
			local h = math.floor(min_left / 60)
			local m = min_left % 60
			info = info .. string.format("  剩余 %d:%02d", h, m)
		end
		batt_info:set({ label = info })
	end)
end

battery:subscribe("mouse.entered", function()
	_exit_gen = _exit_gen + 1
	updateBattInfo()
	batt_info:set({ drawing = true })
	battery:set({ popup = { drawing = true } })
end)

battery:subscribe("mouse.exited", function()
	scheduleHide()
end)

battery:subscribe("mouse.clicked", function()
	_popup_pinned = not _popup_pinned
	updateBattInfo()
	battery:set({ popup = { drawing = "toggle" } })
end)

batt_info:subscribe("mouse.entered", function()
	_exit_gen = _exit_gen + 1
	_popup_hovering = true
end)
batt_info:subscribe("mouse.exited", function()
	_popup_hovering = false
	scheduleHide()
end)

-- ========== 电池状态更新 ==========
	local function update_battery()
	sbar.exec("ioreg -rn AppleSmartBattery", function(raw)
		local cur_raw = (raw or ""):match('"CurrentCapacity"%s*=%s*(%d+)')
		local max_raw = (raw or ""):match('"MaxCapacity"%s*=%s*(%d+)')
		if not cur_raw or not max_raw then
			battery:set({
				icon = { string = icons.battery._0, color = colors.surface1 },
				label = { string = "—" },
			})
			return
		end
		local cur = tonumber(cur_raw) or 0
		local max_cap = tonumber(max_raw) or 1
		local ext = raw and raw:match('"ExternalConnected"%s*=%s*%w+') or ""
		local chg = raw and raw:match('"IsCharging"%s*=%s*%w+') or ""
		local ac = ext:find("Yes") ~= nil
		local charging = chg:find("Yes") ~= nil
		local charge_num = math.floor(cur * 100 / max_cap + 0.5)
		local label = string.format("%02d%%", charge_num)

		local color = colors.green
		local icon
		if ac or charging then
			icon = icons.battery.charging
		else
			if charge_num > 80 then
				icon = icons.battery._100
			elseif charge_num > 60 then
				icon = icons.battery._75
			elseif charge_num > 40 then
				icon = icons.battery._50
			elseif charge_num > 20 then
				icon = icons.battery._25
				color = colors.peach
			else
				icon = icons.battery._0
				color = colors.red
			end
		end

		battery:set({
			icon = { string = icon, color = color },
			label = { string = label },
		})
	end)
end

battery:subscribe({ "routine", "power_source_change", "system_woke" }, update_battery)
battery:subscribe("theme_changed", update_battery)
update_battery()
