-- ========== CPU 使用率显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

-- 启动 CPU 监控后台进程，每 2 秒通过事件推送 CPU 数据
sbar.exec("killall cpu_load 2>/dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local sys = sbar.add("item", "widgets.sys", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.cpu,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 0,
		color = colors.active.accent_opaque,
	},
	label = {
		string = "0%",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 2,
		padding_right = 8,
		align = "right",
		max_chars = 3,
		width = 30,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

sys:subscribe("cpu_update", function(env)
	local cpu_load = tonumber(env.total_load) or 0
	local cpu_str = string.format("%d%%", cpu_load > 99 and 99 or cpu_load)
	local cpu_color = cpu_load > 70 and colors.active.red
		or (cpu_load > 40 and colors.active.peach or colors.active.green)
	sys:set({
		icon = { color = cpu_color },
		label = { string = cpu_str, color = colors.active.sep_opaque },
	})
end)
