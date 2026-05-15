-- ========== CPU 使用率显示 ==========
-- 由后台 C 程序 cpu_load 每 2 秒推送 cpu_update 事件
local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

-- 启动 CPU 监控后台进程，每 2 秒通过事件推送 CPU 数据
sbar.exec("killall cpu_load >/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local sys = sbar.add("item", "widgets.sys", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.cpu,
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 0,
		color = colors.tokyo_night.accent_opaque,
	},
	label = {
		string = "0%",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 2,
		padding_right = 8,
		align = "right",
		width = 36,         -- 固定宽度，防止数字跳动导致布局变化
		color = colors.tokyo_night.sep_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.active.item_gradient[7],
		border_width = 2,
	},
})

-- 响应后台进程推送的 cpu_update 事件
sys:subscribe("cpu_update", function(env)
	local cpu_load = tonumber(env.total_load) or 0
	local cpu_str = string.format("%d%%", cpu_load)
	-- 根据负载动态变色：>70% 红 / >40% 橙 / 正常 绿
	local cpu_color = cpu_load > 70 and colors.red or (cpu_load > 40 and colors.orange or colors.green)
	sys:set({
		icon = { color = cpu_color },
		label = { string = cpu_str, color = colors.tokyo_night.sep_opaque },
	})
end)
