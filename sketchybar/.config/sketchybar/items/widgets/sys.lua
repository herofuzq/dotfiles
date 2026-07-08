-- ========== CPU 使用率与按需系统详情 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local enter_animation = require("helpers.enter_animation")
local colors = appearance.colors
local settings = require("settings")

local CONFIG_DIR = os.getenv("CONFIG_DIR") or ""
local WATCHER = CONFIG_DIR .. "/helpers/event_providers/sys_watch/bin/sys_watch"
local WATCHER_PIDFILE = "/tmp/sketchybar_sys_watch.pid"
local SENSOR_CACHE = "/tmp/sketchybar_sys_sensors.json"

local find_binary = require("helpers.find_binary").find

local shell_quote = require("helpers.utils").shell_quote

local MACTOP = find_binary({ "/opt/homebrew/bin/mactop", "/usr/local/bin/mactop" })
local SKETCHYBAR = find_binary({ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" })
local WATCHER_EXECUTABLE = find_binary({ WATCHER })

-- 启动 CPU 监控后台进程，每 2 秒通过事件推送 CPU 数据
-- 使用 pidfile 避免 reload 时误杀其他同名进程
sbar.exec(table.concat({
	'pidfile="${TMPDIR:-/tmp}/sketchybar_cpu_load.pid"',
	'cpu_bin="$CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load"',
	'old="$(cat "$pidfile" 2>/dev/null)"',
	'case "$old" in ""|*[!0-9]*) old="" ;; esac',
	'if [ -n "$old" ]; then kill "$old" 2>/dev/null; fi',
	'ps -axo pid=,args= | awk -v bin="$cpu_bin" \'index($0, bin " cpu_update") { print $1 }\' | while read -r pid; do',
	'[ "$pid" != "$$" ] && kill "$pid" 2>/dev/null',
	"done",
	'"$cpu_bin" cpu_update 2.0 &',
	'echo $! > "$pidfile"',
}, "\n"))

local sys = sbar.add("item", "widgets.sys", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = icons.cpu,
		font = appearance.font_icon_bold(),
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 0,
		color = colors.mauve,
	},
	label = {
		string = "0%",
		font = appearance.font_label_bold(),
		padding_left = 2,
		padding_right = 8,
		align = "right",
		max_chars = 4,
		width = 30,
		color = colors.pill_fg,
	},
	background = appearance.pill_bg(),
	popup = {
		align = "center",
		background = appearance.popup_bg(),
		blur_radius = 30,
		height = 30,
	},
})

local function popup_item(name, text, color)
	return sbar.add("item", name, {
		position = "popup.widgets.sys",
		drawing = false,
		width = 250,
		icon = { drawing = false },
		label = {
			string = text,
			font = { family = fonts.font.text, style = fonts.font.style_map["Semibold"], size = 12.0 },
			color = color or colors.pill_fg,
			padding_left = 12,
			padding_right = 12,
			align = "left",
			width = 226,
		},
		background = { drawing = false },
	})
end

local info = popup_item("widgets.sys.info", "正在读取温度和进程…", colors.peach)
local process_items = {}
for i = 1, 10 do
	process_items[i] = popup_item("widgets.sys.process." .. i, " ")
end

local popup_utils = require("helpers.popup_utils")
local popup_state = popup_utils.new_state()
local _watching = false

local function stop_watcher()
	_watching = false
	local command = table.concat({
		"pidfile=" .. shell_quote(WATCHER_PIDFILE),
		"watcher=" .. shell_quote(WATCHER),
		'pid="$(cat "$pidfile" 2>/dev/null)"',
		'case "$pid" in ""|*[!0-9]*) pid="" ;; esac',
		'if [ -n "$pid" ] && ps -p "$pid" -o args= 2>/dev/null | grep -Fq "$watcher"; then kill "$pid" 2>/dev/null; fi',
		'rm -f "$pidfile"',
	}, "\n")
	sbar.exec(command)
end

local function start_watcher()
	if _watching or not MACTOP or not SKETCHYBAR or not WATCHER_EXECUTABLE then
		return
	end
	_watching = true
	local command = table.concat({
		"pidfile=" .. shell_quote(WATCHER_PIDFILE),
		shell_quote(WATCHER_EXECUTABLE)
			.. " "
			.. shell_quote(MACTOP)
			.. " "
			.. shell_quote(SKETCHYBAR)
			.. " 2000 "
			.. shell_quote(SENSOR_CACHE)
			.. " >/dev/null 2>&1 &",
		'echo $! > "$pidfile"',
	}, "\n")
	sbar.exec(command)
end

local function set_popup_items(drawing)
	info:set({ drawing = drawing })
	for _, item in ipairs(process_items) do
		item:set({ drawing = drawing })
	end
end

local sys_popup = popup_animation.new(sys, {
	background_color = function()
		return appearance.popup_bg().color
	end,
	on_hidden = function()
		set_popup_items(false)
		stop_watcher()
	end,
})

local function show_popup()
	popup_state.exit_gen = popup_state.exit_gen + 1
	set_popup_items(true)
	sys_popup:show()
	if not MACTOP then
		info:set({ label = "请安装 mactop" })
		for _, item in ipairs(process_items) do
			item:set({ drawing = false })
		end
		return
	end
	if not WATCHER_EXECUTABLE or not SKETCHYBAR then
		info:set({ label = "系统信息不可用" })
		for _, item in ipairs(process_items) do
			item:set({ drawing = false })
		end
		return
	end
	start_watcher()
end

local function hide_popup()
	sys_popup:hide_async()
end

local function schedule_hide()
	popup_utils.schedule_hide(popup_state, function()
		hide_popup()
	end)
end

sys:subscribe("mouse.entered", show_popup)
sys:subscribe("mouse.exited", schedule_hide)
sys:subscribe("mouse.clicked", function()
	if popup_state.pinned then
		popup_state.pinned = false
		hide_popup()
	else
		popup_state.pinned = true
		show_popup()
	end
end)

popup_utils.bind_popup_hover({ info, table.unpack(process_items) }, popup_state, schedule_hide)

stop_watcher()

local last_cpu_signature

sys:subscribe("cpu_update", function(env)
	local cpu_load = math.max(0, math.min(100, math.floor(tonumber(env.total_load) or 0)))
	local cpu_color = cpu_load > 70 and colors.red
		or (cpu_load > 40 and colors.peach or colors.green)
	-- dedup: cpu 百分比和颜色档位都和上次一样就不 set
	local signature = cpu_load .. "|" .. tostring(cpu_color)
	if signature == last_cpu_signature then
		return
	end
	last_cpu_signature = signature
	sys:set({
		icon = { color = cpu_color },
		label = { string = string.format("%d%%", cpu_load), color = colors.pill_fg },
	})
end)

enter_animation.register("widgets.sys")
