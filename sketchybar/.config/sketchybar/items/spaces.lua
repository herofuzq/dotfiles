-- ========== aerospace 工作区显示 ==========
-- 通过 aerospace CLI 查询窗口和屏幕信息，动态显示各工作区的应用图标
-- 工作区边框由 borders.lua 动态分配，空工作区隐藏 label、icon 居中
local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local borders = require("helpers.borders")
local sbar = require("sketchybar")
local fonts = require("fonts")
local settings = require("settings")
local SPACE_ICONS = { "󰼏", "󰼐", "󰼑", "󰼒", "󰼓", "󰼔" }

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
local _popup_items = {} -- { [ws_name] = { item1, ..., item10 } }
local _popup_windows = {} -- { [ws_name] = { {id, app, title}, ... } }
local _popup_pinned = {} -- { [ws_name] = true/false } 记录点击固定状态，固定后鼠标离开不隐藏
local _popup_gen = {} -- { [ws_name] = gen } 防止 hover 异步回调覆盖 mouse.exited.global 的隐藏
local _popup_hovering = {} -- { [ws_name] = true/false } 鼠标当前是否在 popup 子项上
local _popup_exit_gen = {} -- { [ws_name] = gen } 延迟隐藏的代数，进入 popup 时作废旧延迟

-- aerospace 模式指示器（当前仅在 service 模式下显示 "󰰣" 图标）
local mode_item = sbar.add("item", "aerospace_mode", {
	position = "left",
	padding_left = 2,
	padding_right = 2,
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
		color = appearance.colors.sapphire,
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
			font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = fonts.font.size },
			padding_left = 8,
			padding_right = 8,
			align = "center",
			color = appearance.colors.peach,
		},
		background = { drawing = false },
	})
	front_app:subscribe("front_app_switched", function(env)
		front_app:set({ label = { string = env.INFO } })
	end)
end

-- ========== 窗口信息收集 ==========
local generation = 0

local function withWindows(f)
	local my_gen = generation
	local results = {
		open_windows = {},
		has_fullscreen = {},
		focused_workspace = nil,
		visible_workspaces = nil,
	}
	local pending = 3

	local function check_done()
		if my_gen ~= generation then
			return
		end
		pending = pending - 1
		if pending == 0 then
			f(results)
		end
	end

	local get_windows =
		"aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}%{window-is-fullscreen}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"

	sbar.exec(get_windows, function(workspace_and_windows)
		if not workspace_and_windows then
			check_done()
			return
		end
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

				table.insert(results.open_windows[workspace_index], app)
			end
		end

		check_done()
	end)

	sbar.exec(get_focus_workspaces, function(focused_workspace)
		if focused_workspace then
			results.focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		else
			results.focused_workspace = ""
		end
		check_done()
	end)

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
local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index]
	local focused_workspace = args.focused_workspace
	local visible_workspaces = args.visible_workspaces
	local is_focused = workspace_index == focused_workspace

	if open_windows == nil then
		open_windows = {}
	end

	-- 拼接应用图标字符串（使用 sketchybar-app-font 的 :name: 格式）
	local icon_line = ""
	local no_app = true
	for _, app in ipairs(open_windows) do
		no_app = false
		local lookup = app_icons[app]
		local icon = ((lookup == nil) and app_icons["Default"] or lookup)
		icon_line = icon_line .. icon
	end

	-- 情况1：没有应用，但工作区当前在屏幕上可见
	for _, vw in ipairs(visible_workspaces) do
		if no_app and workspace_index == vw["workspace"] then
			local raw_id = vw["monitor-appkit-nsscreen-screens-id"]
			local monitor_id = raw_id and math.floor(raw_id)
			workspaces[workspace_index]:set({
				drawing = true,
				icon = { padding_left = 10, padding_right = 10 },
				label = { drawing = false },
				display = monitor_id,
			})
			return
		end
	end

	-- 情况2：没有应用，也不聚焦 → always_show 则显示，否则隐藏
	if no_app and workspace_index ~= focused_workspace then
		workspaces[workspace_index]:set({
			drawing = always_show[workspace_index] and true or false,
			icon = { padding_left = 10, padding_right = 10 },
			label = { drawing = false },
		})
		return
	end

	-- 情况3：没有应用，但是聚焦的工作区
	if no_app and workspace_index == focused_workspace then
		workspaces[workspace_index]:set({
			drawing = true,
			icon = { padding_left = 10, padding_right = 10 },
			label = { drawing = false },
		})
		return
	end

	-- 情况4：有应用
	-- 注：高亮由 root subscribe("aerospace_workspace_change") 立即设置（env.FOCUSED_WORKSPACE），
	-- 此处不重复设置，避免 aerospace CLI 偶尔失败时把高亮误清
	workspaces[workspace_index]:set({
		drawing = true,
		icon = { padding_left = 10, padding_right = 2 },
		label = { drawing = true, string = icon_line },
	})
end

local function scheduleHide(ws_index, workspace)
	_popup_gen[ws_index] = (_popup_gen[ws_index] or 0) + 1
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
		workspace:set({ popup = { drawing = false } })
	end)
end

-- ========== Popup：展示/切换工作区窗口列表 ==========
-- force_show=true 用于 hover（总是展示，不 toggle），留空则是 toggle（点击切换）
local function togglePopup(ws_index, workspace_item, force_show, gen)
	if not workspace_item then
		return
	end

	local cmd = 'aerospace list-windows --workspace "'
		.. ws_index
		.. "\" --format '%{window-id}%{app-name}%{window-title}' --json"

	sbar.exec(cmd, function(windows)
		if not windows or #windows == 0 then
			return
		end

		_popup_windows[ws_index] = {}
		for i, w in ipairs(windows) do
			if i > MAX_POPUP_SLOTS then
				break
			end
			local id = w["window-id"]
			if not id then
				break
			end
			_popup_windows[ws_index][i] = {
				id = id,
				app = w["app-name"] or "?",
				title = (w["window-title"] and #w["window-title"] > 0 and w["window-title"])
					or w["app-name"]
					or "Untitled",
			}
		end

		for _, ws in pairs(workspaces) do
			if ws ~= workspace_item then
				ws:set({ popup = { drawing = false } })
			end
		end

		for i = 1, MAX_POPUP_SLOTS do
			local item = _popup_items[ws_index] and _popup_items[ws_index][i]
			local win = _popup_windows[ws_index] and _popup_windows[ws_index][i]
			if item then
				if win then
					local icon = (app_icons[win.app] or app_icons["Default"])
					item:set({
						drawing = true,
						icon = { string = icon, color = appearance.colors.pill_fg },
						label = { string = win.title, color = appearance.colors.text },
					})
				else
					item:set({ drawing = false })
				end
			end
		end

		if gen and _popup_gen[ws_index] ~= gen then
			return
		end

		local drawing = force_show and true or "toggle"
		workspace_item:set({ popup = { drawing = drawing } })
	end)
end

-- ========== 工作区高亮辅助 ==========
local function set_highlight(ws, is_focused)
	ws:set({
		icon = { highlight = is_focused },
		background = {
			border_color = is_focused and appearance.colors.red or appearance.colors.border,
			border_width = 1,
			corner_radius = 10,
		},
		popup = {
			background = {
				border_color = is_focused and appearance.colors.red or appearance.colors.border,
				border_width = 1,
				corner_radius = 10,
			},
		},
	})
end

-- ========== 更新所有工作区 + 分配边框颜色 ==========
local function updateWindows()
	generation = generation + 1
	withWindows(function(args)
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

		-- 第三步：通过中央调色器分配边框颜色 + 全屏处理
		local visible_names = {}
		local fullscreen_idx = {}
		for i, ws_idx in ipairs(visible) do
			visible_names[#visible_names + 1] = "workspace." .. ws_idx
			if args.has_fullscreen[ws_idx] then
				fullscreen_idx[i] = true
			end
		end
		borders.distribute(visible_names, fullscreen_idx)
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

for ws in raw:gmatch('"workspace"%s*:%s*"([^"]+)"') do
	local workspace = sbar.add("item", "workspace." .. ws, {
		background = {
			color = appearance.colors.pill_bg,
			drawing = true,
			corner_radius = 10,
			border_width = 2,
			border_color = appearance.colors.border,
		},
		drawing = false,
		padding_left = 2,
		padding_right = 2,
		icon = {
			color = appearance.colors.pill_fg,
			highlight_color = appearance.colors.red,
			font = { family = fonts.font.text, style = fonts.font.style_map["Bold"], size = fonts.font.size },
			padding_left = 10,
			padding_right = 2,
			drawing = true,
			string = (SPACE_ICONS[tonumber(ws:match("^(%d)"))] or ws) .. " >",
		},
		label = {
			color = appearance.colors.pill_fg,
			highlight_color = appearance.colors.red,
			font = "sketchybar-app-font:Regular:14.0",
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
end

-- front_app 在 begin_config 中直接创建（不依赖 aerospace 回调）
ensure_front_app()

-- 事件订阅 + 初始化（在 end_config 后延迟执行）
sbar.exec(":", function()
	for _, ws in ipairs(workspace_order) do
		local w = workspaces[ws]

		w:subscribe("mouse.entered", function()
			_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
			local gen = (_popup_gen[ws] or 0) + 1
			_popup_gen[ws] = gen
			togglePopup(ws, w, true, gen)
		end)
		w:subscribe("mouse.exited", function()
			scheduleHide(ws, w)
		end)
		w:subscribe("mouse.exited.global", function()
			_popup_exit_gen[ws] = (_popup_exit_gen[ws] or 0) + 1
			_popup_gen[ws] = (_popup_gen[ws] or 0) + 1
			if not _popup_pinned[ws] then
				w:set({ popup = { drawing = false } })
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
					sbar.exec('aerospace workspace "' .. ws .. '"')
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
					sbar.exec("aerospace focus --window-id " .. win.id)
					w:set({ popup = { drawing = false } })
				end
			end)
		end
	end

	-- 首次加载
	updateWindows()
	updateWorkspaceMonitor()

	-- aerospace_workspace_change
	root:subscribe("aerospace_workspace_change", function(env)
		ensure_front_app()
		local focused = env.FOCUSED_WORKSPACE
		if focused then
			for k, _ in pairs(_popup_pinned) do
				_popup_pinned[k] = false
			end
			for k, _ in pairs(_popup_hovering) do
				_popup_hovering[k] = false
			end
			for ws_idx, ws in pairs(workspaces) do
				set_highlight(ws, ws_idx == focused)
			end
		end
		updateWindows()
	end)

	-- space_windows_change（300ms 防抖）
	local _space_change_gen = 0
	root:subscribe("space_windows_change", function()
		local my_gen = _space_change_gen + 1
		_space_change_gen = my_gen
		sbar.delay(0.3, function()
			if _space_change_gen ~= my_gen then
				return
			end
			updateWindows()
		end)
	end)

	-- display_change
	root:subscribe("display_change", function()
		local h = settings.detect_bar_height()
		sbar.bar({ height = h })
		updateWorkspaceMonitor()
		updateWindows()
	end)

	-- aerospace_fullscreen_change
	root:subscribe("aerospace_fullscreen_change", function()
		sbar.exec("aerospace list-workspaces --focused", function(focused)
			focused = focused and focused:match("^%s*(.-)%s*$")
			if focused then
				for ws_idx, ws in pairs(workspaces) do
					set_highlight(ws, ws_idx == focused)
				end
			end
		end)
		updateWindows()
	end)

	-- aerospace_mode_change
	root:subscribe("aerospace_mode_change", function(_)
		sbar.exec("aerospace list-modes --current", function(result)
			local is_service = (result or ""):match("service") ~= nil
			mode_item:set({ drawing = is_service })
		end)
	end)

	-- theme_changed
	root:subscribe("theme_changed", function()
		for _, ws_idx in ipairs(workspace_order) do
			local ws = workspaces[ws_idx]
			if ws then
				ws:set({
					background = { color = appearance.colors.pill_bg },
					icon = { color = appearance.colors.pill_fg },
					label = { color = appearance.colors.pill_fg },
					popup = { background = { color = appearance.with_alpha(appearance.colors.pill_bg, 0.85) } },
				})
			end
		end
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
		updateWindows()
	end)

	-- 初始 focus
	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		if not focused_workspace then
			return
		end
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		if workspaces[focused_workspace] then
			set_highlight(workspaces[focused_workspace], true)
		end
	end)
end)
