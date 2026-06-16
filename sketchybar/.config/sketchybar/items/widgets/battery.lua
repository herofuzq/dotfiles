-- ========== 电池电量显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors

local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	update_freq = 180,
	padding_left = 2,
	padding_right = 4,
	icon = {
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
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
		padding_right = 8,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

local function update_battery()
	sbar.exec("pmset -g batt", function(batt_info)
		local icon = "!"
		local label = "?"
		local found, _, charge_str = batt_info:find("(%d+)%%")
		local charge_num

		if found then
			charge_num = tonumber(charge_str)
			label = string.format("%02d%%", charge_num)
		end

		local color = colors.active.green
		local ac_found = batt_info:find("AC Power")

		if ac_found then
			icon = icons.battery.charging
		else
			if found and charge_num > 80 then
				icon = icons.battery._100
			elseif found and charge_num > 60 then
				icon = icons.battery._75
			elseif found and charge_num > 40 then
				icon = icons.battery._50
			elseif found and charge_num > 20 then
				icon = icons.battery._25
				color = colors.active.peach
			else
				icon = icons.battery._0
				color = colors.active.red
			end
		end

		battery:set({
			icon = { string = icon, color = color },
			-- label 颜色始终使用 sep_opaque，不与 icon 联动（简约风格，避免视觉干扰）
			label = { string = label },
		})
	end)
end

battery:subscribe({ "routine", "power_source_change", "system_woke" }, update_battery)
battery:subscribe("theme_changed", update_battery)
