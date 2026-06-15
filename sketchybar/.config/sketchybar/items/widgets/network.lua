-- ========== 网络速度显示（↓下载 / ↑上传）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

local MAX_DOWN = 110000
local MAX_UP = 45000

local network = sbar.add("item", "widgets.network", {
	position = "right",
	update_freq = 2,
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.network_down,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.active.sapphire,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.active.sep_opaque,
	},
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

local function format_speed(raw)
	if not raw then
		return "—"
	end
	local n = tonumber((raw:match("^(%d+)")))
	if not n or n == 0 then
		return "—"
	end
	if n > 999 then
		return string.format("%.1fM", n / 1000)
	else
		return tostring(n) .. "K"
	end
end

network:subscribe("routine", function()
	sbar.exec("ifstat -i en0 -b 0.1 1 2>/dev/null | tail -n1", function(result)
		local down_raw, up_raw = (result or ""):match("^(%S+)%s+(%S+)")
		local dn = tonumber((down_raw or "0"):match("^(%d+)")) or 0
		local up_val = tonumber((up_raw or "0"):match("^(%d+)")) or 0

		-- push 图形条数据
		sbar.exec(string.format(
			"sketchybar -m --push widgets.network %.4f",
			math.max(dn / MAX_DOWN, up_val / MAX_UP)
		))

		network:set({
			label = string.format("↓%s ↑%s", format_speed(down_raw), format_speed(up_raw)),
		})
	end)
end)
