-- ========== aerospace 工作区显示 ==========
-- 通过 aerospace CLI 查询窗口和屏幕信息，动态显示各工作区的应用图标
-- 工作区边框由 borders.lua 动态分配，空工作区隐藏 label、icon 居中
local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local borders = require("helpers.borders")
local popup_animation = require("helpers.popup_animation")
local sbar = require("sketchybar")
local fonts = require("fonts")
local settings = require("settings")
local SPACE_ICONS = { "󰼏", "󰼐", "󰼑", "󰼒", "󰼓", "󰼔" }
local APP_ICON_FONT = "sketchybar-app-font:Regular:14.0"
local EMPTY_APP_FONT = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = fonts.font.size }

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- 始终显示的工作区（即使没有应用也会显示）
-- 注：键名含 U+0332 组合下划线，对应 aerospace 工作区名称，请勿修改
local always_show = {
	["1̲Main"] = true,
	["2̲Sec"] = true,
	["3̲Chat"] = true,
	["4̲Work"] = true,
	["5̲Term"] = true,
	["6̲Play"] = true,
}
-- aerospace 查询命令模板
local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- 用于订阅事件的虚拟根条目（不显示）
local root = sbar.add("item", "spaces.root", { drawing = false })
local workspaces = {} -- 工作区名 → 条目对象的映射
local workspace_order = {} -- 工作区创建顺序（保持显示顺序一致）
local MAX_POPUP_SLOTS = 8
local _popup_items = {} -- { [ws_name] = { item1, ..., item8 } }
local _popup_windows = {} -- { [ws_name] = { {id, app, title}, ... } }
local _popup_pinned = {} -- { [ws_name] = true/false } 记录点击固定状态，固定后鼠标离开不隐藏
local _popup_hovering = {} -- { [ws_name] = true/false } 鼠标当前是否在 popup 子项上
local _popup_exit_gen = {} -- { [ws_name] = gen } 延迟隐藏的代数，进入 popup 时作废旧延迟
local _popup_animations = {}
local _content_anim_gen = {}
local _content_signature = {}
local animations_ready = false
local front_app_generation = 0
local front_app_initialized = false
local front_app_name
local mode_visible = false

local CONTENT_FADE_OUT_FRAMES = 5
local CONTENT_FADE_IN_FRAMES = 8

local function transparent(color)
	return appearance.with_alpha(color, 0)
end

-- aerospace 模式指示器（当前仅在 service 模式下显示 "󰰣" 图标）
local mode_item = sbar.add("item", "aerospace_mode", {
	position = "left",
	padding_left = 0,
	padding_right = 0,
	width = 0,
	icon = { drawing = false },
	background = { drawing = false },
	label = {
		string = "󰰣",
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = 20.0,
		},
		padding_left = 4,
		padding_right = 4,
		color = transparent(appearance.colors.sapphire),
	},
	drawing = false,
})

-- front_app 按需创建，避免重复
local front_app = nil
local function ensure_front_app()
	if front_app then
		return
	end
	front_app = sbar.add("item", "front_app", {
		display = "active",
		updates = true,
		position = "left",
		padding_right = 2,
		padding_left = 2,
		icon = { drawing = false },
		label = {
			font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 14.0 },
			padding_left = 8,
			padding_right = 8,
			align = "center",
			color = appearance.colors.peach,
		},
		background = { drawing = false },
	})
	front_app:subscribe("front_app_switched", function(env)
		local name = env.INFO or ""
		if front_app_name == name then
			return
		end
		front_app_name = name
		front_app_generation = front_app_generation + 1
		local generation = front_app_generation
		if not front_app_initialized then
			front_app_initialized = true
			front_app:set({ label = { string = name } })
			return
		end
		sbar.animate("tanh", CONTENT_FADE_OUT_FRAMES, function()
			front_app:set({
				label = { color = transparent(appearance.colors.peach), y_offset = -2 },
			})
		end)
	sbar.delay(CONTENT_FADE_OUT_FRAMES / 60, function()
			if front_app_generation ~= generation then
				return
			end
			sbar.animate("tanh", CONTENT_FADE_IN_FRAMES, function()
				front_app:set({
					label = { string = name, color = appearance.colors.peach, y_offset = 0 },
				})
			end)
		end)
	end)
end

-- ========== 窗口信息收集 ==========
local focused_workspace_cache
local focused_window_id_cache
local refresh_in_flight = false
local refresh_pending = false
local refresh_schedule_generation = 0
local window_snapshot = {}
local fullscreen_snapshot = {}

-- ========== 公共排序：focused 窗口排最前，其余按 window-id 降序 ==========
-- 注意：
--   - 快照和 popup 都使用 {app, window_id, title}
--   - 比较前统一 tonumber，避免 string/number 类型不一致
--   - window-id 是 macOS 给的 CGWindowID，同一会话内单调递增，跨重启会重置
local function sort_windows_by_focus(wins, focused_window_id)
	local focused_id = tonumber(focused_window_id)
	table.sort(wins, function(a, b)
		local aid = tonumber(a.window_id) or 0
		local bid = tonumber(b.window_id) or 0
		if focused_id then
			if aid == focused_id then
				return bid ~= focused_id
			end
			if bid == focused_id then
				return false
			end
		end
		return aid > bid
	end)
end

local function withWindows(f)
	local results = {
		open_windows = {},
		has_fullscreen = {},
		snapshot_ok = false,
		focused_workspace = focused_workspace_cache,
		focused_window_id = focused_window_id_cache,
		visible_workspaces = nil,
	}
	local pending = focused_workspace_cache and 2 or 3

	local function check_done()
		pending = pending - 1
		if pending == 0 then
			-- 等窗口和工作区查询全部完成后统一排序、渲染。
			for _, wins in pairs(results.open_windows) do
				sort_windows_by_focus(wins, results.focused_window_id)
			end
			f(results)
		end
	end

	local get_windows =
		"aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}%{window-is-fullscreen}%{window-title}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

	sbar.exec(get_windows, function(workspace_and_windows)
		if not workspace_and_windows then
			check_done()
			return
		end
		results.snapshot_ok = true
		local processed_windows = {} -- 去重用：记录已处理的窗口 ID

		for _, entry in ipairs(workspace_and_windows) do
			local workspace_index = entry.workspace
			local app = entry["app-name"]
			local window_id = entry["window-id"]

			if entry["window-is-fullscreen"] then
				results.has_fullscreen[workspace_index] = true
			end

			-- 每个窗口独立统计，允许同一应用多个窗口显示多个图标
			if not processed_windows[window_id] then
				processed_windows[window_id] = true

				if results.open_windows[workspace_index] == nil then
					results.open_windows[workspace_index] = {}
				end

				table.insert(results.open_windows[workspace_index], {
					app = app,
					window_id = window_id,
					title = entry["window-title"],
				})
			end
		end

		-- 排序已挪到 check_done（等所有异步回调结束，确保 focused_window_id 已设上）

		check_done()
	end)

	if not focused_workspace_cache then
		sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
			results.focused_workspace = focused_workspace and focused_workspace:match("^%s*(.-)%s*$") or ""
			focused_workspace_cache = results.focused_workspace
			check_done()
		end)
	end

	sbar.exec(query_visible_workspaces, function(visible_workspaces)
		if not visible_workspaces then
			results.visible_workspaces = {}
		else
			results.visible_workspaces = visible_workspaces
		end
		check_done()
	end)
end

-- ========== 更新单个工作区 ==========
local function app_icon_line(open_windows)
	local icon_line = ""
	for _, win in ipairs(open_windows) do
		local app = win.app
		local lookup = app_icons[app]
		local icon = ((lookup == nil) and app_icons["Default"] or lookup)
		icon_line = icon_line .. icon
	end
	return icon_line
end

local function visible_monitor_id(workspace_index, visible_workspaces)
	for _, vw in ipairs(visible_workspaces) do
		if workspace_index == vw["workspace"] then
			local raw_id = vw["monitor-appkit-nsscreen-screens-id"]
			return raw_id and math.floor(raw_id)
		end
	end
	return nil
end

local function show_empty_workspace(workspace_index, focused_workspace, visible_workspaces)
	local monitor_id = visible_monitor_id(workspace_index, visible_workspaces)
	local properties = {
		drawing = monitor_id ~= nil or workspace_index == focused_workspace or always_show[workspace_index] == true,
		icon = { padding_left = 10, padding_right = 2 },
		label = {
			drawing = true,
			string = "_",
			font = EMPTY_APP_FONT,
			padding_left = 2,
			padding_right = 10,
		},
	}
	if monitor_id then
		properties.display = monitor_id
	end
	workspaces[workspace_index]:set(properties)
end

local function show_workspace_apps(workspace_index, icon_line)
	-- 注：高亮由 root subscribe("aerospace_workspace_change") 立即设置（env.FOCUSED_WORKSPACE），
	-- 此处不重复设置，避免 aerospace CLI 偶尔失败时把高亮误清
	workspaces[workspace_index]:set({
		drawing = true,
		icon = { padding_left = 10, padding_right = 2 },
		label = { drawing = true, string = icon_line, font = APP_ICON_FONT },
	})
end

local function content_signature(open_windows)
	if #open_windows == 0 then
		return "empty"
	end
	local apps = {}
	for _, win in ipairs(open_windows) do
		apps[#apps + 1] = win.app or ""
	end
	table.sort(apps)
	return table.concat(apps, "\0")
end

local function animate_workspace_content(workspace_index, apply_content)
	_content_anim_gen[workspace_index] = (_content_anim_gen[workspace_index] or 0) + 1
	local gen = _content_anim_gen[workspace_index]
	local workspace = workspaces[workspace_index]

	sbar.animate("tanh", CONTENT_FADE_OUT_FRAMES, function()
		workspace:set({
			label = {
				color = transparent(appearance.colors.pill_fg),
				highlight_color = transparent(appearance.colors.red),
				y_offset = -2,
			},
		})
	end)
		sbar.delay(CONTENT_FADE_OUT_FRAMES / 60, function()
		if _content_anim_gen[workspace_index] ~= gen then
			return
		end
		apply_content()
		workspace:set({
			label = {
				color = transparent(appearance.colors.pill_fg),
				highlight_color = transparent(appearance.colors.red),
				y_offset = 2,
			},
		})
		sbar.animate("tanh", CONTENT_FADE_IN_FRAMES, function()
			workspace:set({
				label = {
					color = appearance.colors.pill_fg,
					highlight_color = appearance.colors.red,
					y_offset = 0,
				},
			})
		end)
	end)
end

local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index] or {}
	local signature = content_signature(open_windows)
	local changed = _content_signature[workspace_index] ~= nil
		and _content_signature[workspace_index] ~= signature
	_content_signature[workspace_index] = signature

	local function apply_content()
		if #open_windows == 0 then
			show_empty_workspace(workspace_index, args.focused_workspace, args.visible_workspaces)
		else
			show_workspace_apps(workspace_index, app_icon_line(open_windows))
		end
	end

	if animations_ready and changed then
		animate_workspace_content(workspace_index, apply_content)
	else
		_content_anim_gen[workspace_index] = (_content_anim_gen[workspace_index] or 0) + 1
		apply_content()
		workspaces[workspace_index]:set({
			label = {
				color = appearance.colors.pill_fg,
				highlight_color = appearance.colors.red,
				y_offset = 0,
			},
		})
	end
end

local function set_popup_item_colors(ws_index, icon_color, label_color)
	for i = 1, MAX_POPUP_SLOTS do
		local item = _popup_items[ws_index] and _popup_items[ws_index][i]
		local win = _popup_windows[ws_index] and _popup_windows[ws_index][i]
		if item and win then
			item:set({ icon = { color = icon_color }, label = { color = label_color } })
		end
	end
end

local function show_popup(ws_index, workspace)
	local animation = _popup_animations[ws_index]
	if not animations_ready or not animation then
		workspace:set({ popup = { drawing = true } })
		return
	end
	animation:show()
end

local function hide_popup(ws_index, workspace, animated)
	local animation = _popup_animations[ws_index]
	if not animations_ready or not animation then
		workspace:set({ popup = { drawing = false } })
		return
	end
	animation:hide(animated)
end

local function scheduleHide(ws_index, workspace)
	if _popup_pinned[ws_index] then
		return
	end
	local gen = (_popup_exit_gen[ws_index] or 0) + 1
	_popup_exit_gen[ws_index] = gen
	sbar.delay(0.2, function()
		if _popup_exit_gen[ws_index] ~= gen then
			return
		end
		if _popup_hovering[ws_index] or _popup_pinned[ws_index] then
			return
		end
		hide_popup(ws_index, workspace, true)
	end)
end

-- ========== Popup：展示/切换工作区窗口列表 ==========
-- force_show=true 用于 hover（总是展示，不 toggle），留空则是 toggle（点击切换）
local function togglePopup(ws_index, workspace_item, force_show)
	if not workspace_item then
		return
	end

	local windows = {}
	for _, win in ipairs(window_snapshot[ws_index] or {}) do
		windows[#windows + 1] = {
			id = win.window_id,
			app = win.app or "?",
			title = (win.title and #win.title > 0 and win.title) or win.app or "Untitled",
			window_id = win.window_id,
		}
	end
	sort_windows_by_focus(windows, focused_window_id_cache)

	_popup_windows[ws_index] = {}
	for i, win in ipairs(windows) do
		if i > MAX_POPUP_SLOTS then
			break
		end
		_popup_windows[ws_index][i] = win
	end

	if #windows == 0 then
		for i = 1, MAX_POPUP_SLOTS do
			local item = _popup_items[ws_index] and _popup_items[ws_index][i]
			if item then
				item:set({ drawing = false })
			end
		end
		hide_popup(ws_index, workspace_item, true)
		return
	end

	for other_index, ws in pairs(workspaces) do
		if ws ~= workspace_item then
			hide_popup(other_index, ws, false)
		end
	end
	for i = 1, MAX_POPUP_SLOTS do
		local item = _popup_items[ws_index] and _popup_items[ws_index][i]
		local win = _popup_windows[ws_index][i]
		if item then
			if win then
				item:set({
					drawing = true,
					icon = { string = app_icons[win.app] or app_icons["Default"], color = appearance.colors.pill_fg },
					label = { string = win.title, color = appearance.colors.text },
				})
			else
				item:set({ drawing = false })
			end
		end
	end
	if force_show or _popup_pinned[ws_index] then
		show_popup(ws_index, workspace_item)
	else
		hide_popup(ws_index, workspace_item, true)
	end
end

-- ========== 工作区高亮辅助 ==========
local function set_highlight(ws, is_focused)
	ws:set({ icon = { highlight = is_focused }, label = { highlight = is_focused } })
end

local function distribute_cached_borders(focused_workspace, animated)
	local visible_names = {}
	local fullscreen_idx = {}
	for i, ws_idx in ipairs(workspace_order) do
		visible_names[i] = "workspace." .. ws_idx
		if fullscreen_snapshot[ws_idx] then
			fullscreen_idx[i] = true
		end
	end
	borders.distribute(visible_names, fullscreen_idx, "workspace." .. (focused_workspace or ""), animated)
end

-- ========== 更新所有工作区 + 分段状态 ==========
local function updateWindows()
	if refresh_in_flight then
		refresh_pending = true
		return
	end
	refresh_in_flight = true
	withWindows(function(args)
		if refresh_pending then
			refresh_pending = false
			refresh_in_flight = false
			updateWindows()
			return
		end

		if args.snapshot_ok then
			window_snapshot = args.open_windows
			fullscreen_snapshot = args.has_fullscreen
		else
			args.open_windows = window_snapshot
			args.has_fullscreen = fullscreen_snapshot
		end

		for ws_idx, ws in pairs(workspaces) do
			set_highlight(ws, ws_idx == args.focused_workspace)
		end

		-- 第一步：更新每个工作区的窗口内容
		for workspace_index, _ in pairs(workspaces) do
			updateWindow(workspace_index, args)
		end

		-- 第二步：按创建顺序收集所有「可见」的工作区
		-- 先将 visible_workspaces 列表转为 hash set，避免后续 O(n) 查表
		local visible_ws_set = {}
		for _, vw in ipairs(args.visible_workspaces) do
			visible_ws_set[vw["workspace"]] = true
		end

		local visible = {}
		for _, ws_idx in ipairs(workspace_order) do
			local open = args.open_windows[ws_idx]
			local has_apps = open and #open > 0
			local is_visible = has_apps
				or visible_ws_set[ws_idx]
				or ws_idx == args.focused_workspace
				or always_show[ws_idx]

			if is_visible then
				table.insert(visible, ws_idx)
			end
		end

		-- 第三步：更新焦点/全屏分段样式
		local visible_names = {}
		local fullscreen_idx = {}
		for i, ws_idx in ipairs(visible) do
			visible_names[#visible_names + 1] = "workspace." .. ws_idx
			if args.has_fullscreen[ws_idx] then
				fullscreen_idx[i] = true
			end
		end
		borders.distribute(
			visible_names,
			fullscreen_idx,
			"workspace." .. (args.focused_workspace or ""),
			animations_ready
		)
		refresh_in_flight = false
		animations_ready = true
	end)
end

-- 合并短时间内的多个刷新事件，避免重复执行窗口快照查询。
local function scheduleUpdateWindows(delay)
	refresh_schedule_generation = refresh_schedule_generation + 1
	local scheduled_generation = refresh_schedule_generation
	sbar.delay(delay, function()
		if scheduled_generation == refresh_schedule_generation then
			updateWindows()
		end
	end)
end

-- ========== 多显示器支持：更新工作区所属显示器 ==========
local function updateWorkspaceMonitor()
	local workspace_monitor = {}
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		if not workspaces_and_monitors then
			return
		end
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local raw_id = entry["monitor-appkit-nsscreen-screens-id"]
			local monitor_id = raw_id and math.floor(raw_id)
			workspace_monitor[space_index] = monitor_id
		end
		for workspace_index, _ in pairs(workspaces) do
			workspaces[workspace_index]:set({
				display = workspace_monitor[workspace_index],
			})
		end
	end)
end

-- ========== 初始化：同步查询 + begin_config 批量创建 workspace（性能优化）==========
-- 同步查询 workspace 列表（在 begin_config 内，纳入批量处理）
local f = io.popen(query_workspaces .. " 2>/dev/null")
local raw = f and f:read("*a") or ""
if f then
	f:close()
end

local initial_workspaces = {}
local seen_initial_workspaces = {}
for ws in raw:gmatch('"workspace"%s*:%s*"([^"]+)"') do
	if not seen_initial_workspaces[ws] then
		seen_initial_workspaces[ws] = true
		initial_workspaces[#initial_workspaces + 1] = ws
	end
end

if #initial_workspaces == 0 then
	for ws, _ in pairs(always_show) do
		initial_workspaces[#initial_workspaces + 1] = ws
	end
end

table.sort(initial_workspaces, function(a, b)
	return (tonumber(a:match("^(%d+)")) or 999) < (tonumber(b:match("^(%d+)")) or 999)
end)

for _, ws in ipairs(initial_workspaces) do
	local workspace = sbar.add("item", "workspace." .. ws, {
		background = {
			drawing = false,
			border_width = 0,
		},
		drawing = false,
		padding_left = 0,
		padding_right = 0,
		icon = {
			color = appearance.colors.pill_fg,
			highlight_color = appearance.colors.red,
			font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = 13.0 },
			padding_left = 10,
			padding_right = 2,
			drawing = true,
			string = (SPACE_ICONS[tonumber(ws:match("^(%d)"))] or ws) .. " >",
		},
		label = {
			color = appearance.colors.pill_fg,
			highlight_color = appearance.colors.red,
			font = APP_ICON_FONT,
			padding_left = 2,
			padding_right = 10,
			y_offset = 0,
			drawing = true,
		},
		popup = {
			align = "left",
			background = {
				color = appearance.colors.pill_bg,
				corner_radius = 10,
				border_width = 2,
				border_color = appearance.colors.border,
				shadow = { drawing = false },
			},
			blur_radius = 30,
		},
	})

	workspaces[ws] = workspace
	table.insert(workspace_order, ws)

	_popup_items[ws] = {}
	for i = 1, MAX_POPUP_SLOTS do
		local popup_item = sbar.add("item", "workspace." .. ws .. ".popup." .. i, {
			position = "popup.workspace." .. ws,
			drawing = false,
			icon = {
				font = "sketchybar-app-font:Regular:14.0",
				padding_left = 12,
				padding_right = 6,
				color = appearance.colors.pill_fg,
			},
			label = {
				font = { family = fonts.font.text, style = fonts.font.style_map["Semibold"], size = 13.0 },
				padding_left = 0,
				padding_right = 16,
				max_chars = 50,
				color = appearance.colors.text,
			},
			background = { drawing = false, border_width = 0 },
		})
		_popup_items[ws][i] = popup_item
	end
	local workspace_index = ws
	_popup_animations[workspace_index] = popup_animation.new(workspace, {
		on_prepare_show = function()
			set_popup_item_colors(
				workspace_index,
				transparent(appearance.colors.pill_fg),
				transparent(appearance.colors.text)
			)
		end,
		on_show = function()
			set_popup_item_colors(workspace_index, appearance.colors.pill_fg, appearance.colors.text)
		end,
		on_hide = function()
			set_popup_item_colors(
				workspace_index,
				transparent(appearance.colors.pill_fg),
				transparent(appearance.colors.text)
			)
		end,
	})
end

local workspace_names = {}
for _, ws in ipairs(workspace_order) do
	workspace_names[#workspace_names + 1] = "workspace." .. ws
end

sbar.add("bracket", "workspaces.bracket", workspace_names, {
	position = "left",
	padding_left = 2,
	padding_right = 2,
	background = {
		color = appearance.colors.pill_bg,
		height = borders.workspace_style.bracket_height,
		corner_radius = borders.workspace_style.bracket_radius,
		border_width = borders.workspace_style.bracket_border_width,
		border_color = appearance.colors.border,
	},
})

-- front_app 在 begin_config 中直接创建（不依赖 aerospace 回调）
ensure_front_app()

-- 事件订阅 + 初始化（在 end_config 后延迟执行）
sbar.exec(":", function()
	for _, ws in ipairs(workspace_order) do
		local w = workspaces[ws]

		w:subscribe("mouse.entered", function()
			_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
			togglePopup(ws, w, true)
		end)
		w:subscribe("mouse.exited", function()
			scheduleHide(ws, w)
		end)
		w:subscribe("mouse.exited.global", function()
			_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
			if not _popup_pinned[ws] then
				hide_popup(ws, w, true)
			end
		end)
		w:subscribe("mouse.clicked", function()
			sbar.exec("aerospace list-workspaces --focused", function(focused)
				focused = focused and focused:match("^%s*(.-)%s*$")
				if focused == ws then
					_popup_pinned[ws] = not _popup_pinned[ws]
					togglePopup(ws, w)
				else
					for k, _ in pairs(_popup_pinned) do
						_popup_pinned[k] = false
					end
					sbar.exec("aerospace workspace " .. shell_quote(ws))
				end
			end)
		end)

		for i = 1, MAX_POPUP_SLOTS do
			local pi = _popup_items[ws][i]
			pi:subscribe("mouse.entered", function()
				_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
				_popup_hovering[ws] = true
				pi:set({ icon = { color = appearance.colors.red }, label = { color = appearance.colors.red } })
			end)
			pi:subscribe("mouse.exited", function()
				_popup_hovering[ws] = false
				pi:set({ icon = { color = appearance.colors.pill_fg }, label = { color = appearance.colors.text } })
				scheduleHide(ws, w)
			end)
			pi:subscribe("mouse.clicked", function()
				local win = _popup_windows[ws] and _popup_windows[ws][i]
				if win then
					local win_id = tostring(win.id):match("^%d+$")
					if win_id then
						sbar.exec("aerospace focus --window-id " .. win_id)
					end
					hide_popup(ws, w, true)
				end
			end)
		end
	end

	-- 首次加载立即同步当前窗口快照。
	updateWindows()
	updateWorkspaceMonitor()

	-- aerospace_workspace_change
	root:subscribe("aerospace_workspace_change", function(env)
		ensure_front_app()
		local focused = env.FOCUSED_WORKSPACE
		if focused then
			focused_workspace_cache = focused
			for k, _ in pairs(_popup_pinned) do _popup_pinned[k] = false end
			for k, _ in pairs(_popup_hovering) do _popup_hovering[k] = false end
			for ws_idx, ws in pairs(workspaces) do
				set_highlight(ws, ws_idx == focused)
			end
			-- 使用已有快照一次性清除旧背景并点亮当前工作区，不触发窗口查询。
			distribute_cached_borders(focused, animations_ready)
		end
	end)

	root:subscribe("space_windows_change", function()
		scheduleUpdateWindows(0.1)
	end)

	-- 焦点变化只重排已有快照，不再调用 AeroSpace 窗口枚举。
	root:subscribe("window_focus_change", function(env)
		local focused_id = tonumber(env.FOCUSED_WINDOW_ID)
		if not focused_id then
			return
		end
		focused_window_id_cache = focused_id
		for workspace_index, wins in pairs(window_snapshot) do
			local contains_focused_window = false
			for _, win in ipairs(wins) do
				if tonumber(win.window_id) == focused_id then
					contains_focused_window = true
					break
				end
			end
			if contains_focused_window and workspaces[workspace_index] then
				sort_windows_by_focus(wins, focused_id)
				show_workspace_apps(workspace_index, app_icon_line(wins))
				break
			end
		end
	end)

	-- 显示器变化/唤醒：同步 bar、自动显隐区域与工作区所属屏幕
	root:subscribe({ "display_change", "system_woke" }, function()
		local h = settings.detect_bar_height(true)
		sbar.bar({ height = h })
		settings.ensure_toggle(h)
		updateWorkspaceMonitor()
		scheduleUpdateWindows(1.0)
	end)

	-- 全屏状态由完整窗口查询统一同步，避免同一事件重复查询窗口列表。
	root:subscribe("aerospace_fullscreen_change", function()
		updateWindows()
	end)

	-- aerospace_mode_change
	root:subscribe("aerospace_mode_change", function(_)
		sbar.exec("aerospace list-modes --current", function(result)
			local is_service = (result or ""):match("service") ~= nil
			if mode_visible == is_service then
				return
			end
			mode_visible = is_service
			if is_service then
				mode_item:set({
					drawing = true,
					width = 0,
					padding_left = 0,
					padding_right = 0,
					label = { color = transparent(appearance.colors.sapphire) },
				})
			end
			sbar.animate("tanh", 8, function()
				mode_item:set({
					width = is_service and "dynamic" or 0,
					padding_left = is_service and 2 or 0,
					padding_right = is_service and 2 or 0,
					label = {
						color = is_service and appearance.colors.sapphire
							or transparent(appearance.colors.sapphire),
					},
				})
			end)
		end)
	end)

	-- theme_changed
	root:subscribe("theme_changed", function()
		for _, ws_idx in ipairs(workspace_order) do
			local ws = workspaces[ws_idx]
			if ws then
				ws:set({
					icon = { color = appearance.colors.pill_fg },
					label = { color = appearance.colors.pill_fg },
					popup = { background = { color = appearance.with_alpha(appearance.colors.pill_bg, 0.85) } },
				})
			end
		end
		sbar.set("workspaces.bracket", {
			background = { color = appearance.colors.pill_bg, border_color = appearance.colors.border },
		})
		for _, items in pairs(_popup_items) do
			for _, item in ipairs(items) do
				if item then
					item:set({
						icon = { color = appearance.colors.pill_fg },
						label = { color = appearance.colors.text },
					})
				end
			end
		end
		sbar.set("aerospace_mode", { label = { color = appearance.colors.sapphire } })

		-- 主题变化只需重绘现有分段，不重新枚举窗口。
		distribute_cached_borders(focused_workspace_cache)
	end)

	-- 初始 focus
	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		if not focused_workspace then
			return
		end
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		focused_workspace_cache = focused_workspace
		if workspaces[focused_workspace] then
			for ws_idx, ws in pairs(workspaces) do
				set_highlight(ws, ws_idx == focused_workspace)
			end
			distribute_cached_borders(focused_workspace)
		end
	end)
end)
