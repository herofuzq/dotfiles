-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors

-- ========== ↑ 上传（上排，y_offset 偏下）==========
local up = sbar.add("item", "widgets.network_up", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	width = 0,
	icon = { drawing = false, padding_left = 4, padding_right = 0 },
	label = {
		string = "—",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 9.0 },
		padding_left = 0,
		padding_right = 0,
		width = 33,
		align = "right",
		color = colors.pill_fg,
		y_offset = 4,
	},
	background = { drawing = false },
})

-- ========== ↓ 下载（下排，y_offset 偏上）==========
local down = sbar.add("item", "widgets.network_down", {
	position = "right",
	update_freq = 3,
	padding_left = 2,
	padding_right = 2,
	width = 0,
	icon = {
		string = icons.wifi,
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 13.0 },
		drawing = true,
		padding_left = 4,
		padding_right = 0,
		color = colors.sapphire,
	},
	label = {
		string = "—",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 9.0 },
		padding_left = 0,
		padding_right = 0,
		width = 33,
		align = "right",
		color = colors.pill_fg,
		y_offset = -4,
	},
	background = { drawing = false },
})

-- bracket 容器：背景 + wifi 图标
sbar.add("bracket", "widgets.network", { "widgets.network_up", "widgets.network_down" }, {
	position = "right",
	update_freq = 3,
	icon = { drawing = false },
	padding_left = 4,
	padding_right = 0,
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
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

-- 自动检测 ifstat 二进制路径（Apple Silicon / Intel Homebrew）
local function find_ifstat()
	for _, p in ipairs({ "/opt/homebrew/bin/ifstat", "/usr/local/bin/ifstat" }) do
		local f = io.open(p, "r")
		if f then
			f:close()
			return p
		end
	end
	return "/opt/homebrew/bin/ifstat"
end

local IFSTAT = find_ifstat()

local function detect_network_interface()
	local f = io.popen("route get default 2>/dev/null | awk '/interface:/{print $2; exit}'")
	local iface = f and (f:read("*a") or ""):match("^%s*(.-)%s*$") or nil
	if f then
		f:close()
	end
	if iface and iface:match("^[%w%._-]+$") then
		return iface
	end
	return "en0"
end

local NET_IFACE = detect_network_interface()

down:subscribe("routine", function()
	sbar.exec('"' .. IFSTAT .. '" -i ' .. NET_IFACE .. " -b 0.1 1 2>/dev/null", function(raw)
		-- ifstat 输出 N 行 header + 1 行数据，取最后非空行避免依赖 header 行数
		local data = ""
		for line in (raw or ""):gmatch("[^\n]+") do
			if #line > 0 and not line:match("^%s*$") then
				data = line
			end
		end
		local down_raw, up_raw = data:match("%s*(%S+)%s+(%S+)")
		local dn = tonumber((down_raw or "0"):match("^(%d+)")) or 0
		local up_val = tonumber((up_raw or "0"):match("^(%d+)")) or 0

		up:set({ label = "↑" .. format_speed(up_raw) })
		down:set({ label = "↓" .. format_speed(down_raw) })
	end)
end)

-- ========== system bracket（clash_tun + network）==========
sbar.set("widgets.clash_tun", { background = { drawing = false }, padding_left = 1, padding_right = 0 })
sbar.set("widgets.network", { background = { drawing = false } })
sbar.add("bracket", "widgets.system", {
	"widgets.clash_tun",
	"widgets.network_up",
	"widgets.network_down",
}, {
	position = "right",
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
})

-- spacer：防止后续 media 水平 item 覆盖 network bracket
sbar.add("item", "widgets.media_spacer", {
	position = "right",
	width = 58,
	padding_left = 0,
	padding_right = 0,
	background = { drawing = false },
})
