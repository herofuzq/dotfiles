-- ========== 启动渐入（startup fade）==========
--
-- 仅改颜色 alpha：无 y_offset、不强行 drawing=true、无 stagger。
-- 显式声明的 background color / border_color 也参与，但绝不改 drawing 或几何。
--
-- init.lua 流程（必须在 end_config 和首屏 ready 之后，且顺序不可颠倒）:
--   1) prepare() / conceal() -- 收集目标色并统一归零（bar 仍 hidden）
--   2) startup.reveal()      -- 取消 hidden
--   3) run()                 -- item 一次 animate 渐入
--
-- 登记方式：install() 劫持 sbar.add，记录主条 name 和显式颜色 props。
-- prepare 不再逐项 --query；只处理 add 时显式声明的颜色。
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")

local M = {}

local ITEM_FADE_FRAMES = timing.ENTER_ITEM_FADE_FRAMES or 30
local _names = {} -- 有序 name 列表（install 期间收集）
local _name_set = {}
local _props = {} -- add 时声明的 props；避免启动阶段逐项 --query
local _installed = false
local _closed = false -- prepare 起不再登记
local _pending = {}
local _prepare_ok = false
local apply

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

local function fade_color(color, progress)
	local target_alpha = ((color >> 24) & 0xff) / 255
	return appearance.with_alpha(color, target_alpha * progress)
end

local function track_name(name, props)
	if _closed or should_skip_name(name) or should_skip_props(props) then
		return false
	end
	if _name_set[name] then
		return true
	end
	_name_set[name] = true
	_props[name] = props
	_names[#_names + 1] = name
	return true
end

-- 首屏状态在 bar 隐藏期间可能改变目标色（例如 focused workspace 反色）。
-- 只更新动画快照，不发送额外 IPC；prepare() 后自动失效。
function M.update_target(name, props)
	local target = not _closed and _props[name] or nil
	if type(target) ~= "table" or type(props) ~= "table" then return end
	for _, key in ipairs({ "icon", "label", "background" }) do
		local updates = props[key]
		if type(updates) == "table" then
			local merged = {}
			if type(target[key]) == "table" then
				for k, value in pairs(target[key]) do merged[k] = value end
			end
			for k, value in pairs(updates) do merged[k] = value end
			target[key] = merged
		end
	end
end

local function faded_props(props)
	if type(props) ~= "table" then
		return props
	end

	local copy
	for _, key in ipairs({ "icon", "label" }) do
		local section = props[key]
		local color = type(section) == "table" and parse_color(section.color) or nil
		if color and section.drawing ~= false then
			if not copy then
				copy = {}
				for k, value in pairs(props) do
					copy[k] = value
				end
			end
			local section_copy = {}
			for k, value in pairs(section) do
				section_copy[k] = value
			end
			section_copy.color = fade_color(color, 0)
			copy[key] = section_copy
		end
	end

	local background = props.background
	if type(background) == "table" and background.drawing ~= false then
		local color = parse_color(background.color)
		local border_color = parse_color(background.border_color)
		if color or border_color then
			if not copy then
				copy = {}
				for k, value in pairs(props) do
					copy[k] = value
				end
			end
			local background_copy = {}
			for k, value in pairs(background) do
				background_copy[k] = value
			end
			if color then
				background_copy.color = fade_color(color, 0)
			end
			if border_color then
				background_copy.border_color = fade_color(border_color, 0)
			end
			copy.background = background_copy
		end
	end
	return copy or props
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
		local args = { ... }
		local kind, a, b, c = table.unpack(args)
		local props_index
		local props
		if kind == "bracket" and type(b) == "table" and type(c) == "table" then
			props_index, props = 4, c
		elseif type(b) == "table" then
			props_index, props = 3, b
		end

		local tracked = false
		if type(a) == "string" then
			tracked = props_index and track_name(a, props) or false
		end
		if tracked then
			args[props_index] = faded_props(props)
		end
		return raw_add(table.unpack(args))
	end
end

local function snapshot_item(name)
	local props = _props[name]
	if type(props) ~= "table" then
		return nil
	end

	local icon = type(props.icon) == "table" and props.icon or nil
	local label = type(props.label) == "table" and props.label or nil
	local background = type(props.background) == "table" and props.background or nil
	local background_drawing = background and background.drawing
	local background_visible = background_drawing ~= false and background_drawing ~= "off"

	local entry = {
		name = name,
		icon = icon and icon.drawing ~= false and parse_color(icon.color) or nil,
		label = label and label.drawing ~= false and parse_color(label.color) or nil,
		background = background and background_visible and parse_color(background.color) or nil,
		border = background and background_visible and parse_color(background.border_color) or nil,
	}

	if not entry.icon and not entry.label and not entry.background and not entry.border then
		return nil
	end
	return entry
end

function M.conceal()
	if not _prepare_ok then return end
	for _, entry in ipairs(_pending) do
		apply(entry, 0)
	end
end

apply = function(entry, alpha)
	-- drawing 由组件自身管理。尤其 workspace 创建时默认隐藏，首轮快照再决定
	-- 哪些应显示；动画若恢复 add 时的 drawing=false，会覆盖这份实时状态。
	local props = {}
	if entry.icon then
		props.icon = { color = fade_color(entry.icon, alpha) }
	end
	if entry.label then
		props.label = { color = fade_color(entry.label, alpha) }
	end
	if entry.background or entry.border then
		props.background = {}
		if entry.background then
			props.background.color = fade_color(entry.background, alpha)
		end
		if entry.border then
			props.background.border_color = fade_color(entry.border, alpha)
		end
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

return M
