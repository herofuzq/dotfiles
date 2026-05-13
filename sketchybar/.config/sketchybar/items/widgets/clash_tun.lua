-- ========== Clash TUN 代理状态 ==========
-- 通过 Unix Socket 查询 Clash Verge 的 TUN 模式是否开启
-- 显示 "TUN"（绿色）或 "OFF"（红色）
local icons = require("icons")
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

local clash_tun = sbar.add("item", "widgets.clash_tun", {
	position = "right",
	update_freq = 5,            -- 每 5 秒轮询一次
	padding_left = 2,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.tokyo_night.bg3_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = settings.padding.icon_label_item.label.padding_right,
		color = colors.tokyo_night.sep_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.item_gradient[6],
		border_width = 2,
	},
})

-- 更新显示：TUN 开启=绿色图标，关闭=红色图标，文字始终灰色
local function update_display(tun_on)
	local icon_color = tun_on and colors.green or colors.red
	clash_tun:set({
		icon = { string = icons.clash.tun, color = icon_color },
		label = { string = tun_on and "TUN" or "OFF", color = colors.tokyo_night.sep_opaque },
	})
end

-- 通过 Unix Socket 查询 Clash Verge 配置中 tun.enable 的值
local function check_status()
	sbar.exec(
		"curl -s --max-time 2 --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/configs 2>/dev/null | python3 -c \"import sys,json; print('on' if json.load(sys.stdin)['tun']['enable'] else 'off')\" 2>/dev/null || echo 'off'",
		function(status)
			update_display(status:match("on") ~= nil)
		end
	)
end

clash_tun:subscribe({ "routine", "system_woke" }, check_status)
check_status()

-- 点击触发 Clash TUN 切换快捷键 (ctrl+opt+cmd+D)
clash_tun:subscribe("mouse.clicked", function()
	sbar.exec("osascript -e 'tell application \"System Events\" to keystroke \"d\" using {command down, control down, option down}'")
end)
