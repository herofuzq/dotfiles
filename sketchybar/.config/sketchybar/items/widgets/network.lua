-- ========== 网络收发速度显示 ==========
-- 由后台 C 程序 network_load 每 2 秒推送 network_update 事件
-- 显示格式：下载速度      上传速度
local colors = require("appearance").colors
local sbar = require("sketchybar")
local fonts = require("fonts")

-- 网络图标（NerdFont 字形）
local wifi_icon = "󰖩"         -- WiFi 图标（预留）
local wifi_down_icon = ""    -- 下载箭头
local wifi_up_icon = ""      -- 上传箭头

-- 启动网络监控后台进程，每 2 秒通过事件推送网络数据（监听 en0 网卡）
sbar.exec("killall network_load >/dev/null; $CONFIG_DIR/helpers/event_providers/network_load/bin/network_load en0 network_update 2.0")

local network = sbar.add("item", "widgets.network", {
	position = "right",
	icon = {
		string = wifi_down_icon,
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = 10.0,          -- 图标稍小
		},
		padding_left = 4,
		padding_right = 1,
	},
	label = {
		string = "  0B " .. wifi_up_icon .. "  0B",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = 10.0,
		},
		padding_left = 0,
		padding_right = 4,
	},
	background = {
		color = colors.tokyo_night.bg1,
		corner_radius = 0,       -- 无圆角，融入菜单栏背景
	},
})

-- 格式化速度：保留 4 位宽度右对齐，避免数字跳动
local function fmt_speed(raw)
	if not raw then return "   0B" end
	local val, unit = raw:match("^%s*(%d+)%s*(%a+)$")
	if not val then return "   0B" end
	local num = tonumber(val) or 0
	if unit == "MBps" then
		return string.format("%4dM", num)
	elseif unit == "KBps" then
		return string.format("%4dK", num)
	else
		return string.format("%4dB", num)
	end
end

-- 响应后台进程推送的 network_update 事件
network:subscribe("network_update", function(env)
	network:set({
		label = {
			string = fmt_speed(env.download) .. " " .. wifi_up_icon .. " " .. fmt_speed(env.upload),
		},
	})
end)
