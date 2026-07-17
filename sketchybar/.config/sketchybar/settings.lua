-- 全局设置：高度、默认边距等
--
-- 外部依赖说明（哪些是 brew 装、哪些是本地编译）:
--   bar_height: 本地编译产物 helpers/bar_height/bin/bar_height (Swift, autostart-on-stale)
--   dock_width: 本地编译产物 helpers/dock_width/bin/dock_width (Swift, autostart-on-stale)
local tmp_path = require("helpers.utils").tmp_path
local BAR_HEIGHT_CACHE = tmp_path("sketchybar_bar_height.cache")
local DOCK_WIDTH_CACHE = tmp_path("sketchybar_dock_width.cache")

local shell_quote = require("helpers.utils").shell_quote

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

local function clear_cache(path)
	os.remove(path)
end

-- fallback: 非刘海外接屏无菜单栏时的兜底
-- 用 Carbon GetMBarHeight (30) 的标准值, 不信实测 31 那 1pt 漂移
local FALLBACK_HEIGHT = 30
local FALLBACK_DOCK_WIDTH = 55

local function cached_bar_height()
	local cached = tonumber(read_cache(BAR_HEIGHT_CACHE))
	if cached and cached > 0 then
		return cached
	end
	return FALLBACK_HEIGHT
end

local function parse_bar_height(output)
	local raw_height = (output or ""):match("^%s*(%d+)%s*$")
	local height = tonumber(raw_height)
	if height and height > 0 then
		write_cache(BAR_HEIGHT_CACHE, tostring(height))
		return height
	end
	if raw_height == "0" then
		-- A valid zero means the menu bar is hidden on a non-notch display. Do
		-- not carry an internal-display notch height across that transition.
		clear_cache(BAR_HEIGHT_CACHE)
		return FALLBACK_HEIGHT
	end
	return cached_bar_height()
end

local function cached_dock_width()
	local width, hidden = (read_cache(DOCK_WIDTH_CACHE) or ""):match("^(%d+)%s+(%d+)$")
	width = tonumber(width)
	hidden = tonumber(hidden)
	if width and width > 0 and hidden then
		return width, hidden
	end
	return FALLBACK_DOCK_WIDTH, 0
end

local function parse_dock_width(output)
	local width, hidden = (output or ""):match("^(%d+)%s+(%d+)")
	width = tonumber(width)
	hidden = tonumber(hidden)
	if width and width > 0 and hidden then
		write_cache(DOCK_WIDTH_CACHE, string.format("%d %d", width, hidden))
		return width, hidden
	end
	return cached_dock_width()
end

local function refresh_helper(path, parser, callback)
	local cfg = os.getenv("CONFIG_DIR")
	if not cfg then
		callback(parser(""))
		return
	end
	require("sketchybar").exec(shell_quote(cfg .. path) .. " 2>/dev/null", function(output)
		callback(parser(output))
	end)
end

return {
	height = cached_bar_height(),
	initial_dock_width = cached_dock_width,
	refresh_bar_height = function(callback)
		refresh_helper("/helpers/bar_height/bin/bar_height", parse_bar_height, callback)
	end,
	refresh_dock_width = function(callback)
		refresh_helper("/helpers/dock_width/bin/dock_width", parse_dock_width, callback)
	end,
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
