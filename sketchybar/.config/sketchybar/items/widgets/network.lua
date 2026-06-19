-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local NETWORK_SAMPLE_INTERVAL = 3
local INTERFACE_REFRESH_INTERVAL = 30

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
local function find_ifstat()
	for _, p in ipairs({ "/opt/homebrew/bin/ifstat", "/usr/local/bin/ifstat" }) do
		local f = io.open(p, "r")
		if f then
			f:close()
			return p
		end
	end
	return nil
end

local IFSTAT = find_ifstat()

local function network_kind(port, iface)
	port = (port or ""):lower()
	if port:find("wi%-fi") or port:find("airport") then
		return "wifi"
	end
	if port:find("iphone") or port:find("mobile") or port:find("cellular") then
		return "hotspot"
	end
	if port:find("ethernet")
		or port:find("lan")
		or port:find("usb")
		or port:find("thunderbolt")
	then
		return "ethernet"
	end
	if iface == "en0" then
		return "wifi"
	end
	if iface and (iface:match("^en%d+$") or iface:match("^bridge%d+$")) then
		return "ethernet"
	end
	return "unknown"
end

local function detect_network()
	local command = table.concat({
		"route get default 2>/dev/null",
		"printf '\\n---SERVICES---\\n'",
		"networksetup -listnetworkserviceorder 2>/dev/null",
		"printf '\\n---NWI---\\n'",
		"scutil --nwi 2>/dev/null",
	}, "; ")
	local f = io.popen(command)
	local output = f and (f:read("*a") or "") or ""
	if f then
		f:close()
	end

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
		return nil, "offline"
	end

	local port
	for hardware_port, device in services_output:gmatch("Hardware Port:%s*([^,\n]+),%s*Device:%s*([^%)\n]+)") do
		if device:match("^%s*(.-)%s*$") == iface then
			port = hardware_port:match("^%s*(.-)%s*$")
			break
		end
	end
	return iface, network_kind(port, iface)
end

local function icon_color(kind)
	if kind == "offline" then
		return colors.surface1
	end
	if kind == "hotspot" then
		return colors.mauve
	end
	return colors.sapphire
end

local net_iface, current_network_kind, last_interface_check

local function update_network(force_interface_check)
	local now = os.time()
	if force_interface_check
		or not net_iface
		or not last_interface_check
		or now - last_interface_check >= INTERFACE_REFRESH_INTERVAL
	then
		net_iface, current_network_kind = detect_network()
		last_interface_check = now
		down:set({
			icon = {
				string = icons.network[current_network_kind] or icons.network.unknown,
				color = icon_color(current_network_kind),
			},
		})
	end

	if not IFSTAT or not net_iface then
		up:set({ label = "↑  —" })
		down:set({ label = "↓  —" })
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
		if not down_raw or not up_raw then
			up:set({ label = "↑  —" })
			down:set({ label = "↓  —" })
			return
		end

		up:set({ label = "↑" .. format_speed(up_raw) })
		down:set({ label = "↓" .. format_speed(down_raw) })
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
