local sbar = require("sketchybar")
local appearance = require("appearance")
local icons = require("icons")
local fonts = require("fonts")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find
local config = require("helpers.git.config")
local popup_utils = require("helpers.popup_utils")
local startup = require("helpers.startup")

local vlen = utf8 and utf8.len or function(s)
	local n = 0
	for _, _ in s:gmatch("()[\0-\127]") do n = n + 1 end
	for _, _ in s:gmatch("()[\194-\244][\128-\191]+") do n = n + 1 end
	return n
end

local colors = appearance.colors
local item_name = (config.item or {}).name or "git_status"
local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
local lua_bin = find_binary({ "/opt/homebrew/bin/lua", "/usr/local/bin/lua" }, "lua")
local status_script = config_dir .. "/helpers/git/status.lua"
local initial_ready = startup.track("git.status")

local git_item = sbar.add("item", item_name, {
	position = "e", display = "active",
	update_freq = 120,
	padding_left = 0, padding_right = 0,
	icon = {
		string = icons.git,
		font = appearance.font_icon_bold(16.0),
		color = colors.text,
		padding_left = 4, padding_right = 4,
	},
	label = {
		string = "0",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 12.0 },
		color = colors.status.ok,
		padding_left = 0, padding_right = 2,
	},
	background = { drawing = false, border_width = 0 },
	popup = { align = "center", background = appearance.popup_bg(), blur_radius = 30 },
})

local PF = fonts.popup
local function pf()
	return { family = PF.text, style = PF.style_map["Bold"], size = PF.size }
end

local repo_rows = {}
local repo_specs = {}
local repo_spec_by_path = {}

for ri, repo in ipairs(config.repos or {}) do
	local label = repo.label or repo.path
	local item = sbar.add("item", item_name .. ".popup.repo." .. ri, {
		position = "popup." .. item_name,
		-- Keep the pre-created rows drawable so the first click has popup geometry
		-- before the asynchronous status cache arrives. Later refreshes only render
		-- these rows while the popup is open.
		drawing = true, width = 560,
		padding_left = 0, padding_right = 0,
		icon = { drawing = false },
		label = {
			string = icons.git .. " " .. label,
			font = pf(),
			color = colors.text,
			padding_left = 8, padding_right = 14,
		},
		background = { drawing = false, height = 18, border_width = 0 },
	})
	repo_rows[repo.path] = item
	local spec = { path = repo.path, label = label, row = item }
	repo_specs[#repo_specs + 1] = spec
	repo_spec_by_path[repo.path] = spec
end

local max_label_len = 0
for _, repo in ipairs(repo_specs) do
	local l = vlen(repo.label)
	if l > max_label_len then max_label_len = l end
end

local function spl(line)
	local f = {}; line = line .. "\t"
	for v in line:gmatch("([^\t]*)\t") do f[#f+1] = v end
	return f
end

local function status_color(status)
	if status == "ok" then return colors.status.ok end
	if status == "dirty" then return colors.status.warn end
	return colors.surface1
end

local popup_visible = false
local last_popup_state = { entries = {}, max_branch_len = 0, max_info_len = 0 }
local last_main_signature
local last_total_dirty = 0

local function render_popup(state)
	local seen = {}
	for _, e in ipairs(state.entries) do
		seen[e.path] = true
		local pad_label = e.label .. string.rep(" ", max_label_len - vlen(e.label) + 2)
		local pad_branch = e.branch .. string.rep(" ", state.max_branch_len - vlen(e.branch) + 2)
		local pad_info = e.info .. string.rep(" ", state.max_info_len - vlen(e.info) + 2)
		e.row:set({
			drawing = true,
			label = { string = icons.git .. "  " .. pad_label .. pad_branch .. pad_info .. e.path:gsub("^" .. os.getenv("HOME"), "~"), color = status_color(e.status) },
		})
	end
	for path, row in pairs(repo_rows) do
		if not seen[path] then
			row:set({ drawing = false })
		end
	end
end

local function apply_status(state, force_main)
	local total_dirty = state.total_dirty
	local bar_color = total_dirty > 0 and colors.count or colors.pill_fg -- 计数统一色；干净时普通色
	local icon_color = total_dirty > 0 and colors.status.ok or colors.text -- 图标：有计数绿，无计数普通色
	last_total_dirty = total_dirty
	local main_signature = tostring(total_dirty) .. "|" .. tostring(bar_color) .. "|" .. tostring(icon_color)
	if force_main or main_signature ~= last_main_signature then
		last_main_signature = main_signature
		git_item:set({
			icon = { color = icon_color },
			label = { string = tostring(total_dirty), color = bar_color },
		})
	end
	last_popup_state = state
	if popup_visible then
		render_popup(last_popup_state)
	end
end

local function is_uint(value)
	return type(value) == "string" and value:match("^%d+$") ~= nil
end

local function make_state(entries, total_dirty)
	local max_branch_len, max_info_len = 0, 0
	for _, entry in ipairs(entries) do
		if vlen(entry.branch) > max_branch_len then max_branch_len = vlen(entry.branch) end
		if vlen(entry.info) > max_info_len then max_info_len = vlen(entry.info) end
	end
	return {
		entries = entries,
		max_branch_len = max_branch_len,
		max_info_len = max_info_len,
		total_dirty = total_dirty,
	}
end

local function unavailable_state()
	local entries = {}
	for _, spec in ipairs(repo_specs) do
		entries[#entries + 1] = {
			row = spec.row,
			label = spec.label,
			branch = "-",
			status = "error",
			info = "unavailable",
			path = spec.path,
		}
	end
	return make_state(entries, 0)
end

local function parse_snapshot(output)
	local entries, seen = {}, {}
	local total_dirty = 0
	local text = tostring(output or "")
	if text:sub(-1) == "\n" then text = text:sub(1, -2) end
	if text == "" or text:sub(1, 1) == "\n" or text:sub(-1) == "\n" or text:find("\n\n", 1, true) then return nil end

	for line in (text .. "\n"):gmatch("(.-)\n") do
		local f = spl(line)
		if #f ~= 8 or f[1] ~= "repo" then return nil end

		local path, label, branch, status, dirty, ahead, behind = f[2], f[3], f[4], f[5], f[6], f[7], f[8]
		local spec = repo_spec_by_path[path]
		if path == "" or not spec or seen[path] or label ~= spec.label then return nil end
		seen[path] = true

		local info
		if status == "ok" then
			if branch == "" or branch == "-" or dirty ~= "0" or not is_uint(ahead) or not is_uint(behind) then return nil end
			info = "clean"
		elseif status == "dirty" then
			if branch == "" or branch == "-" or not is_uint(dirty) or tonumber(dirty) <= 0
				or not is_uint(ahead) or not is_uint(behind) then return nil end
			info = dirty .. " dirty"
			total_dirty = total_dirty + tonumber(dirty)
		elseif status == "error" or status == "missing" then
			if branch ~= "-" or dirty ~= "-" or ahead ~= "-" or behind ~= "-" then return nil end
			info = status == "error" and "unavailable" or "missing"
		else
			return nil
		end

		local a = tonumber(ahead)
		if a and a > 0 then info = info .. "  ↑" .. ahead end
		local b = tonumber(behind)
		if b and b > 0 then info = info .. "  ↓" .. behind end

		entries[#entries + 1] = {
			row = spec.row,
			label = spec.label,
			branch = branch,
			status = status,
			info = info,
			path = path,
		}
	end

	if #entries ~= #repo_specs then return nil end
	for _, spec in ipairs(repo_specs) do
		if not seen[spec.path] then return nil end
	end
	return make_state(entries, total_dirty)
end

local inflight = false
local pending = false
local refresh_generation = 0
local REFRESH_TIMEOUT = 8
local first_status = true

local function refresh()
	if inflight then pending = true; return end
	inflight = true
	refresh_generation = refresh_generation + 1
	local generation = refresh_generation
	local settled = false
	local function finish(output, exit_code)
		if settled or generation ~= refresh_generation then return end
		settled = true
		inflight = false
		local state = tonumber(exit_code) == 0 and parse_snapshot(output) or nil
		if not state then state = unavailable_state() end
		local force_main = first_status
		first_status = false
		startup.after_reveal("git.status", function() apply_status(state, force_main) end)
		initial_ready()
		if pending then pending = false; refresh() end
	end
	sbar.delay(REFRESH_TIMEOUT, function() finish(nil, nil) end)
	sbar.exec(shell_quote(lua_bin) .. " " .. shell_quote(status_script), finish)
end

local function show()
	render_popup(last_popup_state)
	refresh()
	local popup_color = appearance.popup_bg().color
	-- Git's popup refreshes several rows on click. Keep its transition local and
	-- direct: the shared controller's nested deferred sets can miss this popup
	-- while SketchyBar is dispatching the originating mouse event.
	git_item:set({
		popup = {
			drawing = true,
			background = { color = appearance.with_alpha(popup_color, 0) },
		},
	})
	sbar.animate("linear", timing.STANDARD_DURATION_FRAMES, function()
		git_item:set({ popup = { background = { color = popup_color } } })
	end)
end
local function hide()
	git_item:set({ popup = { drawing = false } })
end
local function toggle_popup()
	popup_visible = not popup_visible
	-- Popup rows are refreshed on open. Deferring avoids sending those item IPC
	-- updates while SketchyBar is still dispatching the mouse event.
	popup_utils.defer(function()
		if popup_visible then
			show()
		else
			hide()
		end
	end)
end

git_item:subscribe("mouse.clicked", toggle_popup)

-- 显示器拓扑变化渐入前统一关闭 popup（popup 不参与 alpha 遮罩）
git_item:subscribe("display_transition_begin", function()
	if popup_visible then
		popup_visible = false
		hide()
	end
end)

git_item:subscribe({ "routine", "system_woke" }, refresh)
refresh()

git_item:set({ popup = { height = 16 } })

-- ========== 主题热换色：按缓存的 git 状态重涂 ==========
local function apply_colors(C)
	-- 主条：icon 有计数绿、无计数普通色；label dirty>0 用计数统一色，干净时普通色
	local bar_color = last_total_dirty > 0 and C.count or C.pill_fg
	local popup_bg = appearance.popup_bg()
	git_item:set({
		icon = { color = last_total_dirty > 0 and C.status.ok or C.text },
		label = { color = bar_color },
		popup = { background = { color = popup_bg.color, border_color = popup_bg.border_color } },
	})
	-- popup 行颜色（render_popup 同样按 status_color 现算）
	for _, e in ipairs(last_popup_state.entries) do
		e.row:set({ label = { color = status_color(e.status) } })
	end
end
apply_colors(colors)
appearance.register_colors("git", apply_colors)
