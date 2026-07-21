-- ========== 电池电量显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local parsers = require("helpers.widget_parsers")
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("battery.status")
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
local popup_visible = false
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

battery:subscribe("mouse.clicked", function()
	popup_visible = not popup_visible
	local visible = popup_visible
	if not visible then
		battery_popup:hide()
	else
		popup_utils.defer(function()
			if not popup_visible then return end
			update_batt_info(last_state)
			batt_info:set({ drawing = true })
			battery_popup:show()
		end)
	end
end)

-- ========== 电池状态更新 ==========
local function update_battery_display(state)
	if not state then
		if last_battery_signature == false then
			return
		end
		last_battery_signature = false
		startup.after_reveal("battery.status", function()
			battery:set({
				icon = { string = icons.battery._0, color = colors.surface1 },
				label = { string = "—" },
			})
		end)
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

	startup.after_reveal("battery.status", function()
		battery:set({
			icon = { string = icon, color = color },
			label = { string = string.format("%02d%%", state.percent) },
		})
	end)
end

local function update_battery()
	sbar.exec("ioreg -rn AppleSmartBattery", function(raw)
		last_state = parsers.parse_battery(raw)
		update_battery_display(last_state)
		initial_ready()
		-- popup 内容由点击打开时直接刷新，这里只维护主条状态。
	end)
end

battery:subscribe({ "routine", "power_source_change", "system_woke" }, update_battery)
update_battery()
