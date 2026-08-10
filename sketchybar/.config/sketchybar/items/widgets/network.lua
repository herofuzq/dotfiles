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
local SAMPLE_TIMEOUT = 1.5

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
		color = colors.identity.network,
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
	sbar.exec(command, function(output, exit_code)
		if tonumber(exit_code) ~= 0 then
			callback(nil, "offline", true)
			return
		end
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
			callback(nil, "offline", true)
			return
		end

		local port
		for hardware_port, device in services_output:gmatch("Hardware Port:%s*([^,\n]+),%s*Device:%s*([^%)\n]+)") do
			if device:match("^%s*(.-)%s*$") == iface then
				port = hardware_port:match("^%s*(.-)%s*$")
				break
			end
		end
		callback(iface, parsers.network_kind(port, iface), true)
	end)
end

local function icon_color(kind)
	if kind == "offline" then
		return colors.status.error
	end
	if kind == "hotspot" then
		return colors.identity.network_hotspot
	end
	return colors.identity.network
end

local net_iface, current_network_kind, next_interface_check_at, next_sample_at
local last_up_str, last_down_str
local consecutive_failures = 0
local unavailable = false
local interface_check_generation = 0
local interface_check_in_flight
local interface_check_pending
local retained_detection_intent
local interface_epoch = 0
local sample_generation = 0
local sample_request_generation = 0
local active_sample_request
local forced_sample_pending = false

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
	if unavailable and not last_up_str and not last_down_str then
		return
	end
	unavailable = true
	last_up_str, last_down_str = nil, nil
	startup.after_reveal("network.values", function()
		up:set({ label = "↑ —" })
		down:set({ label = "↓ —" })
	end)
end

local function reset_sample_epoch()
	interface_epoch = interface_epoch + 1
	sample_generation = sample_generation + 1
	consecutive_failures = 0
	next_sample_at = nil
	forced_sample_pending = false
	show_unavailable()
end

local function invalidate_sample_generation()
	sample_generation = sample_generation + 1
end

local function failure_delay(failure_count)
	if failure_count == 1 then return 3 end
	if failure_count == 2 then return 6 end
	if failure_count == 3 then return 12 end
	return 15
end

local sample_network

local function finish_sample(request_id, source, raw, exit_code)
	local request = active_sample_request
	if not request or request.id ~= request_id then
		return
	end

	-- Clear only this request's ownership before checking whether its result is stale.
	active_sample_request = nil
	local pending_force = forced_sample_pending
	forced_sample_pending = false
	local current = request.iface == net_iface
		and request.epoch == interface_epoch
		and request.generation == sample_generation

	if pending_force then
		sample_network(true)
		return
	end

	if not current then
		return
	end

	local down_raw, up_raw
	if source == "callback" and tonumber(exit_code) == 0 then
		local data = ""
		for line in (raw or ""):gmatch("[^\n]+") do
			if #line > 0 and not line:match("^%s*$") then
				data = line
			end
		end
		down_raw, up_raw = data:match("%s*(%S+)%s+(%S+)")
	end

	if source == "timeout" or not tonumber(down_raw) or not tonumber(up_raw) then
		consecutive_failures = consecutive_failures + 1
		next_sample_at = os.time() + failure_delay(consecutive_failures)
		if consecutive_failures >= MAX_CONSECUTIVE_FAILURES then
			show_unavailable()
		end
		initial_ready()
		return
	end

	consecutive_failures = 0
	next_sample_at = os.time() + NETWORK_SAMPLE_INTERVAL
	unavailable = false
	local up_str = "↑" .. format_speed(up_raw)
	local down_str = "↓" .. format_speed(down_raw)
	if up_str ~= last_up_str or down_str ~= last_down_str then
		last_up_str = up_str
		last_down_str = down_str
		startup.after_reveal("network.values", function()
			up:set({ label = up_str })
			down:set({ label = down_str })
		end)
	end
	initial_ready()
end

sample_network = function(force)
	if not IFSTAT or not net_iface then
		show_unavailable()
		initial_ready()
		return
	end
	if active_sample_request then
		if force then forced_sample_pending = true end
		return
	end
	if not force and next_sample_at and os.time() < next_sample_at then
		return
	end

	sample_request_generation = sample_request_generation + 1
	local request = {
		id = sample_request_generation,
		iface = net_iface,
		epoch = interface_epoch,
		generation = sample_generation,
		finished = false,
	}
	active_sample_request = request

	sbar.exec(
		shell_quote(IFSTAT) .. " -i " .. shell_quote(request.iface) .. " -b 0.1 1 2>/dev/null",
		function(raw, exit_code)
			if request.finished then return end
			request.finished = true
			finish_sample(request.id, "callback", raw, exit_code)
		end
	)
	sbar.delay(SAMPLE_TIMEOUT, function()
		if request.finished then return end
		request.finished = true
		finish_sample(request.id, "timeout")
	end)
end

local function intent_for_reason(reason)
	return {
		reason = reason,
		force_check = reason ~= "routine",
		reset_epoch = reason == "wifi_change",
		force_sample_after_check = reason == "system_woke" or reason == "wifi_change",
	}
end

local function merge_intents(left, right)
	if not left then return right end
	if not right then return left end
	local reset_epoch = left.reset_epoch or right.reset_epoch
	local force_sample_after_check = left.force_sample_after_check or right.force_sample_after_check
	local reason
	if reset_epoch then
		reason = "wifi_change"
	elseif force_sample_after_check then
		reason = "system_woke"
	elseif left.reason == "initial" or right.reason == "initial" then
		reason = "initial"
	else
		reason = right.reason or left.reason
	end
	return {
		reason = reason,
		force_check = left.force_check or right.force_check,
		reset_epoch = reset_epoch,
		force_sample_after_check = force_sample_after_check,
	}
end

local update_network

local function launch_interface_check(intent)
	interface_check_generation = interface_check_generation + 1
	local generation = interface_check_generation
	interface_check_in_flight = { generation = generation, intent = intent }

	local function finish(iface, kind, apply_result)
		local active = interface_check_in_flight
		if not active or active.generation ~= generation then
			return
		end
		interface_check_in_flight = nil
		local pending = interface_check_pending
		interface_check_pending = nil
		if pending then
			launch_interface_check(merge_intents(intent, pending))
			return
		end

		local retry_interval = apply_result and iface and INTERFACE_REFRESH_INTERVAL or OFFLINE_RETRY_INTERVAL
		next_interface_check_at = os.time() + retry_interval
		if not apply_result then
			if intent.force_sample_after_check then
				retained_detection_intent = merge_intents(retained_detection_intent, intent)
			else
				sample_network(false)
			end
			initial_ready()
			return
		end

		local interface_changed = iface ~= net_iface
		if interface_changed then
			reset_sample_epoch()
			net_iface = iface
		elseif not iface then
			show_unavailable()
		end
		set_network_icon(kind)
		if iface then
			retained_detection_intent = nil
			sample_network(intent.force_sample_after_check or interface_changed)
		else
			if intent.force_sample_after_check then
				retained_detection_intent = merge_intents(retained_detection_intent, intent)
			end
			initial_ready()
		end
	end

	sbar.delay(5, function()
		finish(nil, nil, false)
	end)

	detect_network(function(iface, kind, apply_result)
		finish(iface, kind, apply_result)
	end)
end

update_network = function(reason)
	local intent = intent_for_reason(reason)
	if intent.reset_epoch then
		reset_sample_epoch()
		next_interface_check_at = nil
	elseif reason == "system_woke" then
		invalidate_sample_generation()
	end

	if interface_check_in_flight then
		if intent.force_check then
			interface_check_pending = merge_intents(interface_check_pending, intent)
		end
		return
	end

	local now = os.time()
	local needs_interface_check = intent.force_check
		or not next_interface_check_at
		or now >= next_interface_check_at
	if needs_interface_check then
		intent = merge_intents(retained_detection_intent, intent)
		retained_detection_intent = nil
		launch_interface_check(intent)
	elseif not retained_detection_intent or not retained_detection_intent.force_sample_after_check then
		sample_network(false)
	end
end

down:subscribe("routine", function()
	update_network("routine")
end)

down:subscribe("wifi_change", function()
	update_network("wifi_change")
end)

down:subscribe("system_woke", function()
	update_network("system_woke")
end)

update_network("initial")

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
appearance.register_pill("widgets.system")

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

-- ========== 主题热换色：按缓存的网络类型重涂 ==========
local function apply_colors(C)
	-- 尚未完成首次检测时保持创建期的 identity.network
	down:set({
		icon = { color = current_network_kind and icon_color(current_network_kind) or C.identity.network },
		label = { color = C.pill_fg },
	})
	up:set({ label = { color = C.pill_fg } })
	sbar.set("widgets.system", {
		background = { color = C.pill_bg, border_color = C.border },
	})
end
apply_colors(colors)
appearance.register_colors("network", apply_colors)
