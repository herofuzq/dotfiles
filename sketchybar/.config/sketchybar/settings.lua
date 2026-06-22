-- 全局设置：高度、默认边距等
--
-- 外部依赖说明（哪些是 brew 装、哪些是本地编译）:
--   bar_height: 本地编译产物 helpers/bar_height/bin/bar_height (Swift, autostart-on-stale)
--   dock_width: 本地编译产物 helpers/dock_width/bin/dock_width (Swift, autostart-on-stale)
--   sketchybar-toggle: brew 安装 (随 sketchybar cask 一起),由 ensure_toggle() 启动,
--                      实现"鼠标接近顶部自动显示 / 远离自动隐藏"bar 的行为
local BAR_HEIGHT_CACHE = "/tmp/sketchybar_bar_height.cache"
local TOGGLE_PIDFILE = "/tmp/sketchybar_toggle.pid"
local TOGGLE_CONFIG_FILE = "/tmp/sketchybar_toggle.config"
local TOGGLE_TRIGGER_ZONE = 2
local TOGGLE_DEBOUNCE_MS = 150

local function read_cache(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local value = f:read("*a")
	f:close()
	return value
end

local function write_cache(path, value)
	local f = io.open(path, "w")
	if not f then
		return
	end
	f:write(value)
	f:close()
end

-- fallback: 非刘海外接屏无菜单栏时的兜底
-- 用 Carbon GetMBarHeight (30) 的标准值, 不信实测 31 那 1pt 漂移
local FALLBACK_HEIGHT = 30

local function detect_bar_height(force)
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/bar_height/bin/bar_height" 2>/dev/null')
		if f then
			local output = f:read("*a")
			f:close()
			local h = output:match("^(%d+)")
			if h then
				h = tonumber(h)
				if h and h > 0 then
					-- binary 拿到有效值 → 更新 cache 并返回
					write_cache(BAR_HEIGHT_CACHE, tostring(h))
					return h
				end
				-- h == 0: 菜单栏在无刘海屏被隐藏了, 不污染 cache
			end
		end
	end
	-- binary 失败 / 菜单栏在无刘海屏隐藏 → 优先用 cache (保留上次可见时的实测值)
	local cached = tonumber(read_cache(BAR_HEIGHT_CACHE))
	if cached and cached > 0 then
		return cached
	end
	-- 冷启动 cache 也是空 → 用 fallback
	write_cache(BAR_HEIGHT_CACHE, tostring(FALLBACK_HEIGHT))
	return FALLBACK_HEIGHT
end

local function detect_dock_width()
	local fallback = 55
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/dock_width/bin/dock_width" 2>/dev/null')
		if f then
			local output = f:read("*a")
			f:close()
			local w, hidden, x = output:match("^(%d+)%s+(%d+)%s+(%-?%d+)")
			local width = tonumber(w)
			if width and width > 0 then
				return width, tonumber(hidden) or 0, tonumber(x) or 0
			end
		end
	end
	return fallback, 0, 0
end

local function ensure_toggle(bar_height)
	bar_height = math.floor(tonumber(bar_height) or 0)
	if bar_height <= 0 then
		return
	end

	local menu_bar_height = bar_height + 5
	local signature = string.format("%d:%d:%d", TOGGLE_TRIGGER_ZONE, menu_bar_height, TOGGLE_DEBOUNCE_MS)
	local command = table.concat({
		'pidfile="' .. TOGGLE_PIDFILE .. '"',
		'configfile="' .. TOGGLE_CONFIG_FILE .. '"',
		'expected="' .. signature .. '"',
		'old="$(cat "$pidfile" 2>/dev/null)"',
		'case "$old" in ""|*[!0-9]*) old="" ;; esac',
		'current="$(cat "$configfile" 2>/dev/null)"',
		'is_toggle() { [ -n "$old" ] && ps -p "$old" -o args= 2>/dev/null | grep -Fq "sketchybar-toggle --trigger-zone"; }',
		'if is_toggle && [ "$current" = "$expected" ]; then exit 0; fi',
		'if is_toggle; then kill "$old" 2>/dev/null; else pkill -x sketchybar-toggle 2>/dev/null; fi',
		string.format(
			"sketchybar-toggle --trigger-zone %d --menu-bar-height %d --debounce %d >/dev/null 2>&1 &",
			TOGGLE_TRIGGER_ZONE,
			menu_bar_height,
			TOGGLE_DEBOUNCE_MS
		),
		'echo $! > "$pidfile"',
		'printf %s "$expected" > "$configfile"',
	}, "\n")
	os.execute(command)
end

return {
	height = detect_bar_height(),
	detect_bar_height = detect_bar_height,
	detect_dock_width = detect_dock_width,
	ensure_toggle = ensure_toggle,
	default_padding = 8,
	item_padding = {
		icon_label_item = {
			icon = {
				padding_left = 8,
				padding_right = 0,
			},
			label = {
				padding_left = 6,
				padding_right = 8,
			},
		},
	},
}
