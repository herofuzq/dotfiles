local sbar = require("sketchybar")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local icons = require("icons")
local fonts = require("fonts")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find
local config = require("helpers.git.config")

local colors = appearance.colors
local item_name = (config.item or {}).name or "git_status"
local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
local sketchybar_bin = find_binary({ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" }, "sketchybar")
local lua_bin = find_binary({ "/opt/homebrew/bin/lua", "/usr/local/bin/lua" }, "lua")
local status_script = config_dir .. "/helpers/git/status.lua"

local git_item = sbar.add("item", item_name, {
	position = "e", display = "active",
	update_freq = 60,
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

local git_anim = popup_animation.new(git_item, {
	background_color = function()
		return appearance.popup_bg().color
	end,
})

local PF = fonts.popup
local function pf()
	return { family = PF.text, style = PF.style_map["Bold"], size = PF.size }
end

local hover_items = {}

local function track(item)
	hover_items[#hover_items + 1] = item
	return item
end

local repo_rows = {}

for ri, repo in ipairs(config.repos or {}) do
	local item = track(sbar.add("item", item_name .. ".popup.repo." .. ri, {
		position = "popup." .. item_name,
		drawing = true, width = 300,
		padding_left = 0, padding_right = 0,
		icon = { drawing = false },
		label = {
			string = icons.git .. " " .. (repo.label or repo.path),
			font = pf(),
			color = colors.text,
			padding_left = 8, padding_right = 14,
		},
		background = { drawing = false, height = 18, border_width = 0 },
	}))
	repo_rows[repo.path] = item
end

local max_label_len = 0
for _, repo in ipairs(config.repos or {}) do
	local l = #(repo.label or repo.path)
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

local function apply_status(output)
	local total_dirty = 0
	local entries, max_branch_len = {}, 0

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
				else
					info = "missing"
				end

				local a = tonumber(ahead)
				if a and a > 0 then info = info .. "  ↑" .. ahead end
				local b = tonumber(behind)
				if b and b > 0 then info = info .. "  ↓" .. behind end

				entries[#entries + 1] = { row = row, label = label, branch = branch, color = color, info = info }
				if #branch > max_branch_len then max_branch_len = #branch end
			end
		end
	end


	for _, e in ipairs(entries) do
		local pad_label = e.label .. string.rep(" ", max_label_len - #e.label + 2)
		local pad_branch = e.branch .. string.rep(" ", max_branch_len - #e.branch + 2)
		e.row:set({ label = { string = icons.git .. "  " .. pad_label .. pad_branch .. e.info, color = e.color } })
	end

	local bar_color = total_dirty > 0 and colors.yellow or colors.green
	git_item:set({ label = { string = tostring(total_dirty), color = bar_color } })
end

local inflight = false; local pending = false

local function refresh()
	if inflight then pending = true; return end
	inflight = true
	sbar.exec(shell_quote(lua_bin) .. " " .. shell_quote(status_script), function(o)
		inflight = false; apply_status(o)
		if pending then pending = false; refresh() end
	end)
end

local popup_pinned = false; local popup_hovering = false; local popup_exit_gen = 0

local function show()
	popup_exit_gen = popup_exit_gen + 1; refresh()
	git_anim:show()
end
local function hide()
	git_anim:hide_async()
end
local function schedule_hide()
	if popup_pinned then return end
	popup_exit_gen = popup_exit_gen + 1; local g = popup_exit_gen
	sbar.delay(timing.POPUP_HIDE_DELAY_S, function()
		if popup_exit_gen ~= g or popup_hovering or popup_pinned then return end
		hide()
	end)
end

git_item:subscribe("mouse.entered", show)
git_item:subscribe("mouse.exited", schedule_hide)
git_item:subscribe("mouse.clicked", function() popup_pinned = not popup_pinned; if popup_pinned then show() else hide() end end)

for _, r in ipairs(hover_items) do
	r:subscribe("mouse.entered", function() popup_exit_gen = popup_exit_gen + 1; popup_hovering = true end)
	r:subscribe("mouse.exited", function() popup_hovering = false; schedule_hide() end)
end

git_item:subscribe("system_woke", refresh)
refresh()

git_item:set({ popup = { height = 16 } })

local enter_animation = require("helpers.enter_animation")
enter_animation.register(item_name)
