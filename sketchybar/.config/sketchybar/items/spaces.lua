-- ========== aerospace 工作区显示 ==========
-- 双模式：USE_AEROSPACE = true 用 aerospace，false 用原生 macOS Space
local USE_AEROSPACE = false
-- 通过 aerospace CLI 查询窗口和屏幕信息，动态显示各工作区的应用图标
-- 工作区边框由 borders.lua 动态分配，空工作区隐藏 label、icon 居中
local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local borders = require("helpers.borders")
local sbar = require("sketchybar")
local fonts = require("fonts")
local settings = require("settings")

-- 始终显示的工作区（即使没有应用也会显示）
-- 注：键名含 U+0332 组合下划线，对应 aerospace 工作区名称，请勿修改
local always_show = {
	["1̲Main"] = true,
	["2̲Sec"] = true,
	["3̲Chat"] = true,
	["4̲Work"] = true,
	["5̲Term"] = true,
	-- ["6̲Play"] = true,  -- 6̲Play 不强制常显（仅在有窗口或被聚焦时显示）
}
-- aerospace 查询命令模板
local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- 用于订阅事件的虚拟根条目（不显示）
local root = sbar.add("item", "spaces.root", { drawing = false })
local workspaces = {} -- 工作区名 → 条目对象的映射
local workspace_order = {} -- 工作区创建顺序（保持显示顺序一致）
local MAX_POPUP_SLOTS = 10
local _popup_items = {}   -- { [ws_name] = { item1, ..., item10 } }
local _popup_windows = {} -- { [ws_name] = { {id, app, title}, ... } }
local _popup_pinned = {}   -- { [ws_name] = true/false } 记录点击固定状态，固定后鼠标离开不隐藏
local _popup_gen = {}     -- { [ws_name] = gen } 防止 hover 异步回调覆盖 mouse.exited.global 的隐藏
local _popup_hovering = {} -- { [ws_name] = true/false } 鼠标当前是否在 popup 子项上
local _popup_exit_gen = {} -- { [ws_name] = gen } 延迟隐藏的代数，进入 popup 时作废旧延迟

-- aerospace 模式指示器（当前仅在 service 模式下显示 "󰰣" 图标）
local mode_item = sbar.add("item", "aerospace_mode", {
	position = "left",
	padding_left = 2,
	padding_right = 2,
	icon = { drawing = false },
	label = {
		string = "󰰣",
		font = "Hack Nerd Font:Bold:28.0",
		padding_left = 4,
		padding_right = 4,
		color = appearance.colors.active.deep_blue,
	},
	background = { drawing = false },
	drawing = false,
})

-- ========== 窗口信息收集函数 ==========
-- 调用多个 aerospace 命令，收集窗口列表、可见工作区、聚焦工作区
-- 最终调用回调函数 f(args)
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

-- ========== 更新单个工作区的显示 ==========
-- 决定显示应用图标 / 隐藏
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
	if _popup_pinned[ws_index] then return end
	local gen = (_popup_exit_gen[ws_index] or 0) + 1
	_popup_exit_gen[ws_index] = gen
	sbar.delay(0.2, function()
		if _popup_exit_gen[ws_index] ~= gen then return end
		if _popup_hovering[ws_index] or _popup_pinned[ws_index] then return end
		workspace:set({ popup = { drawing = false } })
	end)
end

-- ========== Popup：展示/切换工作区窗口列表 ==========
-- force_show=true 用于 hover（总是展示，不 toggle），留空则是 toggle（点击切换）
local function togglePopup(ws_index, workspace_item, force_show, gen)
	if not workspace_item then return end

	local cmd = "aerospace list-windows --workspace \""
		.. ws_index
		.. "\" --format '%{window-id}%{app-name}%{window-title}' --json"

	sbar.exec(cmd, function(windows)
		if not windows or #windows == 0 then
			return
		end

		_popup_windows[ws_index] = {}
		for i, w in ipairs(windows) do
			if i > MAX_POPUP_SLOTS then break end
			local id = w["window-id"]
			if not id then break end
			_popup_windows[ws_index][i] = {
				id = id,
				app = w["app-name"] or "?",
				title = (w["window-title"] and #w["window-title"] > 0 and w["window-title"]) or w["app-name"] or "Untitled",
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
                  icon = { string = icon, color = appearance.colors.active.sep_opaque },
                  label = { string = win.title, color = appearance.colors.active.text },
               })
				else
					item:set({ drawing = false })
				end
			end
		end

      if gen and _popup_gen[ws_index] ~= gen then return end

      local drawing = force_show and true or "toggle"
      workspace_item:set({ popup = { drawing = drawing } })
	end)
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
		if not workspaces_and_monitors then return end
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

-- ========== 初始化：为每个工作区创建 sketchybar 条目 ==========
if USE_AEROSPACE then
sbar.exec(query_workspaces, function(workspaces_and_monitors)
	if not workspaces_and_monitors then return end
	for _, entry in ipairs(workspaces_and_monitors) do
		local workspace_index = entry.workspace
		local style = appearance.styles.workspace -- 引用 appearance 中的样式模板

		-- 初始边框色（稍后会被 borders.distribute() 覆盖）
		local bg = {
			color = style.background.color,
			drawing = style.background.drawing,
			corner_radius = style.background.corner_radius,
			border_width = style.background.border_width,
			border_color = appearance.colors.active.mauve, -- 初始色（与当前主题匹配，由 borders.distribute() 立即覆盖）
		}

		local workspace = sbar.add("item", "workspace." .. workspace_index, {
			background = bg,

			drawing = false, -- 初始隐藏，稍后由 updateWindow 决定显示/隐藏
			padding_left = 2,
			padding_right = 2,
			icon = { -- 显示工作区名称（如 "3̲Chat", "5̲Term"）
				color = style.icon.color,
				highlight_color = style.icon.highlight_color,
				font = style.icon.font,
				padding_left = style.icon.padding_left,
				padding_right = style.icon.padding_right,
				drawing = true,
				string = workspace_index,
			},
			label = { -- 显示应用图标字符串
				color = style.label.color,
				highlight_color = style.label.highlight_color,
				font = style.label.font,
				padding_left = style.label.padding_left,
				padding_right = style.label.padding_right,
				y_offset = style.label.y_offset,
				drawing = true,
			},
			popup = {
				align = "left",
				background = {
					color = appearance.colors.with_alpha(appearance.colors.active.bar_bg, 0.85),
					corner_radius = 12,
					border_width = 2,
					shadow = { drawing = false },
				},
				blur_radius = 30,
			},
		})

		workspaces[workspace_index] = workspace
		table.insert(workspace_order, workspace_index)

		workspace:subscribe("mouse.entered", function()
			_popup_exit_gen[workspace_index] = (_popup_exit_gen[workspace_index] or 0) + 1
			local gen = (_popup_gen[workspace_index] or 0) + 1
			_popup_gen[workspace_index] = gen
			togglePopup(workspace_index, workspace, true, gen)
		end)

		workspace:subscribe("mouse.exited", function()
			scheduleHide(workspace_index, workspace)
		end)

		workspace:subscribe("mouse.exited.global", function()
			_popup_exit_gen[workspace_index] = (_popup_exit_gen[workspace_index] or 0) + 1
			_popup_gen[workspace_index] = (_popup_gen[workspace_index] or 0) + 1
			if not _popup_pinned[workspace_index] then
				workspace:set({ popup = { drawing = false } })
			end
		end)

		workspace:subscribe("mouse.clicked", function()
			sbar.exec("aerospace list-workspaces --focused", function(focused)
				focused = focused and focused:match("^%s*(.-)%s*$")
				if focused == workspace_index then
					_popup_pinned[workspace_index] = not _popup_pinned[workspace_index]
					togglePopup(workspace_index, workspace)
				else
					for k, _ in pairs(_popup_pinned) do
						_popup_pinned[k] = false
					end
					sbar.exec("aerospace workspace \"" .. workspace_index .. "\"")
				end
			end)
		end)

		_popup_items[workspace_index] = {}
		for i = 1, MAX_POPUP_SLOTS do
			local popup_item = sbar.add("item", "workspace." .. workspace_index .. ".popup." .. i, {
				position = "popup.workspace." .. workspace_index,
				drawing = false,
				icon = {
					font = "sketchybar-app-font:Regular:14.0",
					padding_left = 12,
					padding_right = 6,
					color = appearance.colors.active.sep_opaque,
				},
				label = {
					font = {
						family = fonts.font.text,
						style = fonts.font.style_map["Semibold"],
						size = fonts.font.size,
					},
					padding_left = 0,
					padding_right = 16,
					max_chars = 50,
					color = appearance.colors.active.text,
				},
				background = { drawing = false },
			})
			_popup_items[workspace_index][i] = popup_item

		popup_item:subscribe("mouse.entered", function()
			_popup_exit_gen[workspace_index] = (_popup_exit_gen[workspace_index] or 0) + 1
			_popup_hovering[workspace_index] = true
			popup_item:set({
				icon = { color = 0xffff4444 },
				label = { color = 0xffff4444 },
			})
		end)
		popup_item:subscribe("mouse.exited", function()
			_popup_hovering[workspace_index] = false
			popup_item:set({
				icon = { color = appearance.colors.active.sep_opaque },
				label = { color = appearance.colors.active.text },
			})
			scheduleHide(workspace_index, workspace)
		end)

			popup_item:subscribe("mouse.clicked", function()
				local win = _popup_windows[workspace_index] and _popup_windows[workspace_index][i]
				if win then
					sbar.exec("aerospace focus --window-id " .. win.id)
					workspace:set({ popup = { drawing = false } })
				end
			end)
		end
	end

	-- 装饰性文字（左侧 "Powered by " —  为 i3 window management 图标，保留作装饰用）
	sbar.add("item", "i3", {
		position = "left",
		padding_left = 2,
		padding_right = 2,
		icon = {
			string = "Powered by ",
			font = "Hack Nerd Font:Bold:10.0",
			padding_left = 6,
			padding_right = 6,
			color = 0xff74c7ec, -- 固定使用深色模式颜色，不随主题变化
		},
		label = { drawing = false },
		background = { drawing = false },
	})

	-- 首次加载
	updateWindows()
	updateWorkspaceMonitor()

	-- ===== 事件订阅 =====

	-- 工作区切换时立即更新高亮（用 env 变量，0ms 延迟） + 异步更新窗口内容
	-- 这替代了 6a39153 移除的 per-workspace subscription
	root:subscribe("aerospace_workspace_change", function(env)
		local focused = env.FOCUSED_WORKSPACE
		if focused then
			for k, _ in pairs(_popup_pinned) do
				_popup_pinned[k] = false
			end
			for k, _ in pairs(_popup_hovering) do
				_popup_hovering[k] = false
			end
			for ws_idx, ws in pairs(workspaces) do
				local is_focused = (ws_idx == focused)
				ws:set({
					icon = { highlight = is_focused },
					label = { highlight = is_focused },
					popup = { drawing = false },
				})
			end
		end
		updateWindows()
	end)

	-- 窗口变化时更新（Hammerspoon window_watcher 50ms 防抖后单源触发，
	-- 之前 front_app_switched 兜底会跟它撞车 → 6 个 sbar.exec 挤在 layout
	-- 切换窗口期里把 1 帧的 tile→float 拖成可见的"飞"。去掉兜底后单源化
	-- 延迟 300ms 执行，避免 IPC 查询干扰 aerospace 处理 on-window-detected
	-- 原因：aerospace 处理新窗口是先放进布局树、再配成浮动。Hammerspoon 的 windowCreated
	-- 事件到达 sketchybar 时（~50ms 后），我们发起的 3 条 aerospace CLI IPC 查询
	--（list-windows, list-workspaces）会让 daemon 遍历窗口树。这个遍历会把已经设成
	-- 浮动的窗口短暂"钩"回布局排列位置，等 IPC 结束后才恢复。用户就会看到先平铺再浮动的闪烁。
	-- 解决方法：等 300ms 再查，aerospace 早就处理完了，tree 遍历钩不到了。
	local _space_change_gen = 0
	root:subscribe("space_windows_change", function()
		local my_gen = _space_change_gen + 1
		_space_change_gen = my_gen
		sbar.delay(0.3, function()
			if _space_change_gen ~= my_gen then return end
			updateWindows()
		end)
	end)

	-- 显示器变化时（插拔显示器）重新分配
	root:subscribe("display_change", function()
		local h = settings.detect_bar_height()
		sbar.bar({ height = h })
		updateWorkspaceMonitor()
		updateWindows()
	end)

	-- 全屏切换时刷新边框
	root:subscribe("aerospace_fullscreen_change", updateWindows)

	-- aerospace 模式切换时显示/隐藏模式图标
	root:subscribe("aerospace_mode_change", function(_)
		sbar.exec("aerospace list-modes --current", function(result)
			local is_service = (result or ""):match("service") ~= nil
			mode_item:set({ drawing = is_service })
		end)
	end)

	-- 主题切换时更新所有工作区背景色 + 静态装饰项 + 边框色
	root:subscribe("theme_changed", function()
		for _, ws_idx in ipairs(workspace_order) do
			local ws = workspaces[ws_idx]
			if ws then
				ws:set({
					background = { color = appearance.colors.active.bar_bg },
					icon = { color = appearance.styles.workspace.icon.color },
					label = { color = appearance.styles.workspace.label.color },
					popup = {
						background = {
							color = appearance.colors.with_alpha(appearance.colors.active.bar_bg, 0.85),
						},
					},
				})
			end
		end
		-- 更新所有 popup 子项颜色（跟随亮色/暗色主题切换）
		for ws_idx, items in pairs(_popup_items) do
			for i, item in ipairs(items) do
				if item then
					item:set({
						icon = { color = appearance.colors.active.sep_opaque },
						label = { color = appearance.colors.active.text },
					})
				end
			end
		end
		-- 更新 i3（固定深色模式颜色）和 aerospace_mode 文字色
		sbar.set("i3", { icon = { color = 0xff74c7ec } })
		sbar.set("aerospace_mode", { label = { color = appearance.colors.active.deep_blue } })
		-- 重新分发边框色（borders.lua 已通过 set_theme 知道当前主题）
		updateWindows()
	end)

	-- （已移除 front_app_switched 兜底订阅，理由见 space_windows_change 注释）

	-- 查询初始聚焦的工作区，标记为高亮
	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		if not focused_workspace then return end
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		if workspaces[focused_workspace] then
			workspaces[focused_workspace]:set({
				icon = { highlight = true },
				label = { highlight = true },
			})
		end
	end)
end)
end

if not USE_AEROSPACE then
-- ══════════════════════════════════════════════════════════
-- 原生 macOS Space 模式（tangrid 等）
-- 桌面 1-6，读取 Hammerspoon space_bridge 的 JSON 数据
-- ══════════════════════════════════════════════════════════
local MAX_POPUP_SLOTS = 10
local _n_workspaces = {}
local _n_ws_order = {}
local _n_popup_items = {}
local _n_popup_windows = {}
local _n_pinned = {}
local _n_gen = {}
local _n_hovering = {}
local _n_exit_gen = {}
local SPACE_COUNT = 6

local function _n_readSpaceData()
	local f = io.open("/tmp/sketchybar_spaces.json", "r")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	local focused = tonumber(data:match('"focused":%s*(%d+)'))
	local spaces = {}
	for mc_id, id_str in data:gmatch('"mc_id":%s*(%d+)[^}]*"id":%s*(%d+)') do
		local sid = tonumber(id_str)
		local wins = {}
		local block = data:match('"mc_id":%s*' .. mc_id .. '[^%]]*%[(.-)%]')
		if block then
			for app, title in block:gmatch('"app":"([^"]-)"[^}]-"title":"([^"]-)"') do
				wins[#wins + 1] = { app = app, title = title }
			end
		end
		spaces[tonumber(mc_id)] = { id = sid, windows = wins }
	end
	return { focused = focused, spaces = spaces }
end

local function _n_scheduleHide(idx, ws)
	_n_gen[idx] = (_n_gen[idx] or 0) + 1
	if _n_pinned[idx] then return end
	local gen = (_n_exit_gen[idx] or 0) + 1
	_n_exit_gen[idx] = gen
	sbar.delay(0.2, function()
		if _n_exit_gen[idx] ~= gen then return end
		if _n_hovering[idx] or _n_pinned[idx] then return end
		ws:set({ popup = { drawing = false } })
	end)
end

local function _n_showPopup(idx, ws)
	local data = _n_readSpaceData()
	if not data then return end
	_n_popup_windows[idx] = {}
	local count = 0
	for mc_id, s in pairs(data.spaces or {}) do
		if idx == mc_id then
			for _, w in ipairs(s.windows or {}) do
				count = count + 1
				if count > MAX_POPUP_SLOTS then break end
				_n_popup_windows[idx][count] = { app = w.app, title = w.title }
			end
			break
		end
	end
	for _, w in pairs(_n_workspaces) do
		if w ~= ws then w:set({ popup = { drawing = false } }) end
	end
	for i = 1, MAX_POPUP_SLOTS do
		local item = _n_popup_items[idx] and _n_popup_items[idx][i]
		local win = _n_popup_windows[idx] and _n_popup_windows[idx][i]
		if item then
			if win then
				local icon = app_icons[win.app] or app_icons["Default"]
				item:set({ drawing = true, icon = { string = icon, color = appearance.colors.active.sep_opaque }, label = { string = win.title, color = appearance.colors.active.text } })
			else
				item:set({ drawing = false })
			end
		end
	end
	ws:set({ popup = { drawing = true } })
end

for i = 1, SPACE_COUNT do
	local ws_name = tostring(i)
	local style = appearance.styles.workspace
	local ws = sbar.add("item", "workspace." .. ws_name, {
		background = { color = style.background.color, drawing = style.background.drawing, corner_radius = style.background.corner_radius, border_width = style.background.border_width, border_color = appearance.colors.active.mauve },
		drawing = true, padding_left = 2, padding_right = 2,
		icon = { color = style.icon.color, highlight_color = style.icon.highlight_color, font = style.icon.font,
			padding_left = 10, padding_right = 10, drawing = true, string = ws_name .. ">" },
		label = { color = style.label.color, highlight_color = style.label.highlight_color, font = style.label.font,
			padding_left = style.label.padding_left, padding_right = style.label.padding_right, y_offset = style.label.y_offset, drawing = false },
		popup = { align = "left", background = { color = appearance.colors.with_alpha(appearance.colors.active.bar_bg, 0.85), corner_radius = 12, border_width = 2, shadow = { drawing = false } }, blur_radius = 30 },
	})
	_n_workspaces[ws_name] = ws
	_n_ws_order[#_n_ws_order + 1] = ws_name

	ws:subscribe("mouse.entered", function() _n_showPopup(i, ws) end)
	ws:subscribe("mouse.exited", function() _n_scheduleHide(ws_name, ws) end)
	ws:subscribe("mouse.exited.global", function()
		_n_exit_gen[ws_name] = (_n_exit_gen[ws_name] or 0) + 1
		if not _n_pinned[ws_name] then ws:set({ popup = { drawing = false } }) end
	end)
	ws:subscribe("mouse.clicked", function()
		local f = io.open("/tmp/sketchybar_space_switch", "w")
		if f then f:write(tostring(i)); f:close() end
		_n_pinned[ws_name] = not _n_pinned[ws_name]
		_n_showPopup(i, ws)
	end)

	_n_popup_items[ws_name] = {}
	for j = 1, MAX_POPUP_SLOTS do
		local pi = sbar.add("item", "workspace." .. ws_name .. ".popup." .. j, {
			position = "popup.workspace." .. ws_name, drawing = false,
			icon = { font = "sketchybar-app-font:Regular:14.0", padding_left = 12, padding_right = 6, color = appearance.colors.active.sep_opaque },
			label = { font = { family = fonts.font.text, style = fonts.font.style_map["Semibold"], size = fonts.font.size }, padding_left = 0, padding_right = 16, max_chars = 50, color = appearance.colors.active.text },
			background = { drawing = false },
		})
		_n_popup_items[ws_name][j] = pi
		pi:subscribe("mouse.entered", function()
			_n_exit_gen[ws_name] = (_n_exit_gen[ws_name] or 0) + 1
			_n_hovering[ws_name] = true
			pi:set({ icon = { color = 0xffff4444 }, label = { color = 0xffff4444 } })
		end)
		pi:subscribe("mouse.exited", function()
			_n_hovering[ws_name] = false
			pi:set({ icon = { color = appearance.colors.active.sep_opaque }, label = { color = appearance.colors.active.text } })
			_n_scheduleHide(ws_name, ws)
		end)
	end
end

-- 用 sketchybar 原生 space_windows_change 获取各桌面应用图标
-- 同时订阅 space_changed（来自 Hammerspoon）获取 popup 窗口标题数据
local _n_root = sbar.add("item", "spaces_native.root", { drawing = false })
_n_root:subscribe("space_windows_change", function(env)
	if not env.INFO or not env.INFO.apps then return end
	local sid = env.INFO.space
	local icons = ""
	for app, count in pairs(env.INFO.apps) do
		for _ = 1, (count or 1) do
			icons = icons .. (app_icons[app] or app_icons["Default"])
		end
	end
	local ws = _n_workspaces[tostring(sid)]
	if ws then
		if #icons > 0 then
			ws:set({ icon = { padding_left = 10, padding_right = 2 }, label = { drawing = true, string = icons } })
		else
			ws:set({ icon = { padding_left = 10, padding_right = 10 }, label = { drawing = false } })
		end
	end
	-- 边框：收集有内容的 workspace（延迟执行等所有 item 就绪）
	local names = {}
	for _, n in ipairs(_n_ws_order) do
		if _n_workspaces[n] then names[#names + 1] = "workspace." .. n end
	end
	if #names > 0 then
		sbar.delay(0.1, function() borders.distribute(names) end)
	end
end)

-- 首次加载时触发边框分配（延迟等 widget/calendar 就绪）
sbar.delay(0.2, function()
	borders.distribute({ "workspace.1", "workspace.2", "workspace.3", "workspace.4", "workspace.5", "workspace.6" })
end)

-- 订阅 Hammerspoon space_changed → 聚焦高亮 + popup 数据
root:subscribe("space_changed", function()
	local data = _n_readSpaceData()
	if not data then return end
	for ws_idx, ws in pairs(_n_workspaces) do
		local is_focused = false
		for _, s in pairs(data.spaces or {}) do
			if tonumber(ws_idx) == (s.mc_id or s.id) and s.id == data.focused then
				is_focused = true
				break
			end
		end
		ws:set({ icon = { highlight = is_focused }, label = { highlight = is_focused } })
	end
end)
end
