-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local appearance = require("appearance")
local parsers = require("helpers.widget_parsers")
local find_binary = require("helpers.find_binary").find
local shell_quote = require("helpers.utils").shell_quote
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("network.status")
local NETWORK_SAMPLE_INTERVAL = 3
local INTERFACE_REFRESH_INTERVAL = 60
local OFFLINE_RETRY_INTERVAL = 15
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
		font = appearance.font_label_bold(9.0),
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
		font = appearance.font_icon_bold(13.0),
		drawing = true,
		padding_left = 4,
		padding_right = 0,
		color = colors.sapphire,
	},
	label = {
		string = "—",
		font = appearance.font_label_bold(9.0),
		padding_left = 0,
		padding_right = 0,
		width = 33,
		align = "right",
		color = colors.pill_fg,
		y_offset = -4,
	},
	background = { drawing = false },
})

-- 仅用于组合上下行；可见背景由外层 widgets.system 统一绘制。
sbar.add("bracket", "widgets.network", { "widgets.network_up", "widgets.network_down" }, {
	position = "right",
	icon = { drawing = false },
	padding_left = 4,
	padding_right = 0,
	background = { drawing = false },
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
local unavailable = false
local interface_check_in_flight = false
local interface_check_pending = false
local interface_check_generation = 0

local function set_network_icon(kind)
	local next_kind = kind or "offline"
	if current_network_kind == next_kind then
		return
	end
	current_network_kind = next_kind
	startup.after_reveal("network.icon", function()
		down:set({
			icon = {
				drawing = true,
				string = icons.network[next_kind] or icons.network.offline,
				color = icon_color(next_kind),
			},
		})
	end)
end

local function show_unavailable()
	if unavailable then
		return
	end
	unavailable = true
	last_up_str, last_down_str = nil, nil
	set_network_icon("offline")
	startup.after_reveal("network.values", function()
		up:set({ label = "↑ —" })
		down:set({ label = "↓ —" })
	end)
end

local function sample_network()
	if not IFSTAT or not net_iface then
		consecutive_failures = 0
		show_unavailable()
		initial_ready()
		return
	end
	sbar.exec(
		shell_quote(IFSTAT) .. " -i " .. shell_quote(net_iface) .. " -b 0.1 1 2>/dev/null",
		function(raw)
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
				initial_ready()
				return
			end

			consecutive_failures = 0
			unavailable = false
			local up_str = "↑" .. format_speed(up_raw)
			local down_str = "↓" .. format_speed(down_raw)
			-- dedup: 上下行速度和上次一样就不 set
			if up_str == last_up_str and down_str == last_down_str then
				initial_ready()
				return
			end
			last_up_str = up_str
			last_down_str = down_str
			startup.after_reveal("network.values", function()
				up:set({ label = up_str })
				down:set({ label = down_str })
			end)
			initial_ready()
		end
	)
end

local function update_network(force_interface_check)
	local now = os.time()
	local interface_refresh_interval = net_iface and INTERFACE_REFRESH_INTERVAL or OFFLINE_RETRY_INTERVAL
	local needs_interface_check = force_interface_check
		or not last_interface_check
		or now - last_interface_check >= interface_refresh_interval
	if not needs_interface_check then
		sample_network()
		return
	end
	if interface_check_in_flight then
		if force_interface_check then
			interface_check_pending = true
		end
		return
	end

	interface_check_in_flight = true
	interface_check_generation = interface_check_generation + 1
	local generation = interface_check_generation
	last_interface_check = now

	sbar.delay(5, function()
		if not interface_check_in_flight or interface_check_generation ~= generation then
			return
		end
		last_interface_check = os.time()
		interface_check_in_flight = false
		if interface_check_pending then
			interface_check_pending = false
			update_network(true)
		else
			sample_network()
		end
		initial_ready()
	end)

	detect_network(function(iface, kind)
		if not interface_check_in_flight or interface_check_generation ~= generation then
			return
		end
		interface_check_in_flight = false
		net_iface = iface
		set_network_icon(kind)
		if iface then
			unavailable = false
		end
		sample_network()
		if interface_check_pending then
			interface_check_pending = false
			update_network(true)
		end
	end)
end

down:subscribe("routine", function()
	update_network(false)
end)

down:subscribe({ "wifi_change", "system_woke" }, function()
	update_network(true)
end)

update_network(true)

-- ========== system bracket（clash_tun + network_up/down）==========
-- clash_tun、network 子项及子 bracket 创建时均不绘制背景。
-- 依赖 widgets/init.lua：clash_tun 在 network 之前 require。
sbar.add("bracket", "widgets.system", {
	"widgets.clash_tun",
	"widgets.network_up",
	"widgets.network_down",
}, {
	position = "right",
	background = appearance.pill_bg(),
})

-- spacer：system bracket 与 social bracket 之间的水平间隙（硬编码，改 network 字号/padding 时需同步）。
-- 公式约 = network_down 可视宽度 + system bracket 左右 border。
local SPACER_WIDTH = 58
sbar.add("item", "widgets.system_bracket_spacer", {
	position = "right",
	width = SPACER_WIDTH,
	padding_left = 0,
	padding_right = 0,
	background = { drawing = false },
})
