-- ========== Clash TUN 代理状态 ==========
-- 自身不画 pill；背景由 network.lua 的 widgets.system bracket 统一提供。
-- 须在 widgets/init.lua 里先于 network 加载。
local sbar = require("sketchybar")
local icons = require("icons")
local appearance = require("appearance")
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("clash_tun.status")
local settings = require("settings")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 30, -- 与其他外部轮询错峰
	padding_left = 1,
	padding_right = 0,
	icon = {
		font = appearance.font_icon_bold(),
		padding_left = 2,
		padding_right = 2,
		color = colors.surface1,
	},
	label = {
		font = appearance.font_label_bold(),
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.pill_fg,
	},
	background = { drawing = false },
})

local function color_for(state)
	if state == "all" then
		return colors.identity.clash_all
	end
	if state == "tun" then
		return colors.status.ok
	end
	if state == "sys" then
		return colors.identity.clash_sys
	end
	if state == "off" then
		return colors.status.error
	end
	return colors.surface1
end

local function label_for(state)
	if state == "all" then
		return "ALL"
	end
	if state == "tun" then
		return "TUN"
	end
	if state == "sys" then
		return "SYS"
	end
	if state == "off" then
		return "OFF"
	end
	return "—"
end

local function update_display(state)
	startup.after_reveal("clash_tun.status", function()
		clash_tun:set({
			icon = { string = icons.clash.tun, color = color_for(state) },
			label = { string = label_for(state), color = colors.pill_fg },
		})
	end)
end

local last_state
local clash_status_in_flight = false
local clash_status_pending = false

local function check_status()
	if clash_status_in_flight then
		clash_status_pending = true
		return
	end
	clash_status_in_flight = true
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		clash_status_in_flight = false
		if clash_status_pending then
			clash_status_pending = false
			check_status()
		end
	end
	-- clash_status.sh 内含 curl --max-time 2；这里再加 3s 总闸，避免唤醒风暴时查询互相重叠。
	sbar.delay(3.0, function()
		if finished then
			return
		end
		initial_ready()
		finish()
	end)
	sbar.exec("$CONFIG_DIR/helpers/clash_status.sh", function(status)
		if finished then
			return
		end
		status = (status or ""):match("^%s*(.-)%s*$")
		if status == last_state then
			initial_ready()
			finish()
			return
		end
		last_state = status
		update_display(status)
		initial_ready()
		finish()
	end)
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

-- ========== 主题热换色：按缓存 state 用 color_for 重涂 ==========
local function apply_colors(C)
	clash_tun:set({
		icon = { color = color_for(last_state) },
		label = { color = C.pill_fg },
	})
end
apply_colors(colors)
appearance.register_colors("clash_tun", apply_colors)
