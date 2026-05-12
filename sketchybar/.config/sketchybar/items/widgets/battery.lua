-- ========== 电池电量显示 ==========
-- 图标根据电量区间变化（满/75/50/25/0），颜色：绿/橙/红
local icons = require("icons")
local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	update_freq = 180,          -- 每 3 分钟刷新一次（省电）
	padding_left = 2,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 8,
		padding_right = 2,
		color = colors.tokyo_night.sep_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = 8,
		color = colors.tokyo_night.sep_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.subtext0,
		border_width = 2,
	},
})

-- 定时刷新、电源状态变化、系统唤醒时更新电量
battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batt_info)    -- 执行系统命令获取电池信息
		local icon = "!"
		local label = "?"
		local found, _, charge = batt_info:find("(%d+)%%")  -- 匹配百分比数字

		if found then
			charge = tonumber(charge)
			label = string.format("%02d%%", charge)          -- 两位数格式化，如 05%
		end

		local color = colors.green
		local charging, _, _ = batt_info:find("AC Power")    -- 检测是否在充电

		if charging then
			icon = icons.battery.charging                     -- 充电图标
		else
			if found and charge > 80 then
				icon = icons.battery._100
			elseif found and charge > 60 then
				icon = icons.battery._75
			elseif found and charge > 40 then
				icon = icons.battery._50
			elseif found and charge > 20 then
				icon = icons.battery._25
				color = colors.orange                         -- 电量偏低，变橙色
			else
				icon = icons.battery._0
				color = colors.red                            -- 电量不足，变红色
			end
		end

		battery:set({
			icon = { string = icon, color = color },
			label = { string = label },
		})
	end)
end)
