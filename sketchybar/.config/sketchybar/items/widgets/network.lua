-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors

local MAX_DOWN = 110000
local MAX_UP = 45000

-- ========== ↑ 上传（上排，y_offset 偏下）==========
local up = sbar.add("item", "widgets.network_up", {
	position = "right",
	width = 0,
	icon = { drawing = false },
	label = {
		string = "—",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 7.0 },
		padding_left = 0,
		padding_right = 6,
		width = 40,
		align = "right",
		color = colors.active.sep_opaque,
		y_offset = 3,
	},
	background = { drawing = false },
})

-- ========== ↓ 下载（下排，y_offset 偏上）==========
local down = sbar.add("item", "widgets.network_down", {
	position = "right",
	width = 0,
	icon = {
		string = "",
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 13.0 },
		drawing = true,
		padding_left = 8,
		padding_right = 4,
		color = colors.active.sapphire,
	},
	label = {
		string = "—",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 7.0 },
		padding_left = 0,
		padding_right = 6,
		width = 40,
		align = "right",
		color = colors.active.sep_opaque,
		y_offset = -3,
	},
	background = { drawing = false },
})

-- bracket 容器：背景 + wifi 图标
local net = sbar.add("bracket", "widgets.network", { "widgets.network_up", "widgets.network_down" }, {
	position = "right",
	update_freq = 2,
	padding_left = 6,
	padding_right = 8,
	icon = { drawing = false },
	background = {
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_width = 2,
	},
})

local function format_speed(raw)
	local n = raw and tonumber((raw:match("^(%d+)"))) or 0
	if n > 999 then
		return string.format("%.1fM", n / 1000)
	else
		return string.format("%3dK", n)
	end
end

net:subscribe("routine", function()
	sbar.exec("/opt/homebrew/bin/ifstat -i en0 -b 0.1 1 2>/dev/null", function(raw)
		local lines = {}
		for line in (raw or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
		local data = lines[3] or ""
		local down_raw, up_raw = data:match("%s*(%S+)%s+(%S+)")
		local dn = tonumber((down_raw or "0"):match("^(%d+)")) or 0
		local up_val = tonumber((up_raw or "0"):match("^(%d+)")) or 0

		sbar.exec(string.format("sketchybar -m --push widgets.network %.4f",
			math.max(dn / MAX_DOWN, up_val / MAX_UP)))

		up:set({ label = "↑" .. format_speed(up_raw) })
		down:set({ label = "↓" .. format_speed(down_raw) })
	end)
end)
