-- ========== CPU 使用率显示 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

-- 启动 CPU 监控后台进程，每 2 秒通过事件推送 CPU 数据
-- 使用 pidfile 避免 reload 时误杀其他同名进程
sbar.exec(table.concat({
	'pidfile="${TMPDIR:-/tmp}/sketchybar_cpu_load.pid"',
	'cpu_bin="$CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load"',
	'if [ -f "$pidfile" ]; then',
	'old="$(cat "$pidfile" 2>/dev/null)"',
	'case "$old" in ""|*[!0-9]*) old="" ;; esac',
	'if [ -n "$old" ] && ps -p "$old" -o comm= 2>/dev/null | grep -qx cpu_load; then kill "$old" 2>/dev/null; fi',
	'else',
	'pkill -f "$cpu_bin cpu_update" 2>/dev/null',
	"fi",
	'"$cpu_bin" cpu_update 2.0 &',
	'echo $! > "$pidfile"',
}, "\n"))

local sys = sbar.add("item", "widgets.sys", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.cpu,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 0,
		color = colors.mauve,
	},
	label = {
		string = "0%",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 2,
		padding_right = 8,
		align = "right",
		max_chars = 3,
		width = 30,
		color = colors.pill_fg,
	},
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
})

sys:subscribe("cpu_update", function(env)
	local cpu_load = tonumber(env.total_load) or 0
	local cpu_str = string.format("%d%%", cpu_load > 99 and 99 or cpu_load)
	local cpu_color = cpu_load > 70 and colors.red
		or (cpu_load > 40 and colors.peach or colors.green)
	sys:set({
		icon = { color = cpu_color },
		label = { string = cpu_str, color = colors.pill_fg },
	})
end)
