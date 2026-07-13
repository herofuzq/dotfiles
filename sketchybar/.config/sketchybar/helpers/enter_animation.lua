-- ========== 启动渐隐（startup fade）==========
--
-- 仅改颜色 alpha：无 y_offset、不强行 drawing=true、无 stagger。
--
-- init.lua 流程（必须在 end_config 之后，且顺序不可颠倒）:
--   1) prepare()  -- 使用登记的 icon/label 颜色铺透明（bar 仍 hidden）
--   2) run_bar()  -- 取消 hidden，写出最终 bar 样式
--   3) run()      -- item 一次 animate 渐入
--
-- 登记方式：install() 劫持 sbar.add，记录主条 name 和声明的 icon/label props。
-- prepare 不再逐项 --query；动态运行时设置的 background 不参与启动渐入。
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")

local M = {}

local ITEM_FADE_FRAMES = timing.ENTER_ITEM_FADE_FRAMES or 60
local _names = {} -- 有序 name 列表（install 期间收集）
local _name_set = {}
local _props = {} -- add 时声明的 props；避免启动阶段逐项 --query
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
	_props[name] = props
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

local function snapshot_item(name)
	local props = _props[name]
	if type(props) ~= "table" then
		return nil
	end

	local icon = type(props.icon) == "table" and props.icon or nil
	local label = type(props.label) == "table" and props.label or nil

	local entry = {
		name = name,
		was_drawing = props.drawing ~= false,
		icon = icon and icon.drawing ~= false and parse_color(icon.color) or nil,
		label = label and label.drawing ~= false and parse_color(label.color) or nil,
		-- Background colors are often changed after add() to join a bracket.
		-- Do not animate a stale creation-time value.
		background = nil,
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
		io.stderr:write("sketchybar: enter_animation prepare: no declared item colors, skip fade\n")
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
