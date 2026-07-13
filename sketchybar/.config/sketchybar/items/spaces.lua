-- ========== AeroSpace 工作区显示 ==========
-- 这个模块只负责 SketchyBar UI 渲染：工作区编号、窗口图标、焦点分段和窗口 popup。
--
-- 数据流：
--   1. AeroSpace / SketchyBar 事件只负责“提醒有变化”；
--   2. 本模块收到需要刷新窗口内容的事件后，再查询一次 AeroSpace 完整快照；
--   3. 边框和图标都基于同一份快照重画，避免 Swift helper 和 Lua 各维护一份 UI 状态。
--
-- 性能原则：
--   - 工作区焦点变化只更新缓存和边框，不做完整窗口查询；
--   - 窗口创建/销毁、全屏状态变化、显示器变化才刷新窗口快照。
local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local borders = require("helpers.borders")
local popup_animation = require("helpers.popup_animation")
local timing = require("helpers.timing")
local sbar = require("sketchybar")
local fonts = require("fonts")
local settings = require("settings")
local SPACE_ICONS = { "󰼏", "󰼐", "󰼑", "󰼒", "󰼓", "󰼔" }
-- nf-cod-screen_full：用在工作区编号左侧，表示该工作区里有 macOS fullscreen 窗口。
local FULLSCREEN_ICON = ""
local APP_ICON_FONT = "sketchybar-app-font:Regular:14.0"
local EMPTY_APP_FONT = appearance.font_label_bold()
local REFRESH_TIMEOUT = 3.0
local WINDOW_REFRESH_DELAY_DEFAULT = 0.30
local WINDOW_REFRESH_DELAY_CREATED = 0.30
local WINDOW_REFRESH_DELAY_DESTROYED = 0.05

local shell_quote = require("helpers.utils").shell_quote

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
local _popup_cached_gen = {} -- { [ws_name] = snapshot_generation } popup 数据缓存版本号
local _border_signature
local animations_ready = false
local front_app_generation = 0
local front_app_initialized = false
local front_app_name
local mode_visible = false
local mode_generation = 0

-- 内容切换动画帧数:统一规范，跟随 timing.lua 的标准 fade 时长。
-- Workspace app 图标是一整串 label；内容变化时直接切换到最终反显色，
-- 避免高亮背景上的 alpha 过渡看起来像闪烁。
-- UI 反馈类动画(apple click、media button click)另算，不是入场动画。
local CONTENT_FADE_FRAMES = timing.STANDARD_DURATION_FRAMES

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
			font = appearance.font_label_bold(14.0),
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
		sbar.animate("linear", CONTENT_FADE_FRAMES, function()
			front_app:set({
				label = { color = transparent(appearance.colors.peach) },
			})
		end)
		sbar.delay(timing.frames_to_seconds(CONTENT_FADE_FRAMES), function()
			if front_app_generation ~= generation then
				return
			end
			front_app:set({
				label = { string = name, color = transparent(appearance.colors.peach) },
			})
			sbar.animate("linear", CONTENT_FADE_FRAMES, function()
				front_app:set({
					label = { color = appearance.colors.peach },
				})
			end)
		end)
	end)
end

-- ========== 窗口信息收集 ==========
local focused_workspace_cache
local refresh_in_flight = false
local refresh_pending = false
local refresh_pending_protect_empty_snapshot = false
local refresh_schedule_generation = 0
local refresh_generation = 0
local display_sync_generation = 0
local window_snapshot = {}
local snapshot_generation = 0   -- 窗口快照版本号，用于 popup 数据缓存去重

-- ========== 公共排序：按创建时间倒序 ==========
-- 注意：
--   - 快照和 popup 都使用 {app, window_id, title}
--   - 比较前统一 tonumber，避免 string/number 类型不一致
--   - window-id 是 macOS 给的 CGWindowID，同一会话内单调递增，跨重启会重置
--   - id 大 = 创建晚，所以按 id 降序就是按创建时间倒序（最新创建的排最前）
--   - 主条只做工作区级高亮，不按 focus 窗口单独标 app 图标
local function sort_windows_by_creation(wins)
	table.sort(wins, function(a, b)
		return (tonumber(a.window_id) or 0) > (tonumber(b.window_id) or 0)
	end)
end

-- 统一采集本次渲染所需的 AeroSpace 状态。
--
-- 这里仍然走 Lua 的 `sbar.exec`，因为它拿的是完整窗口快照，
-- 并且会和 SketchyBar 原生 `space_windows_change` 事件配合。
-- Swift `aerospace_watch` 只做轻量触发和 fullscreen diff，不直接传 UI 数据。
local function withWindows(f)
	local results = {
		open_windows = {},
		snapshot_ok = false,
		focused_workspace = focused_workspace_cache,
		visible_workspaces = {},
	}
	local pending = focused_workspace_cache and 2 or 3
	local completed = false

	local function check_done()
		pending = pending - 1
		if pending == 0 and not completed then
			completed = true
			for _, wins in pairs(results.open_windows) do
				sort_windows_by_creation(wins)
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

			-- 快照保留窗口粒度：主条按 app 去重渲染，popup 仍按窗口逐个显示。
			if not processed_windows[window_id] then
				processed_windows[window_id] = true

				if results.open_windows[workspace_index] == nil then
					results.open_windows[workspace_index] = {}
				end

				table.insert(results.open_windows[workspace_index], {
					app = app,
					window_id = window_id,
					is_fullscreen = entry["window-is-fullscreen"] == true,
					title = entry["window-title"],
				})
			end
		end

		-- 排序已挪到 check_done（等所有异步回调结束）

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
	local seen_apps = {}
	for _, win in ipairs(open_windows) do
		local app = win.app or "Default"
		if not seen_apps[app] then
			seen_apps[app] = true
			local lookup = app_icons[app]
			local icon = ((lookup == nil) and app_icons["Default"] or lookup)
			icon_line = icon_line .. icon
		end
	end
	return icon_line
end

local function workspace_has_fullscreen(open_windows)
	for _, win in ipairs(open_windows or {}) do
		if win.is_fullscreen then
			return true
		end
	end
	return false
end

-- 工作区级 fullscreen 标记。之前标在 app 图标上，但 fullscreen 后工作区通常只剩
-- 这个窗口，所以标在工作区编号旁更稳定，也不会改动 app icon 字符串。
local function workspace_icon_string(workspace_index, has_fullscreen)
	local icon = SPACE_ICONS[tonumber(tostring(workspace_index):match("^(%d)"))] or workspace_index
	if has_fullscreen then
		return FULLSCREEN_ICON .. " " .. icon .. " >"
	end
	return icon .. " >"
end

local function snapshot_is_empty(snapshot)
	for _, wins in pairs(snapshot) do
		if #wins > 0 then
			return false
		end
	end
	return true
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

local function show_empty_workspace(workspace_index, focused_workspace, visible_workspaces, label_color)
	local monitor_id = visible_monitor_id(workspace_index, visible_workspaces)
	local label = {
		drawing = true,
		string = "_",
		font = EMPTY_APP_FONT,
		padding_left = 2,
		padding_right = 10,
	}
	if label_color then
		label.color = label_color
		label.highlight_color = label_color
	end
	local properties = {
		drawing = monitor_id ~= nil or workspace_index == focused_workspace or always_show[workspace_index] == true,
		icon = {
			padding_left = 10,
			padding_right = 2,
			string = workspace_icon_string(workspace_index, false),
		},
		label = label,
	}
	if monitor_id then
		properties.display = monitor_id
	end
	workspaces[workspace_index]:set(properties)
end

local function show_workspace_apps(workspace_index, icon_line, has_fullscreen, label_color)
	-- 注：高亮由 root subscribe("aerospace_workspace_change") 立即设置（env.FOCUSED_WORKSPACE），
	-- 此处不重复设置，避免 aerospace CLI 偶尔失败时把高亮误清
	local label = { drawing = true, string = icon_line, font = APP_ICON_FONT }
	if label_color then
		label.color = label_color
		label.highlight_color = label_color
	end
	workspaces[workspace_index]:set({
		drawing = true,
		icon = {
			padding_left = 10,
			padding_right = 2,
			string = workspace_icon_string(workspace_index, has_fullscreen),
		},
		label = label,
	})
end

local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index] or {}

	local function apply_content(label_color)
		if #open_windows == 0 then
			show_empty_workspace(workspace_index, args.focused_workspace, args.visible_workspaces, label_color)
		else
			show_workspace_apps(workspace_index, app_icon_line(open_windows), workspace_has_fullscreen(open_windows), label_color)
		end
	end

	local is_focused = args.focused_workspace == workspace_index
	local final_color = is_focused and appearance.colors.crust or appearance.colors.pill_fg
	apply_content(final_color)
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

local function hide_popup_async(ws_index, workspace)
	local animation = _popup_animations[ws_index]
	if animations_ready and animation and animation.hide_async then
		animation:hide_async()
		return
	end
	workspace:set({ popup = { drawing = false } })
end

local function scheduleHide(ws_index, workspace)
	if _popup_pinned[ws_index] then
		return
	end
	local gen = (_popup_exit_gen[ws_index] or 0) + 1
	_popup_exit_gen[ws_index] = gen
	sbar.delay(timing.POPUP_HIDE_DELAY_S, function()
		if _popup_exit_gen[ws_index] ~= gen then
			return
		end
		if _popup_hovering[ws_index] or _popup_pinned[ws_index] then
			return
		end
		hide_popup_async(ws_index, workspace)
	end)
end

-- ========== Popup：展示/切换工作区窗口列表 ==========
-- force_show=true 用于 hover（总是展示，不 toggle），留空则是 toggle（点击切换）
local function togglePopup(ws_index, workspace_item, force_show)
	if not workspace_item then
		return
	end

	-- 快照未变化时复用缓存，避免每次 hover 都重建完整窗口表（大工作区 >20 窗口场景收益明显）
	local windows
	if _popup_cached_gen[ws_index] == snapshot_generation and _popup_windows[ws_index] then
		-- 缓存命中：从 _popup_windows 还原 windows（仅用于空判断，O(MAX_POPUP_SLOTS) 可忽略）
		windows = {}
		for i = 1, MAX_POPUP_SLOTS do
			local w = _popup_windows[ws_index][i]
			if w then windows[#windows + 1] = w end
		end
	else
		_popup_cached_gen[ws_index] = snapshot_generation
		windows = {}
		for _, win in ipairs(window_snapshot[ws_index] or {}) do
			windows[#windows + 1] = {
				id = win.window_id,
				app = win.app or "?",
				title = (win.title and #win.title > 0 and win.title) or win.app or "Untitled",
				window_id = win.window_id,
			}
		end
		sort_windows_by_creation(windows)

		_popup_windows[ws_index] = {}
		for i, win in ipairs(windows) do
			if i > MAX_POPUP_SLOTS then
				break
			end
			_popup_windows[ws_index][i] = win
		end
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

local function distribute_cached_borders(focused_workspace, animated)
	local visible_names = {}
	for i, ws_idx in ipairs(workspace_order) do
		visible_names[i] = "workspace." .. ws_idx
	end
	local focused_name = "workspace." .. (focused_workspace or "")
	local signature = focused_name .. "\0" .. table.concat(visible_names, "\0")
	if _border_signature == signature then
		return
	end
	_border_signature = signature
	borders.distribute(visible_names, focused_name, animated, workspace_order)
end

local function distribute_borders_if_changed(visible_names, focused_name, animated)
	local signature = (focused_name or "") .. "\0" .. table.concat(visible_names, "\0")
	if _border_signature == signature then
		return
	end
	_border_signature = signature
	borders.distribute(visible_names, focused_name, animated, workspace_order)
end

-- ========== 更新所有工作区 + 分段状态 ==========
local function updateWindows(opts)
	opts = opts or {}
	if refresh_in_flight then
		refresh_pending = true
		refresh_pending_protect_empty_snapshot = refresh_pending_protect_empty_snapshot
			or opts.protect_empty_snapshot == true
		return
	end

	refresh_generation = refresh_generation + 1
	local generation = refresh_generation
	local protect_empty_snapshot = opts.protect_empty_snapshot == true
	refresh_in_flight = true

	sbar.delay(REFRESH_TIMEOUT, function()
		if not refresh_in_flight or refresh_generation ~= generation then
			return
		end
		refresh_in_flight = false
		if refresh_pending then
			local pending_protect = refresh_pending_protect_empty_snapshot
			refresh_pending = false
			refresh_pending_protect_empty_snapshot = false
			updateWindows({ protect_empty_snapshot = pending_protect })
		end
	end)

	withWindows(function(args)
		if not refresh_in_flight or refresh_generation ~= generation then
			return
		end

		if refresh_pending then
			local pending_protect = refresh_pending_protect_empty_snapshot
			refresh_pending = false
			refresh_pending_protect_empty_snapshot = false
			refresh_in_flight = false
			updateWindows({ protect_empty_snapshot = pending_protect })
			return
		end

		if args.snapshot_ok then
			if protect_empty_snapshot and snapshot_is_empty(args.open_windows) and not snapshot_is_empty(window_snapshot) then
				args.open_windows = window_snapshot
			else
				window_snapshot = args.open_windows
				snapshot_generation = snapshot_generation + 1
			end
		else
			args.open_windows = window_snapshot
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

		-- 第三步：更新焦点分段样式
		local visible_names = {}
		for i, ws_idx in ipairs(visible) do
			visible_names[#visible_names + 1] = "workspace." .. ws_idx
		end
		distribute_borders_if_changed(
			visible_names,
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
		local has_monitor_data = false
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local raw_id = entry["monitor-appkit-nsscreen-screens-id"]
			local monitor_id = raw_id and math.floor(raw_id)
			if space_index and monitor_id then
				has_monitor_data = true
				workspace_monitor[space_index] = monitor_id
			end
		end
		if not has_monitor_data then
			return
		end
		for workspace_index, _ in pairs(workspaces) do
			workspaces[workspace_index]:set({
				display = workspace_monitor[workspace_index],
			})
		end
	end)
end

local function syncDisplayState()
	local h = settings.detect_bar_height()
	if h and h > 0 then
		sbar.bar({ height = h })
		settings.height = h
	end

	-- Display/wake can leave the focused workspace cache stale while AeroSpace
	-- is still settling. Force the next window snapshot to query the real focus.
	focused_workspace_cache = nil
	updateWorkspaceMonitor()
	updateWindows({ protect_empty_snapshot = true })
end

local function scheduleDisplaySync()
	display_sync_generation = display_sync_generation + 1
	local gen = display_sync_generation
	for _, delay in ipairs({ 0.25, 1.25 }) do
		sbar.delay(delay, function()
			if display_sync_generation == gen then
				syncDisplayState()
			end
		end)
	end
end

-- ========== 初始化：begin_config 批量创建 workspace（性能优化）==========
-- AeroSpace 配置固定使用 persistent-workspaces，启动时直接创建这些常驻工作区。
-- 避免在 SketchyBar 冷启动路径同步等待 aerospace CLI；显示器/窗口状态后续异步同步。
local initial_workspaces = {}
for ws, _ in pairs(always_show) do
	initial_workspaces[#initial_workspaces + 1] = ws
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
			highlight_color = appearance.colors.crust,
			font = appearance.font_label_bold(13.0),
			padding_left = 10,
			padding_right = 2,
			drawing = true,
			string = (SPACE_ICONS[tonumber(ws:match("^(%d)"))] or ws) .. " >",
		},
		label = {
			color = appearance.colors.pill_fg,
			highlight_color = appearance.colors.crust,
			font = APP_ICON_FONT,
			padding_left = 2,
			padding_right = 10,
			y_offset = 0,
			drawing = true,
		},
		popup = {
			align = "left",
			background = appearance.popup_bg(),
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
	if not next(workspace_order) then
		io.stderr:write("sketchybar: spaces init failed — no workspaces loaded\n")
		return
	end
	for _, ws in ipairs(workspace_order) do
		local w = workspaces[ws]

		w:subscribe("mouse.entered", function()
			_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
			togglePopup(ws, w, true)
		end)
		w:subscribe("mouse.exited", function()
			scheduleHide(ws, w)
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
					hide_popup_async(ws, w)
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
			-- 使用已有快照一次性清除旧背景并点亮当前工作区，不触发窗口查询。
			distribute_cached_borders(focused, animations_ready)
		end
	end)

	-- `space_windows_change` 有两个来源：
	--   1. SketchyBar 原生事件：窗口创建/销毁后触发，负责关闭窗口的实时刷新；
	--   2. aerospace_watch 自定义 trigger：AeroSpace 检测到新窗口后补一发 created。
	root:subscribe("space_windows_change", function(env)
		local event = env and env.WINDOW_EVENT
		local delay = WINDOW_REFRESH_DELAY_DEFAULT
		if event == "created" then
			delay = WINDOW_REFRESH_DELAY_CREATED
		elseif event == "destroyed" or event == "terminated" then
			delay = WINDOW_REFRESH_DELAY_DESTROYED
		end
		scheduleUpdateWindows(delay)
	end)

	-- fullscreen 变化由 aerospace_watch 在 focus/workspace 等事件后 diff，触发 aerospace_fullscreen_change。
	-- 不再使用 window_focus_change（主条只高亮工作区段）。

	-- 显示器变化：同步 bar、自动显隐区域与工作区所属屏幕。
	-- system_woke 不直接触发，避免睡眠唤醒但显示器未变化时整组 workspace 重绘。
	root:subscribe("display_change", function()
		scheduleDisplaySync()
	end)

	-- 全屏状态变化后刷新完整快照，并把标记显示在对应工作区编号左侧。
	root:subscribe("aerospace_fullscreen_change", function()
		updateWindows()
	end)

	local function set_mode_visibility(is_service)
		if mode_visible == is_service then
			return
		end
		mode_visible = is_service
		mode_generation = mode_generation + 1
		local gen = mode_generation
		if is_service then
			mode_item:set({
				drawing = true,
				width = "dynamic",
				padding_left = 2,
				padding_right = 2,
				label = { color = transparent(appearance.colors.sapphire) },
			})
		end
		-- 退出 service 时,动画结束后收起 drawing,避免空 item 占位
		sbar.animate("linear", timing.STANDARD_DURATION_FRAMES, function()
			mode_item:set({
				label = {
					color = is_service and appearance.colors.sapphire
						or transparent(appearance.colors.sapphire),
				},
			})
		end)
		if not is_service then
			sbar.delay(timing.frames_to_seconds(timing.STANDARD_DURATION_FRAMES), function()
				if mode_generation ~= gen or mode_visible then
					return
				end
				mode_item:set({
					drawing = false,
					width = 0,
					padding_left = 0,
					padding_right = 0,
				})
			end)
		end
	end

	-- aerospace_mode_change
	root:subscribe("aerospace_mode_change", function(env)
		local mode = env and env.AEROSPACE_MODE
		if mode then
			set_mode_visibility(mode == "service")
			return
		end
		sbar.exec("aerospace list-modes --current", function(result)
			set_mode_visibility((result or ""):match("service") ~= nil)
		end)
	end)

	-- 初始 focus
	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		if not focused_workspace then
			return
		end
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		focused_workspace_cache = focused_workspace
		if workspaces[focused_workspace] then
			distribute_cached_borders(focused_workspace)
		end
	end)
end)

-- 启动渐隐：startup 在 end_config 之后揭示 bar，enter_animation 负责 item 渐入。
-- spaces.root / aerospace_mode / popup 子项在 enter_animation 的 skip 名单里，不参与渐隐。
