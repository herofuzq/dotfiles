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
		color = colors.green,
		padding_left = 4, padding_right = 4,
	},
	label = {
		string = "0",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 12.0 },
		color = colors.green,
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

for ri, repo in ipairs(config.repos or {}) do
	local item = sbar.add("item", item_name .. ".popup.repo." .. ri, {
		position = "popup." .. item_name,
		-- Keep the pre-created rows drawable so the first click has popup geometry
		-- before the asynchronous status cache arrives. Later refreshes only render
		-- these rows while the popup is open.
		drawing = true, width = 560,
		padding_left = 0, padding_right = 0,
		icon = { drawing = false },
		label = {
			string = icons.git .. " " .. (repo.label or repo.path),
			font = pf(),
			color = colors.text,
			padding_left = 8, padding_right = 14,
		},
		background = { drawing = false, height = 18, border_width = 0 },
	})
	repo_rows[repo.path] = item
end

local max_label_len = 0
for _, repo in ipairs(config.repos or {}) do
	local l = vlen(repo.label or repo.path)
	if l > max_label_len then max_label_len = l end
end

local function spl(line)
	local f = {}; line = line .. "\t"
	for v in line:gmatch("([^\t]*)\t") do f[#f+1] = v end
	return f
end

local function status_color(status)
	if status == "ok" then return colors.green end
	if status == "dirty" then return colors.yellow end
	return colors.surface1
end

local popup_visible = false
local last_popup_state = { entries = {}, max_branch_len = 0, max_info_len = 0 }
local last_main_signature

local function render_popup(state)
	local seen = {}
	for _, e in ipairs(state.entries) do
		seen[e.path] = true
		local pad_label = e.label .. string.rep(" ", max_label_len - vlen(e.label) + 2)
		local pad_branch = e.branch .. string.rep(" ", state.max_branch_len - vlen(e.branch) + 2)
		local pad_info = e.info .. string.rep(" ", state.max_info_len - vlen(e.info) + 2)
		e.row:set({
			drawing = true,
			label = { string = icons.git .. "  " .. pad_label .. pad_branch .. pad_info .. e.path:gsub("^" .. os.getenv("HOME"), "~"), color = e.color },
		})
	end
	for path, row in pairs(repo_rows) do
		if not seen[path] then
			row:set({ drawing = false })
		end
	end
end

local function apply_status(output, force_main)
	local total_dirty = 0
	local entries, max_branch_len, max_info_len = {}, 0, 0

	for line in tostring(output or ""):gmatch("[^\n]+") do
		local f = spl(line)
		if f[1] == "repo" then
			local path, label, branch, status, dirty, ahead, behind = f[2], f[3], f[4], f[5], f[6], f[7], f[8]
			local row = repo_rows[path]
			if row then
				local color = status_color(status)
				local info

				if status == "ok" then
					info = "clean"
				elseif status == "dirty" then
					info = dirty .. " dirty"
					total_dirty = total_dirty + (tonumber(dirty) or 0)
				elseif status == "error" then
					info = "unavailable"
				else
					info = "missing"
				end

				local a = tonumber(ahead)
				if a and a > 0 then info = info .. "  ↑" .. ahead end
				local b = tonumber(behind)
				if b and b > 0 then info = info .. "  ↓" .. behind end

				entries[#entries + 1] = { row = row, label = label, branch = branch, color = color, info = info, path = path }
				if vlen(branch) > max_branch_len then max_branch_len = vlen(branch) end
				if vlen(info) > max_info_len then max_info_len = vlen(info) end
			end
		end
	end

	local bar_color = total_dirty > 0 and colors.yellow or colors.green
	local main_signature = tostring(total_dirty) .. "|" .. tostring(bar_color)
	if force_main or main_signature ~= last_main_signature then
		last_main_signature = main_signature
		git_item:set({ label = { string = tostring(total_dirty), color = bar_color } })
	end
	last_popup_state = {
		entries = entries,
		max_branch_len = max_branch_len,
		max_info_len = max_info_len,
	}
	if popup_visible then
		render_popup(last_popup_state)
	end
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
	local function finish(output)
		if settled or generation ~= refresh_generation then return end
		settled = true
		inflight = false
		if output ~= nil then
			local force_main = first_status
			first_status = false
			startup.after_reveal("git.status", function() apply_status(output, force_main) end)
		end
		initial_ready()
		if pending then pending = false; refresh() end
	end
	sbar.delay(REFRESH_TIMEOUT, function() finish(nil) end)
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

git_item:subscribe({ "routine", "system_woke" }, refresh)
refresh()

git_item:set({ popup = { height = 16 } })
