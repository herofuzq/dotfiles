-- ========== 网络速度显示（↓下载 / ↑上传，bracket 堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors

local MAX_DOWN = 110000
local MAX_UP = 45000

-- ========== ↑ 上传（上排，y_offset 偏下）==========
local up = sbar.add("item", "widgets.network_up", {
	position = "right",
	update_freq = 2,
	padding_left = 0,
	padding_right = 0,
	width = 0,
	icon = {
		string = icons.network_up,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = 9.0,
		},
		padding_left = 6,
		padding_right = 2,
		color = colors.active.sapphire,
	},
	label = {
		string = "—",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = 9.0,
		},
		padding_left = 0,
		padding_right = 6,
		color = colors.active.sep_opaque,
		y_offset = 5,
	},
	background = { drawing = false },
})

-- ========== ↓ 下载（下排，y_offset 偏上）==========
local down = sbar.add("item", "widgets.network_down", {
	position = "right",
	update_freq = 2,
	padding_left = 0,
	padding_right = 0,
	width = 0,
	icon = {
		string = icons.network_down,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = 9.0,
		},
		padding_left = 6,
		padding_right = 2,
		color = colors.active.sapphire,
	},
	label = {
		string = "—",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = 9.0,
		},
		padding_left = 0,
		padding_right = 6,
		color = colors.active.sep_opaque,
		y_offset = -4,
	},
	background = { drawing = false },
})

-- bracket 包住两个 item，共享一个背景
sbar.add("bracket", "widgets.network", { "widgets.network_up", "widgets.network_down" }, {
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

local function parse_and_update()
	sbar.exec("ifstat -i en0 -b 0.1 1 2>/dev/null | tail -n1", function(result)
		local down_raw, up_raw = (result or ""):match("^(%S+)%s+(%S+)")
		local dn = tonumber((down_raw or "0"):match("^(%d+)")) or 0
		local up_val = tonumber((up_raw or "0"):match("^(%d+)")) or 0

		-- push 图形条数据
		sbar.exec(string.format(
			"sketchybar -m --push widgets.network_down %.4f --push widgets.network_up %.4f",
			dn / MAX_DOWN,
			up_val / MAX_UP
		))

		-- 更新 label
		up:set({ label = format_speed(up_raw) })
		down:set({ label = format_speed(down_raw) })
	end)
end

up:subscribe("routine", parse_and_update)
parse_and_update()
