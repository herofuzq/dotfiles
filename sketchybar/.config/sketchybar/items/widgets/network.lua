-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local parsers = require("helpers.widget_parsers")
local enter_animation = require("helpers.enter_animation")
local find_binary = require("helpers.find_binary").find
local colors = require("appearance").colors
local NETWORK_SAMPLE_INTERVAL = 3
local INTERFACE_REFRESH_INTERVAL = 61
local MAX_CONSECUTIVE_FAILURES = 2

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
	update_freq = NETWORK_SAMPLE_INTERVAL,
	padding_left = 2,
	padding_right = 2,
	width = 0,
	icon = {
		string = icons.network.offline,
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
local IFSTAT = find_binary({ "/opt/homebrew/bin/ifstat", "/usr/local/bin/ifstat" })

local function detect_network(callback)
	local command = table.concat({
		"route get default 2>/dev/null",
		"printf '\\n---SERVICES---\\n'",
		"networksetup -listnetworkserviceorder 2>/dev/null",
		"printf '\\n---NWI---\\n'",
		"scutil --nwi 2>/dev/null",
	}, "; ")
	sbar.exec(command, function(output)
		output = output or ""
		local route_output, services_output, nwi_output = output:match("^(.-)\n%-%-%-SERVICES%-%-%-\n(.-)\n%-%-%-NWI%-%-%-\n(.*)$")
		route_output, services_output, nwi_output = route_output or "", services_output or "", nwi_output or ""
		local iface = route_output:match("interface:%s*([%w%._-]+)")
		if iface and iface:match("^utun%d+$") then
			local interfaces = nwi_output:match("Network interfaces:%s*([^\n]+)") or ""
			for candidate in interfaces:gmatch("[%w%._-]+") do
				if not candidate:match("^utun%d+$") then
					iface = candidate
					break
				end
			end
		end
		if not iface or not iface:match("^[%w%._-]+$") then
			callback(nil, "offline")
			return
		end

		local port
		for hardware_port, device in services_output:gmatch("Hardware Port:%s*([^,\n]+),%s*Device:%s*([^%)\n]+)") do
			if device:match("^%s*(.-)%s*$") == iface then
				port = hardware_port:match("^%s*(.-)%s*$")
				break
			end
		end
		callback(iface, parsers.network_kind(port, iface))
	end)
end

local function icon_color(kind)
	if kind == "offline" then
		return colors.red
	end
	if kind == "hotspot" then
		return colors.mauve
	end
	return colors.sapphire
end

local net_iface, current_network_kind, last_interface_check
local last_up_str, last_down_str
local consecutive_failures = 0
local interface_check_in_flight = false

local function set_network_icon(kind)
	current_network_kind = kind or "offline"
	down:set({
		icon = {
			drawing = true,
			string = icons.network[current_network_kind] or icons.network.offline,
			color = icon_color(current_network_kind),
		},
	})
end

local function show_unavailable()
	last_up_str, last_down_str = nil, nil
	set_network_icon("offline")
	up:set({ label = "↑ —" })
	down:set({ label = "↓ —" })
end

local function sample_network()
	if not IFSTAT or not net_iface then
		consecutive_failures = 0
		show_unavailable()
		return
	end
	sbar.exec('"' .. IFSTAT .. '" -i ' .. net_iface .. " -b 0.1 1 2>/dev/null", function(raw)
		-- ifstat 输出 N 行 header + 1 行数据，取最后非空行避免依赖 header 行数
		local data = ""
		for line in (raw or ""):gmatch("[^\n]+") do
			if #line > 0 and not line:match("^%s*$") then
				data = line
			end
		end
		local down_raw, up_raw = data:match("%s*(%S+)%s+(%S+)")
		if not tonumber(down_raw) or not tonumber(up_raw) then
			consecutive_failures = consecutive_failures + 1
			if consecutive_failures >= MAX_CONSECUTIVE_FAILURES then
				show_unavailable()
			end
			return
		end

		consecutive_failures = 0
		local up_str = "↑" .. format_speed(up_raw)
		local down_str = "↓" .. format_speed(down_raw)
		-- dedup: 上下行速度和上次一样就不 set
		if up_str == last_up_str and down_str == last_down_str then
			return
		end
		last_up_str = up_str
		last_down_str = down_str
		up:set({ label = up_str })
		down:set({ label = down_str })
	end)
end

local function update_network(force_interface_check)
	local now = os.time()
	local needs_interface_check = force_interface_check
		or not net_iface
		or not last_interface_check
		or now - last_interface_check >= INTERFACE_REFRESH_INTERVAL
	if not needs_interface_check then
		sample_network()
		return
	end
	if interface_check_in_flight then
		return
	end

	interface_check_in_flight = true
	last_interface_check = now
	detect_network(function(iface, kind)
		interface_check_in_flight = false
		net_iface = iface
		set_network_icon(kind)
		sample_network()
	end)
end

down:subscribe("routine", function()
	update_network(false)
end)

down:subscribe({ "wifi_change", "system_woke" }, function()
	update_network(true)
end)

update_network(true)

-- ========== system bracket（clash_tun + network）==========
-- widget.clash_tun 在 clash_tun.lua 创建，此处覆写其 background + padding
-- 使 clash_tun 和 network_up/down 共享同一个 system bracket 背景。
-- 此耦合依赖 widgets/init.lua 的 require 顺序：clash_tun 在 network 之前加载。
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

-- spacer：system bracket 与 social bracket 之间的水平间隙
--   公式 = max(包裹item宽度) + 两侧bracket_border
--        = network_down(33+4+13+2+2=54) + 2 + 2 = 58
--   改 network_down 字体/宽度或 bracket border 时请同步更新此处
sbar.add("item", "widgets.system_bracket_spacer", {
	position = "right",
	width = 58,
	padding_left = 0,
	padding_right = 0,
	background = { drawing = false },
})

enter_animation.register("widgets.network_up")
enter_animation.register("widgets.network_down")
