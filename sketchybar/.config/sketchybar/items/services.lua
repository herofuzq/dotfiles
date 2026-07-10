-- ========== 通用服务状态灯 ==========
-- Popup 树形布局：树形线+图标+文字都在 label，同字体等宽无偏移。
local sbar = require("sketchybar")
local appearance = require("appearance")
local popup_animation = require("helpers.popup_animation")
local icons = require("icons")
local fonts = require("fonts")
local timing = require("helpers.timing")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find
local config = require("helpers.services.config")

local colors = appearance.colors
local item_config = config.item or {}
local item_name = item_config.name or "services"
local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar")
local sketchybar_bin = find_binary({ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" }, "sketchybar")
local lua_bin = find_binary({ "/opt/homebrew/bin/lua", "/usr/local/bin/lua" }, "lua")
local status_script = config_dir .. "/helpers/services/status.lua"
local control_script = config_dir .. "/helpers/services/control.lua"

local services_item = sbar.add("item", item_name, {
	position = "q", display = "active",
	padding_left = 0, padding_right = 0,
	icon = {
		string = icons.services.docker,
		font = appearance.font_icon_bold(16.0),
		color = colors.green,
		padding_left = 2, padding_right = 4,
	},
	label = {
		string = "0",
		font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 12.0 },
		color = colors.surface1,
		padding_left = 0, padding_right = 2,
	},
	background = { drawing = false, border_width = 0 },
	popup = { align = "center", background = appearance.popup_bg(), blur_radius = 30 },
})

local services_anim = popup_animation.new(services_item, {
	background_color = function()
		return appearance.popup_bg().color
	end,
})

local BTN = {
	start  = { icon = "\u{F04B}", color = colors.green  },
	stop   = { icon = "\u{F04D}", color = colors.red    },
	pause  = { icon = "\u{F04C}", color = colors.yellow  },
	resume = { icon = "\u{F051}", color = colors.green  },
	quit   = { icon = "\u{F011}", color = colors.red    },
}

local PF = fonts.popup
local function pf()
	return { family = PF.text, style = PF.style_map["Bold"], size = PF.size }
end

local tree = { continues = {} }
function tree:prefix(depth, is_last)
	if depth == 0 then return "" end
	local s = ""
	for d = 1, depth - 1 do
		s = s .. (self.continues[d] and "\u{2502}  " or "   ")
	end
	s = s .. (is_last and "\u{2514}\u{2500} " or "\u{251C}\u{2500} ")
	self.continues[depth] = not is_last
	return s
end

local text_rows    = {}
local actions_list = {}
local hover_items  = {}
local status_row   = nil

local function service_key(gid, sid)
	return gid .. "\0" .. sid
end

local function track(item)
	hover_items[#hover_items + 1] = item
	return item
end

-- 文本行：树形线 + 图标 + 空格 + 文字，全在 label
local function text_row(key, depth, is_last, opts)
	local prefix = tree:prefix(depth, is_last)
	local item = track(sbar.add("item", "services.popup." .. key, {
		position = "popup." .. item_name,
		drawing = true, width = 240,
		padding_left = 0, padding_right = 0,
		icon = { drawing = false },
		label = {
			string = prefix .. (opts.icon or "") .. " " .. (opts.label or ""),
			font = pf(),
			color = opts.label_color or colors.text,
			padding_left = 8, padding_right = 14,
		},
		background = { drawing = false, height = 18, border_width = 0 },
	}))
	text_rows[key] = { item = item, prefix = prefix }
	return item
end

-- 按钮行：树形线 + 图标 + 空格 + 文字，全在 label
local function btn_row(btn_id, depth, is_last, action, scope, gid, sid)
	local def = BTN[action] or BTN.start
	local prefix = tree:prefix(depth, is_last)
	local item = track(sbar.add("item", btn_id, {
		position = "popup." .. item_name,
		drawing = true, width = 240,
		padding_left = 0, padding_right = 0,
		icon = { drawing = false },
		label = {
			string = prefix .. def.icon .. " " .. (action:sub(1,1):upper() .. action:sub(2)),
			font = pf(),
			color = def.color,
			padding_left = 8, padding_right = 14,
		},
		background = { drawing = false, height = 18, border_width = 0 },
	}))
	actions_list[#actions_list + 1] = {
		scope = scope, group_id = gid, service_id = sid,
		action = action, row = item,
	}
	return item
end

-- ========== 构建 ==========
text_row("docker", 0, false, {
	icon = icons.services.docker, icon_color = colors.green,
	label = "Docker", label_color = colors.subtext1,
})
btn_row("services.popup.docker.btn.start", 1, false, "start", "docker", nil, nil)
btn_row("services.popup.docker.btn.quit",  1, false, "quit",  "docker", nil, nil)

for gi, group in ipairs(config.groups or {}) do
	local gid = group.id
	local is_last_group = (gi == #(config.groups or {}))

	text_row("group." .. gid, 1, is_last_group, {
		icon = icons.services.docker, icon_color = colors.green,
		label = group.label or gid, label_color = colors.subtext1,
	})
	local ga = { "start", "stop", "pause", "resume" }
	for ai, a in ipairs(ga) do
		btn_row("services.popup.group." .. gid .. ".btn." .. a, 2, ai == #ga, a, "group", gid, nil)
	end
	for si, svc in ipairs(group.services or {}) do
		local is_last_svc = (si == #(group.services or {}))
		text_row(gid .. "." .. svc.id, 2, is_last_svc, {
			icon = "•", icon_color = colors.surface1,
			label = (svc.label or svc.id),
		})
		local sa = { "start", "stop", "pause", "resume" }
		for ai, a in ipairs(sa) do
			btn_row("services.popup." .. gid .. "." .. svc.id .. ".btn." .. a, 3, ai == #sa, a, "service", gid, svc.id)
		end
	end
end

status_row = sbar.add("item", "services.popup.status", {
	position = "popup." .. item_name, drawing = false, width = 240,
	padding_left = 0, padding_right = 0,
	icon = { drawing = false },
	label = { string = "", font = pf(), color = colors.surface1, padding_left = 8, padding_right = 14 },
	background = { drawing = false, height = 18, border_width = 0 },
})
track(status_row)

-- ========== 按钮点击 ==========
local function target_name(entry)
	if entry.scope == "docker" then return "docker" end
	return entry.service_id or entry.group_id or "service"
end

local function cmd(entry)
	local p = { shell_quote(lua_bin), shell_quote(control_script), shell_quote(entry.scope) }
	if entry.scope == "docker" then
		p[#p+1] = shell_quote(entry.action)
	elseif entry.scope == "group" then
		p[#p+1] = shell_quote(entry.group_id); p[#p+1] = shell_quote(entry.action)
	else
		p[#p+1] = shell_quote(entry.group_id); p[#p+1] = shell_quote(entry.service_id); p[#p+1] = shell_quote(entry.action)
	end
	return table.concat(p, " ")
end

local function feedback(item, c)
	local f = math.max(1, math.floor(timing.STANDARD_DURATION_FRAMES / 2))
	sbar.animate("linear", f, function() item:set({ label = { color = colors.overlay0 } }) end)
	sbar.delay(timing.frames_to_seconds(f), function()
		sbar.animate("linear", f, function() item:set({ label = { color = c } }) end)
	end)
end

for _, entry in ipairs(actions_list) do
	local e = entry
	entry.row:subscribe("mouse.clicked", function()
		local c = (BTN[e.action] or BTN.start).color
		feedback(e.row, c)
		status_row:set({ drawing = true, label = { string = e.action .. " " .. target_name(e) .. "...", color = colors.yellow } })
		sbar.exec(cmd(e), function() refresh() end)
	end)
end

-- ========== 状态刷新 ==========
local popup_pinned = false; local popup_hovering = false; local popup_exit_gen = 0
local inflight = false; local pending = false

local function count_color(status, running, total)
	if status == "error" or total <= 0 then return colors.surface1 end
	if running >= total then return colors.green end
	if running > 0 then return colors.yellow end
	return colors.red
end

local function st_color(state)
	if state == "running" then return colors.green end
	if state == "paused" then return colors.yellow end
	if state == "exited" or state == "dead" or state == "missing" then return colors.red end
	return colors.surface1
end

local function st_text(state)
	if state == "running" then return "UP" end
	if state == "paused" then return "PAUSE" end
	if state == "exited" then return "OFF" end
	if state == "missing" then return "MISS" end
	return "ERR"
end

local function spl(line)
	local f = {}; line = line .. "\t"
	for v in line:gmatch("([^\t]*)\t") do f[#f+1] = v end
	return f
end

local function apply_status(output)
	local sum = { status = "error", running = 0, total = 0, message = "services unavailable" }
	local grps, svcs = {}, {}

	for line in tostring(output or ""):gmatch("[^\n]+") do
		local f = spl(line)
		if f[1] == "summary" then
			sum = { status = f[2] or "error", running = tonumber(f[3]) or 0, total = tonumber(f[4]) or 0, message = f[5] or "" }
		elseif f[1] == "group" then
			grps[f[2]] = { label = f[3] or f[2], running = tonumber(f[4]) or 0, total = tonumber(f[5]) or 0 }
		elseif f[1] == "service" then
			svcs[service_key(f[2] or "", f[3] or "")] = { label = f[4] or f[3], state = f[5] or "unknown", port = f[6] or "", status = f[7] or "" }
		end
	end

	services_item:set({ label = { string = tostring(sum.running), color = count_color(sum.status, sum.running, sum.total) } })

	for gid, g in pairs(grps) do
		local entry = text_rows["group." .. gid]
		if entry then
			entry.item:set({ label = { string = entry.prefix .. icons.services.docker .. " " .. string.format("%s  %d/%d", g.label, g.running, g.total), color = colors.subtext1 } })
		end
	end

	for key, s in pairs(svcs) do
		local gid, sid = key:match("^(.-)\0(.*)$")
		local lookup_key = (gid or "") .. "." .. (sid or "")
		local entry = text_rows[lookup_key]
		if entry then
			local port = s.port ~= "" and (" :" .. s.port) or ""
			entry.item:set({ label = { string = entry.prefix .. "• " .. string.format("%s  %s%s", s.label, st_text(s.state), port), color = colors.text } })
		end
	end

	if sum.status == "error" then
		status_row:set({ drawing = true, label = { string = sum.message ~= "" and sum.message or "docker unavailable", color = colors.surface1 } })
	else
		status_row:set({ drawing = false })
	end
end

local function refresh()
	if inflight then pending = true; return end
	inflight = true
	sbar.exec(shell_quote(lua_bin) .. " " .. shell_quote(status_script), function(o)
		inflight = false; apply_status(o)
		if pending then pending = false; refresh() end
	end)
end

-- ========== hover ==========
local function show()
	popup_exit_gen = popup_exit_gen + 1; refresh()
	services_anim:show()
end
local function hide()
	services_anim:hide_async()
end
local function schedule_hide()
	if popup_pinned then return end
	popup_exit_gen = popup_exit_gen + 1; local g = popup_exit_gen
	sbar.delay(timing.POPUP_HIDE_DELAY_S, function()
		if popup_exit_gen ~= g or popup_hovering or popup_pinned then return end
		hide()
	end)
end

services_item:subscribe("mouse.entered", show)
services_item:subscribe("mouse.exited", schedule_hide)
services_item:subscribe("mouse.clicked", function() popup_pinned = not popup_pinned; if popup_pinned then show() else hide() end end)

for _, r in ipairs(hover_items) do
	r:subscribe("mouse.entered", function() popup_exit_gen = popup_exit_gen + 1; popup_hovering = true end)
	r:subscribe("mouse.exited", function() popup_hovering = false; schedule_hide() end)
end

services_item:subscribe({ "services_change", "system_woke" }, refresh)
refresh()

-- 覆盖 popup 行高（bar 默认 ~29px 钳制了 popup item 高度）
services_item:set({ popup = { height = 16 } })

local enter_animation = require("helpers.enter_animation")
enter_animation.register(item_name)
