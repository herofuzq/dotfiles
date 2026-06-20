-- ========== CPU 使用率与按需系统详情 ==========
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")

local CONFIG_DIR = os.getenv("CONFIG_DIR") or ""
local WATCHER = CONFIG_DIR .. "/helpers/event_providers/sys_watch/bin/sys_watch"
local WATCHER_PIDFILE = "/tmp/sketchybar_sys_watch.pid"
local SENSOR_PIDFILE = "/tmp/sketchybar_sys_sensor.pid"
local SENSOR_CACHE = "/tmp/sketchybar_sys_sensors.json"

local function find_executable(candidates)
	for _, path in ipairs(candidates) do
		local file = io.open(path, "r")
		if file then
			file:close()
			return path
		end
	end
	return nil
end

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local MACTOP = find_executable({ "/opt/homebrew/bin/mactop", "/usr/local/bin/mactop" })
local SKETCHYBAR = find_executable({ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" })
local WATCHER_EXECUTABLE = find_executable({ WATCHER })

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
		max_chars = 4,
		width = 30,
		color = colors.pill_fg,
	},
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
	popup = {
		align = "center",
		background = {
			color = appearance.with_alpha(colors.pill_bg, 0.9),
			corner_radius = 12,
			border_width = 2,
			border_color = colors.border,
			shadow = { drawing = false },
		},
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

local _popup_pinned, _popup_hovering, _exit_gen = false, false, 0
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
		"sensor_pidfile=" .. shell_quote(SENSOR_PIDFILE),
		'sensor_pid="$(cat "$sensor_pidfile" 2>/dev/null)"',
		'case "$sensor_pid" in ""|*[!0-9]*) sensor_pid="" ;; esac',
		'if [ -n "$sensor_pid" ]; then kill "$sensor_pid" 2>/dev/null; fi',
		'rm -f "$sensor_pidfile"',
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

local function refresh_sensor_cache()
	if not MACTOP or not SKETCHYBAR or not WATCHER_EXECUTABLE then
		return
	end
	local command = table.concat({
		"pidfile=" .. shell_quote(SENSOR_PIDFILE),
		"watcher_pidfile=" .. shell_quote(WATCHER_PIDFILE),
		'watcher_pid="$(cat "$watcher_pidfile" 2>/dev/null)"',
		'case "$watcher_pid" in ""|*[!0-9]*) watcher_pid="" ;; esac',
		'if [ -n "$watcher_pid" ] && kill -0 "$watcher_pid" 2>/dev/null; then exit 0; fi',
		'pid="$(cat "$pidfile" 2>/dev/null)"',
		'case "$pid" in ""|*[!0-9]*) pid="" ;; esac',
		'if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then exit 0; fi',
		shell_quote(WATCHER_EXECUTABLE)
			.. " "
			.. shell_quote(MACTOP)
			.. " "
			.. shell_quote(SKETCHYBAR)
			.. " 2000 "
			.. shell_quote(SENSOR_CACHE)
			.. " --sensor-only >/dev/null 2>&1 &",
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

local function show_popup()
	_exit_gen = _exit_gen + 1
	set_popup_items(true)
	sys:set({ popup = { drawing = true } })
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
	set_popup_items(false)
	sys:set({ popup = { drawing = false } })
	stop_watcher()
end

local function schedule_hide()
	if _popup_pinned then
		return
	end
	_exit_gen = _exit_gen + 1
	local gen = _exit_gen
	sbar.delay(0.2, function()
		if _exit_gen == gen and not _popup_hovering and not _popup_pinned then
			hide_popup()
		end
	end)
end

sys:subscribe("mouse.entered", show_popup)
sys:subscribe("mouse.exited", schedule_hide)
sys:subscribe("mouse.clicked", function()
	if _popup_pinned then
		_popup_pinned = false
		hide_popup()
	else
		_popup_pinned = true
		show_popup()
	end
end)

for _, item in ipairs({ info, table.unpack(process_items) }) do
	item:subscribe("mouse.entered", function()
		_exit_gen = _exit_gen + 1
		_popup_hovering = true
	end)
	item:subscribe("mouse.exited", function()
		_popup_hovering = false
		schedule_hide()
	end)
end

stop_watcher()
sbar.delay(8, refresh_sensor_cache)
sys:subscribe("system_woke", function()
	sbar.delay(8, refresh_sensor_cache)
end)

sys:subscribe("cpu_update", function(env)
	local cpu_load = math.max(0, math.min(100, math.floor(tonumber(env.total_load) or 0)))
	local cpu_str = string.format("%d%%", cpu_load)
	local cpu_color = cpu_load > 70 and colors.red
		or (cpu_load > 40 and colors.peach or colors.green)
	sys:set({
		icon = { color = cpu_color },
		label = { string = cpu_str, color = colors.pill_fg },
	})
end)
