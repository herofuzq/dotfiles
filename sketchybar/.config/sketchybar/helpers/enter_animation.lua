-- ========== Bar/Item 启动渐隐（统一、基于最终状态快照）==========
--
-- init.lua:
--   begin_config → items → end_config
--   prepare()  -- query bar 上最终 item（含 sbar.set 补丁后状态）
--   run_bar() / run()  -- 一次 linear alpha 渐入
--
-- 只改颜色 alpha；不改 y_offset；不强行 drawing=true。
-- 只动画「当前 drawing=on」的 icon/label/geometry.background。
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local M = {}

local BAR_FADE_FRAMES = timing.ENTER_BAR_FADE_FRAMES or 30
local ITEM_FADE_FRAMES = timing.ENTER_ITEM_FADE_FRAMES or 60
local SKETCHYBAR = find_binary(
	{ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" },
	"/opt/homebrew/bin/sketchybar"
)

local _pending = {}

local function should_skip_name(name)
	if not name or name == "" then
		return true
	end
	if name == "spaces.root" or name == "aerospace_mode" then
		return true
	end
	if name:find("popup", 1, true) then
		return true
	end
	-- 日历/系统 popup 行不叫 popup，但也不应进主条渐隐
	if name:find("%.cal_", 1, true) or name:find("%.process%.", 1, true) then
		return true
	end
	if name:match("%.info$") then
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
	if not hex then
		return nil
	end
	return tonumber(hex, 16)
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
	if raw == "" then
		return nil
	end
	return raw
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
		return {}
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
	-- 注意: 必须用 geometry 内的 background，不能 match 到 icon.background
	local geo_bg = geometry and geometry:match('"background"%s*:%s*(%b{})')

	local position = block_field(geometry, "position")
	if position and position:find("^popup", 1) then
		return nil
	end

	local item_drawing = block_field(geometry, "drawing")
	local icon_drawing = block_field(icon, "drawing")
	local label_drawing = block_field(label, "drawing")
	local bg_drawing = block_field(geo_bg, "drawing")

	local icon_c = parse_color(block_field(icon, "color"))
	local label_c = parse_color(block_field(label, "color"))
	local bg_c = parse_color(block_field(geo_bg, "color"))

	local entry = {
		name = name,
		was_drawing = is_on(item_drawing),
		icon = is_on(icon_drawing) and icon_c or nil,
		label = is_on(label_drawing) and label_c or nil,
		background = is_on(bg_drawing) and bg_c or nil,
	}

	if not entry.icon and not entry.label and not entry.background then
		return nil
	end
	-- 完全没画在主条上的跳过
	if not entry.was_drawing and not entry.background then
		-- workspace 可能 drawing=off 暂存；若 icon 也在仍可记，但 prepare 不要强行 drawing on
	end
	return entry
end

local function apply(entry, alpha)
	local props = {
		drawing = entry.was_drawing,
	}
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
	for _, name in ipairs(list_bar_items()) do
		if not should_skip_name(name) then
			local entry = snapshot_item(name)
			if entry then
				_pending[#_pending + 1] = entry
				apply(entry, 0)
			end
		end
	end
end

function M.run()
	if #_pending == 0 then
		return
	end
	sbar.animate("linear", ITEM_FADE_FRAMES, function()
		for _, entry in ipairs(_pending) do
			apply(entry, 1)
		end
	end)
end

function M.run_bar()
	sbar.animate("linear", BAR_FADE_FRAMES, function()
		sbar.bar({
			color = appearance.colors.bar_bg,
			border_color = appearance.colors.border,
			border_width = 2,
		})
	end)
end

-- 兼容旧调用（已废弃）
function M.install() end
function M.register() end
function M.spawn() end

return M
