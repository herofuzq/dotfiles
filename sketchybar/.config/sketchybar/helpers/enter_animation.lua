-- ========== 启动渐隐（startup fade）==========
--
-- 仅改颜色 alpha：无 y_offset、不强行 drawing=true、无 stagger。
--
-- init.lua 流程（必须在 end_config 之后，且顺序不可颠倒）:
--   1) prepare()  -- query 最终主条状态并铺透明（bar 仍 hidden）
--   2) run_bar()  -- 取消 hidden，写出最终 bar 样式
--   3) run()      -- item 一次 animate 渐入
--
-- 为何 end_config 之后再 snapshot:
--   多个 widget 会在 add 之后 sbar.set 调整 background（并入 bracket）。
--   必须用最终状态，否则会把已关掉的 pill 背景又画回来。
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local M = {}

-- bar 当前为瞬时 unhide（见 run_bar），不用 BAR 帧数；仅 item 走 alpha animate。
local ITEM_FADE_FRAMES = timing.ENTER_ITEM_FADE_FRAMES or 60
local SKETCHYBAR = find_binary(
	{ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" },
	"/opt/homebrew/bin/sketchybar"
)

local _pending = {}
local _prepare_ok = false

-- 名称级排除（popup 子项还会用 position 再滤一层）
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
	-- plain find：第三个参数 true 时不要写 Lua pattern 转义
	if name:find(".cal_", 1, true) or name:find(".process.", 1, true) or name:match("%.info$") then
		return true
	end
	return false
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

local function list_bar_items()
	local raw = cli_query("bar")
	if not raw then
		return nil -- 与 {} 区分：query 失败
	end
	local items_block = raw:match('"items"%s*:%s*(%b[])')
	if not items_block then
		return {}
	end
	local names = {}
	for name in items_block:gmatch('"([^"]+)"') do
		names[#names + 1] = name
	end
	return names
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
	_pending = {}
	_prepare_ok = false

	local names = list_bar_items()
	if names == nil then
		io.stderr:write("sketchybar: enter_animation prepare: bar query failed, skip item fade\n")
		return
	end

	for _, name in ipairs(names) do
		if not should_skip_name(name) then
			local entry = snapshot_item(name)
			if entry then
				_pending[#_pending + 1] = entry
				apply(entry, 0)
			end
		end
	end

	_prepare_ok = true
	if #_pending == 0 then
		io.stderr:write("sketchybar: enter_animation prepare: 0 fade targets (ok if bar empty)\n")
	end
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
	-- 视觉上的「渐入感」主要来自随后 run() 的 item alpha 动画。
	-- 须在 prepare() 之后调用，避免 bar 先可见、item 仍是实色的一帧闪烁。
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
