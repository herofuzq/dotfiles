-- ========== aerospace 工作区显示 ==========
-- 通过 aerospace CLI 查询窗口和屏幕信息，动态显示各工作区的应用图标
-- 工作区边框由 borders.lua 动态分配，空工作区隐藏 label、icon 居中
local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local borders = require("helpers.borders")
local sbar = require("sketchybar")

-- 始终显示的工作区（即使没有应用也会显示）
local always_show = {
	["1̲Main"] = true,
	["C̲hat"] = true,
	["T̲erm"] = true,
	["Web̲"] = true,
	["W̲ork"] = true,
	["M̲edia"] = true,
}
-- aerospace 查询命令模板
local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- 用于订阅事件的虚拟根条目（不显示）
local root = sbar.add("item", { drawing = false })
local workspaces = {} -- 工作区名 → 条目对象的映射
local workspace_order = {} -- 工作区创建顺序（保持显示顺序一致）

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
local function withWindows(f)
	local open_windows = {} -- 工作区 → 应用列表
	local has_fullscreen = {} -- 工作区是否有全屏窗口

	local get_windows =
		"aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}%{window-is-fullscreen}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"

	sbar.exec(get_windows, function(workspace_and_windows)
		local processed_windows = {} -- 去重用：记录已处理的窗口 ID

		for _, entry in ipairs(workspace_and_windows) do
			local workspace_index = entry.workspace
			local app = entry["app-name"]
			local window_id = entry["window-id"]

			if entry["window-is-fullscreen"] then
				has_fullscreen[workspace_index] = true
			end

			-- 每个窗口只统计一次（同一应用可能有多个窗口）
			if not processed_windows[window_id] then
				processed_windows[window_id] = true

				if open_windows[workspace_index] == nil then
					open_windows[workspace_index] = {}
				end

				-- 去重：同一应用不重复添加
				local app_exists = false
				for _, existing_app in ipairs(open_windows[workspace_index]) do
					if existing_app == app then
						app_exists = true
						break
					end
				end

				if not app_exists then
					table.insert(open_windows[workspace_index], app)
				end
			end
		end

		-- 嵌套查询：先查聚焦工作区，再查可见工作区，最后统一处理
		sbar.exec(get_focus_workspaces, function(focused_workspace)
			focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
			sbar.exec(query_visible_workspaces, function(visible_workspaces)
				local args = {
					open_windows = open_windows,
					focused_workspace = focused_workspace,
					visible_workspaces = visible_workspaces,
					has_fullscreen = has_fullscreen,
				}
				f(args)
			end)
		end)
	end)
end

-- ========== 更新单个工作区的显示 ==========
-- 决定显示应用图标 / 月亮占位符 / 隐藏
local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index]
	local focused_workspace = args.focused_workspace
	local visible_workspaces = args.visible_workspaces

	if open_windows == nil then
		open_windows = {}
	end

	-- 拼接应用图标字符串（使用 sketchybar-app-font 的 :name: 格式）
	local icon_line = ""
	local no_app = true
	for _, open_window in ipairs(open_windows) do
		no_app = false
		local app = open_window
		local lookup = app_icons[app]
		local icon = ((lookup == nil) and app_icons["Default"] or lookup)
		icon_line = icon_line .. "" .. icon
	end

	sbar.animate("tanh", 10, function()
		-- 情况1：没有应用，但工作区当前在屏幕上可见 → 隐藏 label，icon 居中
		for _, visible_workspace in ipairs(visible_workspaces) do
			if no_app and workspace_index == visible_workspace["workspace"] then
				local monitor_id = math.floor(visible_workspace["monitor-appkit-nsscreen-screens-id"])
				workspaces[workspace_index]:set({
					drawing = true,
					icon = { padding_left = 10, padding_right = 10 },
					label = { drawing = false },
					display = monitor_id,
				})
				return
			end
		end

		-- 情况2：没有应用，也不聚焦 → 如果在 always_show 列表中则显示（隐藏 label），否则隐藏
		if no_app and workspace_index ~= focused_workspace then
			if always_show[workspace_index] then
				workspaces[workspace_index]:set({
					drawing = true,
					icon = { padding_left = 10, padding_right = 10 },
					label = { drawing = false },
				})
				return
			end
			workspaces[workspace_index]:set({
				drawing = false,
			})
			return
		end

		-- 情况3：没有应用，但是聚焦的工作区 → 隐藏 label，icon 居中
		if no_app and workspace_index == focused_workspace then
			workspaces[workspace_index]:set({
				drawing = true,
				icon = { padding_left = 10, padding_right = 10 },
				label = { drawing = false },
			})
			return
		end

		-- 情况4：有应用 → 显示应用图标
		workspaces[workspace_index]:set({
			drawing = true,
			icon = { padding_left = 10, padding_right = 2 },
			label = { drawing = true, string = icon_line },
		})
	end)
end

-- ========== 更新所有工作区 + 分配边框颜色 ==========
local function updateWindows()
	withWindows(function(args)
		-- 第一步：更新每个工作区的窗口内容
		for workspace_index, _ in pairs(workspaces) do
			updateWindow(workspace_index, args)
		end

		-- 第二步：按创建顺序收集所有「可见」的工作区
		local visible = {}
		for _, ws_idx in ipairs(workspace_order) do
			local open = args.open_windows[ws_idx]
			local has_apps = open and #open > 0
			local is_visible = has_apps

			-- 当前在屏幕上的工作区也算可见
			if not is_visible then
				for _, vw in ipairs(args.visible_workspaces) do
					if vw["workspace"] == ws_idx then
						is_visible = true
						break
					end
				end
			end
			-- 聚焦的工作区始终可见
			if not is_visible and ws_idx == args.focused_workspace then
				is_visible = true
			end
			-- always_show 列表中的工作区始终可见
			if not is_visible and always_show[ws_idx] then
				is_visible = true
			end

			if is_visible then
				table.insert(visible, ws_idx)
			end
		end

		-- 第三步：通过中央调色器分配边框颜色
		local visible_names = {}
		for _, ws_idx in ipairs(visible) do
			visible_names[#visible_names + 1] = "workspace." .. ws_idx
		end
		borders.distribute(visible_names)

		-- 第四步：全屏工作区特殊处理（覆盖为红边框 + 加粗）
		sbar.animate("tanh", 10, function()
			for _, ws_idx in ipairs(visible) do
				workspaces[ws_idx]:set({
					icon = { highlight_color = 0xffff4444 },
				})
				if args.has_fullscreen[ws_idx] then
					workspaces[ws_idx]:set({
						background = { border_color = 0xffff4444, border_width = 4 },
					})
				end
			end
		end)
	end)
end

-- ========== 多显示器支持：更新工作区所属显示器 ==========
local function updateWorkspaceMonitor()
	local workspace_monitor = {}
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
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
sbar.exec(query_workspaces, function(workspaces_and_monitors)
	for i, entry in ipairs(workspaces_and_monitors) do
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
			shadow = "on",
			background = bg,
			click_script = "aerospace workspace " .. workspace_index, -- 点击切换到该工作区
			drawing = false, -- 初始隐藏，稍后由 updateWindow 决定显示/隐藏
			padding_left = 2,
			padding_right = 2,
			icon = { -- 显示工作区名称（如 "Web", "C̲hat"）
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
		})

		workspaces[workspace_index] = workspace
		table.insert(workspace_order, workspace_index)

		-- 订阅工作区切换事件，更新高亮状态
		workspace:subscribe("aerospace_workspace_change", function(env)
			local focused_workspace = env.FOCUSED_WORKSPACE
			local is_focused = focused_workspace == workspace_index

			sbar.animate("tanh", 10, function()
				workspace:set({
					icon = { highlight = is_focused },
					label = { highlight = is_focused },
				})
			end)
		end)
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

	-- 工作区切换时更新窗口列表
	root:subscribe("aerospace_workspace_change", function()
		updateWindows()
	end)

	-- 前台应用切换时更新（可能新建/关闭窗口）
	root:subscribe("front_app_switched", function()
		updateWindows()
	end)

	-- 显示器变化时（插拔显示器）重新分配
	root:subscribe("display_change", function()
		updateWorkspaceMonitor()
		updateWindows()
	end)

	-- 全屏切换时刷新边框
	root:subscribe("aerospace_fullscreen_change", updateWindows)

	-- aerospace 模式切换时显示/隐藏模式图标
	root:subscribe("aerospace_mode_change", function(env)
		sbar.exec("aerospace list-modes --current", function(result)
			local is_service = result:match("service") ~= nil
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
				})
			end
		end
		-- 更新 i3（固定深色模式颜色）和 aerospace_mode 文字色
		sbar.set("i3", { icon = { color = 0xff74c7ec } })
		sbar.set("aerospace_mode", { label = { color = appearance.colors.active.deep_blue } })
		-- 重新分发边框色（borders.lua 已通过 set_theme 知道当前主题）
		updateWindows()
	end)

	-- 查询初始聚焦的工作区，标记为高亮
	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		if workspaces[focused_workspace] then
			workspaces[focused_workspace]:set({
				icon = { highlight = true },
				label = { highlight = true },
			})
		end
	end)
end)
