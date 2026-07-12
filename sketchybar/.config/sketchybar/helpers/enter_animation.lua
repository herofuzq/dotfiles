-- ========== 启动渐隐（startup fade）==========
--
-- 仅改颜色 alpha：无 y_offset、不强行 drawing=true、无 stagger。
--
-- init.lua 流程（必须在 end_config 之后，且顺序不可颠倒）:
--   1) prepare()  -- 对登记的主条 item query 最终色并铺透明（bar 仍 hidden）
--   2) run_bar()  -- 取消 hidden，写出最终 bar 样式
--   3) run()      -- item 一次 animate 渐入
--
-- 登记方式：install() 劫持 sbar.add，只记主条 name（不记颜色）。
-- prepare 只 query 这些 name，避免 --query bar 拉出上百 popup 再过滤。
-- 颜色仍 end_config 后 query：因为 add 之后还有 sbar.set 关 bg 并入 bracket。
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local M = {}

local ITEM_FADE_FRAMES = timing.ENTER_ITEM_FADE_FRAMES or 60
local SKETCHYBAR = find_binary(
	{ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" },
	"/opt/homebrew/bin/sketchybar"
)

local _names = {} -- 有序 name 列表（install 期间收集）
local _name_set = {}
local _installed = false
local _closed = false -- prepare 起不再登记
local _pending = {}
local _prepare_ok = false

local SKIP_NAMES = {
	["spaces.root"] = true,
	["aerospace_mode"] = true,
}

local function should_skip_name(name)
	if not name or name == "" or SKIP_NAMES[name] then
		return true
	end
	if name:find("popup", 1, true) then
		return true
	end
	if name:find(".cal_", 1, true) or name:find(".process.", 1, true) or name:match("%.info$") then
		return true
	end
	return false
end

local function should_skip_props(props)
	if type(props) ~= "table" then
		return false
	end
	local pos = props.position
	return type(pos) == "string" and pos:find("^popup", 1) ~= nil
end

local function track_name(name, props)
	if _closed or should_skip_name(name) or should_skip_props(props) then
		return
	end
	if _name_set[name] then
		return
	end
	_name_set[name] = true
	_names[#_names + 1] = name
end

-- 在任何 sbar.add 之前调用（init.lua begin_config 前）
function M.install()
	if _installed then
		return
	end
	_installed = true
	local raw_add = sbar.add
	-- 必须用 ... 原样转发。若 3 参 add 却传入 nil 第 4 参，SbarLua 会误解析，
	-- popup item 丢失 position，全部铺到主条上。
	sbar.add = function(...)
		local item = raw_add(...)
		local kind, a, b, c = ...
		if type(a) == "string" then
			if kind == "bracket" and type(b) == "table" and type(c) == "table" then
				track_name(a, c)
			elseif type(b) == "table" then
				track_name(a, b)
			end
		end
		return item
	end
end

local function parse_color(value)
	if type(value) == "number" then
		return value
	end
	if type(value) ~= "string" or value == "" or value == "(null)" then
		return nil
	end
	local hex = value:match("^0x(%x+)$") or value:match("^(%x+)$")
	return hex and tonumber(hex, 16) or nil
end

local function is_on(value)
	return value == true or value == "on" or value == "true" or value == 1
end

local function cli_query(name)
	local f = io.popen(shell_quote(SKETCHYBAR) .. " --query " .. shell_quote(name) .. " 2>/dev/null")
	if not f then
		return nil
	end
	local raw = f:read("*a") or ""
	f:close()
	return (raw ~= "" and raw) or nil
end

local function block_field(block, key)
	if not block then
		return nil
	end
	return block:match('"' .. key .. '"%s*:%s*"([^"]*)"')
		or block:match('"' .. key .. '"%s*:%s*([%d%.]+)')
end

local function snapshot_item(name)
	local raw = cli_query(name)
	if not raw then
		return nil
	end

	local geometry = raw:match('"geometry"%s*:%s*(%b{})')
	local icon = raw:match('"icon"%s*:%s*(%b{})')
	local label = raw:match('"label"%s*:%s*(%b{})')
	local geo_bg = geometry and geometry:match('"background"%s*:%s*(%b{})')

	local position = block_field(geometry, "position")
	if position and position:find("^popup", 1) then
		return nil
	end

	local entry = {
		name = name,
		was_drawing = is_on(block_field(geometry, "drawing")),
		icon = is_on(block_field(icon, "drawing")) and parse_color(block_field(icon, "color")) or nil,
		label = is_on(block_field(label, "drawing")) and parse_color(block_field(label, "color")) or nil,
		background = is_on(block_field(geo_bg, "drawing")) and parse_color(block_field(geo_bg, "color")) or nil,
	}

	if not entry.icon and not entry.label and not entry.background then
		return nil
	end
	return entry
end

local function apply(entry, alpha)
	local props = { drawing = entry.was_drawing }
	if entry.icon then
		props.icon = { color = appearance.with_alpha(entry.icon, alpha) }
	end
	if entry.label then
		props.label = { color = appearance.with_alpha(entry.label, alpha) }
	end
	if entry.background then
		props.background = { color = appearance.with_alpha(entry.background, alpha) }
	end
	sbar.set(entry.name, props)
end

function M.prepare()
	_closed = true
	_pending = {}
	_prepare_ok = false

	if #_names == 0 then
		io.stderr:write("sketchybar: enter_animation prepare: no tracked items (install missing?)\n")
		return
	end

	local ok_any = false
	for _, name in ipairs(_names) do
		local entry = snapshot_item(name)
		if entry then
			ok_any = true
			_pending[#_pending + 1] = entry
			apply(entry, 0)
		end
	end

	if not ok_any then
		io.stderr:write("sketchybar: enter_animation prepare: all item queries failed, skip fade\n")
		return
	end

	_prepare_ok = true
end

function M.run()
	if not _prepare_ok or #_pending == 0 then
		return
	end
	sbar.animate("linear", ITEM_FADE_FRAMES, function()
		for _, entry in ipairs(_pending) do
			apply(entry, 1)
		end
	end)
end

function M.run_bar()
	-- 配置期 bar 为 hidden；此处瞬时 unhide（不是 color alpha 渐入）。
	-- 须在 prepare() 之后调用。
	local settings = require("settings")
	local h = settings.detect_bar_height()
	if h and h > 0 then
		settings.height = h
	end
	sbar.bar({
		hidden = "off",
		height = settings.height,
		color = appearance.colors.bar_bg,
		border_color = appearance.colors.border,
		border_width = 2,
		blur_radius = 15,
	})
end

return M
