-- ========== 网络速度显示（↓下载 / ↑上传，上下堆叠）==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local appearance = require("appearance")
local parsers = require("helpers.widget_parsers")
local enter_animation = require("helpers.enter_animation")
local find_binary = require("helpers.find_binary").find
local colors = appearance.colors
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

-- bracket 容器：背景 + wifi 图标
sbar.add("bracket", "widgets.network", { "widgets.network_up", "widgets.network_down" }, {
	position = "right",
	icon = { drawing = false },
	padding_left = 4,
	padding_right = 0,
	background = appearance.pill_bg(),
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
local interface_check_pending = false
local interface_check_generation = 0

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
		last_interface_check = nil
		interface_check_in_flight = false
		if interface_check_pending then
			interface_check_pending = false
			update_network(true)
		else
			sample_network()
		end
	end)

	detect_network(function(iface, kind)
		if not interface_check_in_flight or interface_check_generation ~= generation then
			return
		end
		interface_check_in_flight = false
		net_iface = iface
		set_network_icon(kind)
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
	background = appearance.pill_bg(),
})

-- spacer：system bracket 与 social bracket 之间的水平间隙。
--   公式 = max(包裹item宽度) + 两侧bracket_border
--        = network_down(width=33 + padding_left=4 + icon=13 + padding_left=2 + padding_right=2 = 54) + border_left=2 + border_right=2 = 58
-- ⚠️ 脆弱点：SPACER_WIDTH 硬编码，依赖 network_down 的 font-size / icon-size / padding 和 bracket border_width。
--   改 network_down 字体/宽度或 appearance.pill_bg() 的 border_width 时，必须同步更新此值。
--   暂不改动（纯视觉间距问题，动态化引入复杂度 > 收益），保留现状并加注释。
local SPACER_WIDTH = 58
sbar.add("item", "widgets.system_bracket_spacer", {
	position = "right",
	width = SPACER_WIDTH,
	padding_left = 0,
	padding_right = 0,
	background = { drawing = false },
})

enter_animation.register("widgets.network_up")
enter_animation.register("widgets.network_down")
