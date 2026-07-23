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
local enter_animation = require("helpers.enter_animation")
local popup_animation = require("helpers.popup_animation")
local timing = require("helpers.timing")
local window_filter = require("helpers.window_filter")
local sbar = require("sketchybar")
local fonts = require("fonts")
local settings = require("settings")
local startup = require("helpers.startup")
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
	["2̲Term"] = true,
	["3̲Chat"] = true,
	["4̲Work"] = true,
	["5̲AI"] = true,
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
local _popup_pinned = {} -- { [ws_name] = true/false } 当前工作区 popup 是否由点击打开
local _popup_render_gen = {} -- { [ws_name] = gen } 延迟渲染的代数，避免旧鼠标事件覆盖新内容
local _popup_query_gen = {} -- { [ws_name] = gen } 丢弃关闭 popup 后才返回的旧查询
local _popup_animations = {}
local _border_signature
local _workspace_content_signatures = {}
local animations_ready = false
local front_app_generation = 0
local front_app_initialized = false
local front_app_name
local mode_visible = false
local mode_generation = 0
local spaces_initial_ready = startup.track("spaces.snapshot")
local front_app_initial_ready = startup.track("front_app.status")

-- 内容切换动画帧数:统一规范，跟随 timing.lua 的标准 fade 时长。
-- front_app 是一整串 label；名称变化时先淡出、替换文字、再淡入，
-- 避免短名称切换时出现左右移动感。
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
			front_app_initial_ready()
			return
		end
		front_app_name = name
		front_app_generation = front_app_generation + 1
		local generation = front_app_generation
		if not front_app_initialized then
			front_app_initialized = true
			front_app:set({ label = { string = name } })
			front_app_initial_ready()
			return
		end
		front_app_initial_ready()
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
local window_snapshot = {}

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
			local title = entry["window-title"]

			-- 快照保留窗口粒度：主条按 app 去重渲染，popup 仍按窗口逐个显示。
			if window_filter.should_show(app, title) and not processed_windows[window_id] then
				processed_windows[window_id] = true

				if results.open_windows[workspace_index] == nil then
					results.open_windows[workspace_index] = {}
				end

				table.insert(results.open_windows[workspace_index], {
					app = app,
					window_id = window_id,
					is_fullscreen = entry["window-is-fullscreen"] == true,
					title = title,
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
	local icon_line = #open_windows > 0 and app_icon_line(open_windows) or nil
	local has_fullscreen = #open_windows > 0 and workspace_has_fullscreen(open_windows) or false

	local function apply_content(label_color)
		if #open_windows == 0 then
			show_empty_workspace(workspace_index, args.focused_workspace, args.visible_workspaces, label_color)
		else
			show_workspace_apps(workspace_index, icon_line, has_fullscreen, label_color)
		end
	end

	local is_focused = args.focused_workspace == workspace_index
	local final_color = is_focused and appearance.colors.crust or appearance.colors.pill_fg
	local signature
	if #open_windows == 0 then
		local monitor_id = visible_monitor_id(workspace_index, args.visible_workspaces)
		local drawing = monitor_id ~= nil or is_focused or always_show[workspace_index] == true
		signature = table.concat({ "empty", tostring(monitor_id), tostring(drawing), tostring(final_color) }, "\0")
	else
		signature = table.concat({
			"apps",
			icon_line,
			tostring(has_fullscreen),
			tostring(final_color),
		}, "\0")
	end
	if _workspace_content_signatures[workspace_index] == signature then
		return
	end
	_workspace_content_signatures[workspace_index] = signature
	apply_content(final_color)
end

local function defer_popup_render(ws_index, callback)
	local gen = (_popup_render_gen[ws_index] or 0) + 1
	_popup_render_gen[ws_index] = gen
	sbar.delay(0, function()
		if _popup_render_gen[ws_index] == gen then
			callback()
		end
	end)
end

local function show_popup(ws_index, workspace)
	local animation = _popup_animations[ws_index]
	if not animations_ready or not animation then
		workspace:set({ popup = { drawing = true } })
		return
	end
	animation:show()
end

local function hide_popup(ws_index, workspace)
	local animation = _popup_animations[ws_index]
	if not animations_ready or not animation then
		workspace:set({ popup = { drawing = false } })
		return
	end
	animation:hide()
end

local function popup_windows_from_snapshot(ws_index)
	local windows = {}
	for _, win in ipairs(window_snapshot[ws_index] or {}) do
		windows[#windows + 1] = {
			id = win.window_id,
			app = win.app or "?",
			title = (win.title and #win.title > 0 and win.title) or win.app or "Untitled",
			window_id = win.window_id,
		}
	end
	return windows
end

local function popup_windows_from_query(entries)
	if type(entries) ~= "table" then
		return nil
	end

	local windows = {}
	local seen_ids = {}
	for _, entry in ipairs(entries) do
		local window_id = entry["window-id"]
		if window_id and not seen_ids[window_id] then
			seen_ids[window_id] = true
			local app = entry["app-name"] or "?"
			local title = entry["window-title"]
			if window_filter.should_show(app, title) then
				windows[#windows + 1] = {
					id = window_id,
					app = app,
					title = (title and #title > 0 and title) or app or "Untitled",
					window_id = window_id,
				}
			end
		end
	end
	return windows
end

local function render_popup(ws_index, workspace_item, windows)
	sort_windows_by_creation(windows)
	_popup_windows[ws_index] = {}
	for i, win in ipairs(windows) do
		if i > MAX_POPUP_SLOTS then
			break
		end
		_popup_windows[ws_index][i] = win
	end

	if #windows == 0 then
		_popup_pinned[ws_index] = false
		defer_popup_render(ws_index, function()
			for i = 1, MAX_POPUP_SLOTS do
				local item = _popup_items[ws_index] and _popup_items[ws_index][i]
				if item then
					item:set({ drawing = false })
				end
			end
			hide_popup(ws_index, workspace_item)
		end)
		return
	end

	defer_popup_render(ws_index, function()
		for i = 1, MAX_POPUP_SLOTS do
			local item = _popup_items[ws_index] and _popup_items[ws_index][i]
			local win = _popup_windows[ws_index][i]
			if item then
				if win then
					item:set({
						drawing = true,
						icon = {
							string = app_icons[win.app] or app_icons["Default"],
							color = appearance.colors.pill_fg,
							highlight = false,
						},
						label = { string = win.title, color = appearance.colors.text, highlight = false },
					})
				else
					item:set({ drawing = false })
				end
			end
		end
		if _popup_pinned[ws_index] then
			show_popup(ws_index, workspace_item)
		else
			hide_popup(ws_index, workspace_item)
		end
	end)
end

local function invalidate_popup_query(ws_index)
	_popup_query_gen[ws_index] = (_popup_query_gen[ws_index] or 0) + 1
end

local function close_popups(except_ws)
	for ws_index, workspace in pairs(workspaces) do
		if ws_index ~= except_ws then
			invalidate_popup_query(ws_index)
			if _popup_pinned[ws_index] then
				hide_popup(ws_index, workspace)
			end
			_popup_pinned[ws_index] = false
		end
	end
end

-- ========== Popup：点击当前工作区时查询并展示最新窗口列表 ==========
local function open_popup(ws_index, workspace_item)
	if not workspace_item then
		return
	end

	close_popups(ws_index)

	invalidate_popup_query(ws_index)
	local generation = _popup_query_gen[ws_index]
	local command = "aerospace list-windows --workspace " .. shell_quote(ws_index)
		.. " --format '%{app-name}%{window-id}%{window-title}' --json"
	sbar.exec(command, function(entries)
		if _popup_query_gen[ws_index] ~= generation or not _popup_pinned[ws_index] then
			return
		end
		-- AeroSpace 查询失败时沿用主条快照；空表则代表工作区确实已无窗口。
		local windows = popup_windows_from_query(entries) or popup_windows_from_snapshot(ws_index)
		render_popup(ws_index, workspace_item, windows)
	end)
end

-- visible_names 缺省时用全部 workspace_order。
-- 不变量：workspace_order 只含 always_show 的常驻工作区（全部可见），
-- 因此 updateWindows 的可见性过滤目前恒等于完整列表。
local function distribute_borders(focused_workspace, animated, visible_names)
	if not visible_names then
		visible_names = {}
		for i, ws_idx in ipairs(workspace_order) do
			visible_names[i] = "workspace." .. ws_idx
		end
	end
	local focused_name = "workspace." .. (focused_workspace or "")
	local signature = focused_name .. "\0" .. table.concat(visible_names, "\0")
	if _border_signature == signature then
		return
	end
	_border_signature = signature
	borders.distribute(visible_names, focused_name, animated, workspace_order)
end

-- ========== 更新所有工作区 + 分段状态 ==========
-- 完成回调单槽：新登记覆盖旧值。唯一消费者是显示器拓扑变化的渐入门控
-- （enter_animation.hold/release），被覆盖的旧回调其 release(token) 必被
-- token 过期丢弃，且 hold 有 HOLD_TIMEOUT 兜底，覆盖安全。
local windows_on_complete = nil

local function finish_windows_refresh()
	local cb = windows_on_complete
	windows_on_complete = nil
	if cb then
		cb()
	end
end

local function updateWindows(opts)
	opts = opts or {}
	-- 登记必须先于 refresh_in_flight 检查：合并进在飞刷新时，
	-- 由最终那次刷新的完成点统一冲刷。
	if opts.on_complete then
		windows_on_complete = opts.on_complete
	end
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
		spaces_initial_ready()
		if refresh_pending then
			local pending_protect = refresh_pending_protect_empty_snapshot
			refresh_pending = false
			refresh_pending_protect_empty_snapshot = false
			-- 交接给 pending 刷新：on_complete 不在这里冲刷，
			-- 由最终那次刷新的完成点统一冲刷。
			updateWindows({ protect_empty_snapshot = pending_protect })
		else
			finish_windows_refresh()
		end
	end)

	withWindows(function(args)
		startup.after_reveal("spaces.snapshot", function()
			if not refresh_in_flight or refresh_generation ~= generation then
				return
			end

			if refresh_pending then
				local pending_protect = refresh_pending_protect_empty_snapshot
				refresh_pending = false
				refresh_pending_protect_empty_snapshot = false
				refresh_in_flight = false
				-- 交接给 pending 刷新：on_complete 不在这里冲刷，
				-- 由最终那次刷新的完成点统一冲刷。
				updateWindows({ protect_empty_snapshot = pending_protect })
				return
			end

			if args.snapshot_ok then
				if protect_empty_snapshot and snapshot_is_empty(args.open_windows) and not snapshot_is_empty(window_snapshot) then
					args.open_windows = window_snapshot
				else
					window_snapshot = args.open_windows
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
			for _, ws_idx in ipairs(visible) do
				visible_names[#visible_names + 1] = "workspace." .. ws_idx
			end
			distribute_borders(args.focused_workspace, animations_ready, visible_names)
			refresh_in_flight = false
			animations_ready = true
			finish_windows_refresh()
		end)
		spaces_initial_ready()
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

-- ========== 多显示器支持：工作区所属显示器 ==========
local workspace_monitor_signature
local topology_signature

local query_monitors = "aerospace list-monitors --format '%{monitor-id}|%{monitor-name}'"

-- 仅查询组装快照：不更新签名缓存、不 set item。
-- AeroSpace settle 期间可能只返回部分 workspace，"至少一条有数据"会把中间态当
-- 真实拓扑应用；必须每个已知 workspace 都有合法 monitor ID 才算 monitor_valid，
-- 否则映射信号按"未知"处理，交给下一轮 probe 重试。
--
-- 注意 nsscreen id 只是当前屏幕数组序号（AeroSpace 官方确认），单屏场景下外屏和
-- 内屏会拿到同一个 id，映射签名对"换屏"不敏感。因此另取 topology 签名
-- （显示器 id|name 有序列表）做第二信号；名称可能重复，是实用增强而非物理身份。
local function queryMonitorSnapshot(on_done)
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		local snapshot = { monitor_valid = false, monitor_changed = false }
		if not workspaces_and_monitors then
			on_done(snapshot)
			return
		end
		local workspace_monitor = {}
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local raw_id = entry["monitor-appkit-nsscreen-screens-id"]
			local monitor_id = raw_id and math.floor(raw_id)
			if space_index and monitor_id then
				workspace_monitor[space_index] = monitor_id
			end
		end
		for _, workspace_index in ipairs(workspace_order) do
			if not workspace_monitor[workspace_index] then
				on_done(snapshot)
				return
			end
		end
		local signature_parts = {}
		for _, workspace_index in ipairs(workspace_order) do
			signature_parts[#signature_parts + 1] = workspace_index .. "=" .. tostring(workspace_monitor[workspace_index])
		end
		snapshot.monitor_map = workspace_monitor
		snapshot.monitor_signature = table.concat(signature_parts, "\0")

		sbar.exec(query_monitors, function(monitor_list)
			local topo_parts = {}
			if type(monitor_list) == "string" then
				for line in monitor_list:gmatch("[^\r\n]+") do
					topo_parts[#topo_parts + 1] = line
				end
				table.sort(topo_parts)
			end
			if #topo_parts > 0 then
				snapshot.topology_signature = table.concat(topo_parts, "\n")
			end
			snapshot.monitor_valid = true
			snapshot.monitor_changed = snapshot.monitor_signature ~= workspace_monitor_signature
				or (snapshot.topology_signature ~= nil and snapshot.topology_signature ~= topology_signature)
			on_done(snapshot)
		end)
	end)
end

-- 应用已确认的映射快照：更新签名并把 workspace 指派到对应显示器。
local function applyMonitorSnapshot(snapshot)
	workspace_monitor_signature = snapshot.monitor_signature
	if snapshot.topology_signature then
		topology_signature = snapshot.topology_signature
	end
	for workspace_index, _ in pairs(workspaces) do
		workspaces[workspace_index]:set({
			display = snapshot.monitor_map[workspace_index],
		})
	end
end

-- 启动初始化用：查询并直接应用（首次签名必为 changed）。
local function updateWorkspaceMonitor(on_complete)
	queryMonitorSnapshot(function(snapshot)
		if snapshot.monitor_valid and snapshot.monitor_changed then
			applyMonitorSnapshot(snapshot)
		end
		if on_complete then
			on_complete(snapshot.monitor_valid and snapshot.monitor_changed)
		end
	end)
end

-- 采集显示器快照（bar 高度 + 映射签名），只比对不应用。
local function probeDisplayState(on_done)
	settings.refresh_bar_height(function(height)
		local snapshot = {
			height = height,
			height_changed = height and height > 0 and height ~= settings.height or false,
		}
		queryMonitorSnapshot(function(monitor)
			snapshot.monitor_valid = monitor.monitor_valid
			snapshot.monitor_changed = monitor.monitor_changed
			snapshot.monitor_map = monitor.monitor_map
			snapshot.monitor_signature = monitor.monitor_signature
			on_done(snapshot)
		end)
	end)
end

-- 应用 probe 确认的同一份快照（不再次查询，避免 probe/apply 之间状态漂移）。
-- 仅在实际有变化时被调用。on_complete 在窗口快照刷新完成后触发
-- （遮罩会话用它门控渐入的释放时机；高度-only 没有异步步骤，立即触发）。
local function applySnapshot(snapshot, on_complete)
	if snapshot.height_changed then
		settings.height = snapshot.height
		sbar.bar({ height = snapshot.height })
	end
	if snapshot.monitor_changed then
		-- 映射变化后 AeroSpace 仍在 settle，focused workspace 缓存可能过期，
		-- 强制下一次窗口快照查询真实 focus。
		focused_workspace_cache = nil
		applyMonitorSnapshot(snapshot)
		updateWindows({ protect_empty_snapshot = true, on_complete = on_complete })
	elseif on_complete then
		on_complete()
	end
end

-- ========== 显示器/睡眠可见性门控（四态状态机）==========
-- 背景（SketchyBar v2.24 源码确认）：system_woke/display_change 到达 Lua 之前，
-- SketchyBar 已经销毁并重建了全部 bar 窗口（首次 wake 还会 ~500ms 后再来一次；
-- 解锁通知同样转成 SYSTEM_WOKE）。原生重建就是切换时"闪好几次"的来源。
-- hidden 状态由 bar_manager 保留并应用到重建后的新窗口（alpha 做不到），
-- 因此用 hidden 做跨重建门控：
--   idle         → 正常显示
--   sleep_hidden → will_sleep 立即 hidden；设备 wake/补发 wake/锁屏等待都保持；
--                  正常释放入口是 screen_unlocked；首次 wake 武装 75s failsafe
--                  （解锁通知丢失时兜底，只能进 settling，绝不直接 hidden=off）
--   settling     → 已解锁（或清醒 display_change 立即进入）：0.2s 一探，
--                  连续两份有效且相同快照 + 最后事件后 0.8s 静默判定稳定；
--                  3.5s 为故障兜底（enter_animation HOLD_TIMEOUT）
--   revealing    → 应用快照后 release 一次整体渐入，随后回 idle
local SETTLE_PROBE_INTERVAL = 0.2
local SETTLE_QUIET_PROBES = 4 -- 最后事件后至少 0.8s 静默（4×0.2）
local SETTLE_MAX_SECONDS = 3.5
local SLEEP_FAILSAFE_SECONDS = 75

local gate_state = "idle"
local gate_generation = 0
local gate_token = nil
local gate_probes_since_event = 0
local gate_last_valid_key = nil
local gate_settling_started = 0
local gate_had_wake = false
local gate_failsafe_armed = false

local gate_probe -- 前向声明

local function gate_reveal(snapshot)
	gate_state = "revealing"
	if not snapshot.monitor_valid then
		-- 收尾时映射仍无效：fallback 高度-only（映射保持旧值）
		snapshot.monitor_changed = false
	end
	if snapshot.height_changed or snapshot.monitor_changed then
		if gate_had_wake then
			sbar.trigger("display_topology_change")
		end
		applySnapshot(snapshot, function()
			enter_animation.release(gate_token)
			gate_state = "idle"
		end)
	else
		enter_animation.release(gate_token)
		gate_state = "idle"
	end
end

gate_probe = function(gen)
	sbar.delay(SETTLE_PROBE_INTERVAL, function()
		if gen ~= gate_generation or gate_state ~= "settling" then
			return
		end
		probeDisplayState(function(snapshot)
			if gen ~= gate_generation or gate_state ~= "settling" then
				return
			end
			gate_probes_since_event = gate_probes_since_event + 1
			local timed_out = (os.time() - gate_settling_started) >= SETTLE_MAX_SECONDS
			if snapshot.monitor_valid and not timed_out then
				local valid_key = tostring(snapshot.height) .. "|" .. snapshot.monitor_signature
					.. "|" .. tostring(snapshot.topology_signature)
				local stable = gate_last_valid_key == valid_key
				gate_last_valid_key = valid_key
				if not stable or gate_probes_since_event < SETTLE_QUIET_PROBES then
					gate_probe(gen)
					return
				end
			elseif not timed_out then
				-- AeroSpace 数据不完整：不计入稳定性，继续等下一轮
				gate_probe(gen)
				return
			end
			gate_reveal(snapshot)
		end)
	end)
end

-- 进入/续期 settling：generation 作废旧回调，hold 续期并重武装 3.5s 兜底，
-- 静默计数清零。revealing 中的事件属于同一风暴，忽略。
local function gate_enter_settling()
	if gate_state == "revealing" then
		return
	end
	gate_state = "settling"
	gate_generation = gate_generation + 1
	gate_token = enter_animation.hold({ hidden = true })
	gate_probes_since_event = 0
	gate_last_valid_key = nil
	gate_settling_started = os.time()
	gate_probe(gate_generation)
end

-- display_change / system_woke 统一入口
local function gate_on_display_event(source_event)
	if gate_state == "sleep_hidden" then
		-- 睡眠会话：只记录并武装 failsafe（一次），等解锁；不 bump generation，
		-- 否则 failsafe 会被吸收事件作废。
		gate_had_wake = true
		if not gate_failsafe_armed then
			gate_failsafe_armed = true
			local gen = gate_generation
			sbar.delay(SLEEP_FAILSAFE_SECONDS, function()
				if gate_state == "sleep_hidden" and gate_generation == gen then
					io.stderr:write("display_gate: 75s failsafe fired, force settling\n")
					gate_enter_settling()
				end
			end)
		end
		return
	end
	if gate_state == "idle" then
		gate_had_wake = source_event == "system_woke"
		-- popup 状态一致性：hidden 本身会关 popup，这里同步各模块内部标志
		close_popups()
		sbar.trigger("display_transition_begin")
	else
		gate_had_wake = gate_had_wake or source_event == "system_woke"
	end
	gate_enter_settling()
end

local function gate_on_will_sleep()
	gate_state = "sleep_hidden"
	gate_generation = gate_generation + 1 -- 作废旧会话的所有回调
	gate_failsafe_armed = false
	gate_had_wake = false
	close_popups()
	sbar.trigger("display_transition_begin")
	gate_token = enter_animation.hold({ hidden = true, no_timeout = true })
end

local function gate_on_unlock()
	if gate_state == "sleep_hidden" then
		gate_enter_settling()
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
				highlight_color = appearance.colors.red,
			},
			label = {
				font = { family = fonts.font.text, style = fonts.font.style_map["Semibold"], size = 13.0 },
				padding_left = 0,
				padding_right = 16,
				max_chars = 50,
				color = appearance.colors.text,
				highlight_color = appearance.colors.red,
			},
			background = { drawing = false, border_width = 0 },
		})
		_popup_items[ws][i] = popup_item
	end
	local workspace_index = ws
	_popup_animations[workspace_index] = popup_animation.new(workspace)
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

-- 事件订阅 + 初始化（在 end_config 后延迟执行，不启动空 shell）
sbar.delay(0, function()
	if not next(workspace_order) then
		io.stderr:write("sketchybar: spaces init failed — no workspaces loaded\n")
		return
	end
	for _, ws in ipairs(workspace_order) do
		local w = workspaces[ws]

		w:subscribe("mouse.clicked", function()
			sbar.exec("aerospace list-workspaces --focused", function(focused)
				focused = focused and focused:match("^%s*(.-)%s*$")
				if focused == ws then
					if _popup_pinned[ws] then
						_popup_pinned[ws] = false
						invalidate_popup_query(ws)
						hide_popup(ws, w)
					else
						_popup_pinned[ws] = true
						open_popup(ws, w)
					end
				else
					close_popups()
					sbar.exec("aerospace workspace " .. shell_quote(ws))
				end
			end)
		end)

		for i = 1, MAX_POPUP_SLOTS do
			local pi = _popup_items[ws][i]
			pi:subscribe("mouse.entered", function()
				pi:set({ icon = { highlight = true }, label = { highlight = true } })
			end)
			pi:subscribe("mouse.exited", function()
				pi:set({ icon = { highlight = false }, label = { highlight = false } })
			end)
			pi:subscribe("mouse.clicked", function()
				local win = _popup_windows[ws] and _popup_windows[ws][i]
				if win then
					local win_id = tostring(win.id):match("^%d+$")
					if win_id then
						sbar.exec("aerospace focus --window-id " .. win_id)
					end
					_popup_pinned[ws] = false
					invalidate_popup_query(ws)
					hide_popup(ws, w)
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
			close_popups()
			-- 使用已有快照一次性清除旧背景并点亮当前工作区，不触发窗口查询。
			distribute_borders(focused, animations_ready)
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

	-- 唤醒与显示器变化统一走可见性门控（gate_on_display_event）：
	-- 清醒路径立即 hidden 进 settling；睡眠路径只记录并武装 failsafe，等解锁。
	root:subscribe({ "display_change", "system_woke" }, function(env)
		gate_on_display_event(env.SENDER)
	end)

	-- 睡前立即 hidden：SketchyBar 在 wake 事件送达 Lua 之前就重建了全部 bar
	-- 窗口，事件后再遮罩遮不住第一帧旧画面。hidden 状态由 bar_manager 保留，
	-- 跨原生重建有效；睡眠期间定时器不跑，hold 不武装超时。
	root:subscribe("system_will_sleep", function()
		gate_on_will_sleep()
	end)

	-- 解锁是睡眠会话的正常释放入口（锁屏期间保持 hidden）。
	sbar.add("event", "screen_unlocked", "com.apple.screenIsUnlocked")
	root:subscribe("screen_unlocked", function()
		gate_on_unlock()
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
			distribute_borders(focused_workspace)
		end
	end)
end)

-- 启动渐入：startup 在 end_config 之后揭示 bar，enter_animation 负责 item 渐入。
-- spaces.root / aerospace_mode / popup 子项在 enter_animation 的 skip 名单里，不参与渐入。
