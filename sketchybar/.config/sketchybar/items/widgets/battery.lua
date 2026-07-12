-- ========== 电池电量显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local parsers = require("helpers.widget_parsers")
local colors = appearance.colors
local BATTERY_UPDATE_INTERVAL = 37 -- 与其他外部轮询错峰

local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	update_freq = BATTERY_UPDATE_INTERVAL,
	padding_left = 4,
	padding_right = 2,
	icon = {
		font = appearance.font_icon_bold(),
		padding_left = 8,
		padding_right = 2,
		color = colors.pill_fg,
	},
	label = {
		font = appearance.font_label_bold(),
		padding_left = 0,
		padding_right = 8,
		color = colors.pill_fg,
	},
	background = appearance.pill_bg(),
	popup = {
		align = "center",
		background = appearance.popup_bg(),
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
		font = appearance.font_label_bold(13.0),
		color = colors.pill_fg,
		padding_left = 10,
		padding_right = 10,
	},
	background = { drawing = false },
})

local popup_utils = require("helpers.popup_utils")
local popup_state = popup_utils.new_state()
local last_state
local last_battery_signature
local battery_popup = popup_animation.new(battery, {
	background_color = function()
		return appearance.popup_bg().color
	end,
	on_hidden = function()
		batt_info:set({ drawing = false })
	end,
})

local function scheduleHide()
	popup_utils.schedule_hide(popup_state, function()
		battery_popup:hide_async()
	end)
end

local function parse_battery(raw)
	raw = raw or ""
	local cur_raw = raw:match('"CurrentCapacity"%s*=%s*(%d+)')
	local max_raw = raw:match('"MaxCapacity"%s*=%s*(%d+)')
	if not cur_raw or not max_raw then
		return nil
	end

	local function number_field(key)
		return parsers.parse_ioreg_integer(raw:match('"' .. key .. '"%s*=%s*(-?%d+)'))
	end

	local ext = raw:match('"ExternalConnected"%s*=%s*%w+') or ""
	local chg = raw:match('"IsCharging"%s*=%s*%w+') or ""
	local cur = tonumber(cur_raw) or 0
	local max_cap = tonumber(max_raw) or 1
	if max_cap <= 0 then
		return nil
	end

	local min_left = number_field("AvgTimeToEmpty")
	if min_left and min_left >= 65535 then
		min_left = nil
	end

	local system_power = number_field("SystemPowerIn")
	local battery_power = number_field("BatteryPower")
	local amperage = number_field("InstantAmperage") or number_field("Amperage")
	local voltage = number_field("Voltage") or number_field("AppleRawBatteryVoltage")
	local current_watts

	if system_power and system_power > 0 then
		current_watts = system_power / 1000
	elseif battery_power and battery_power ~= 0 then
		current_watts = math.abs(battery_power) / 1000
	elseif amperage and voltage and amperage ~= 0 and voltage > 0 then
		current_watts = math.abs(amperage * voltage) / 1000000
	end
	if current_watts and current_watts > 500 then
		current_watts = nil
	end

	return {
		ac = ext:find("Yes") ~= nil,
		charging = chg:find("Yes") ~= nil,
		current_watts = current_watts,
		min_left = min_left,
		percent = math.floor(cur * 100 / max_cap + 0.5),
	}
end

local function format_watts(watts)
	if not watts then
		return nil
	end
	if watts >= 10 then
		return string.format("%.0fW", watts)
	end
	return string.format("%.1fW", watts)
end

local function update_batt_info(state)
	if not state then
		batt_info:set({ label = "电池信息不可用" })
		return
	end

	local status = state.ac and "⚡ 电源" or "🔋 电池"
	local info = string.format("%s  %d%%", status, state.percent)
	local watts = format_watts(state.current_watts)
	if watts then
		info = info .. string.format("  当前 %s", watts)
	end
	if not state.ac and state.min_left then
		local h = math.floor(state.min_left / 60)
		local m = state.min_left % 60
		info = info .. string.format("  剩余 %d:%02d", h, m)
	end
	batt_info:set({ label = info })
end

battery:subscribe("mouse.entered", function()
	popup_state.exit_gen = popup_state.exit_gen + 1
	update_batt_info(last_state)
	batt_info:set({ drawing = true })
	battery_popup:show()
end)

battery:subscribe("mouse.exited", function()
	scheduleHide()
end)

battery:subscribe("mouse.clicked", function()
	if popup_state.pinned then
		popup_state.pinned = false
		battery_popup:hide_async()
	else
		popup_state.pinned = true
		update_batt_info(last_state)
		batt_info:set({ drawing = true })
		battery_popup:show()
	end
end)

popup_utils.bind_popup_hover({ batt_info }, popup_state, scheduleHide)

-- ========== 电池状态更新 ==========
local function update_battery_display(state)
	if not state then
		if last_battery_signature == false then
			return
		end
		last_battery_signature = false
		battery:set({
			icon = { string = icons.battery._0, color = colors.surface1 },
			label = { string = "—" },
		})
		return
	end

	-- dedup: percent/charging/ac 跟上次一样就不 set
	local signature = string.format("%d|%s|%s", state.percent, tostring(state.charging), tostring(state.ac))
	if signature == last_battery_signature then
		return
	end
	last_battery_signature = signature

	local color = colors.green
	local icon
	if state.ac or state.charging then
		icon = icons.battery.charging
	else
		if state.percent > 80 then
			icon = icons.battery._100
		elseif state.percent > 60 then
			icon = icons.battery._75
		elseif state.percent > 40 then
			icon = icons.battery._50
		elseif state.percent > 20 then
			icon = icons.battery._25
			color = colors.peach
		else
			icon = icons.battery._0
			color = colors.red
		end
	end

	battery:set({
		icon = { string = icon, color = color },
		label = { string = string.format("%02d%%", state.percent) },
	})
end

local function update_battery()
	sbar.exec("ioreg -rn AppleSmartBattery", function(raw)
		last_state = parse_battery(raw)
		update_battery_display(last_state)
		-- popup 内容由 mouse.entered / mouse.clicked 直接触发 update_batt_info,
		-- 这里不必再判断 popup 可见性 (旧代码引用了从未定义的 _popup_visible)。
	end)
end

battery:subscribe({ "routine", "power_source_change", "system_woke" }, update_battery)
update_battery()

