local appearance = require("appearance")
local app_icons = require("helpers.app_icons")
local sbar = require("sketchybar")

local workspace_names = {
	["1"] = "Web",
	["2"] = "Code",
	["3"] = "Media",
	["4"] = "Editing",
	["5"] = "Gaming",
	["6"] = "Work",
	["7"] = "7",
	["8"] = "8",
	["9"] = "9",
	["A"] = "Code",
	["B"] = "SMS",
	["C"] = "Bros",
	["D"] = "Misc",
}

local border_gradient = {
	appearance.colors.tokyo_night.mauve,
	appearance.colors.tokyo_night.lavender,
	appearance.colors.tokyo_night.sapphire,
	appearance.colors.tokyo_night.blue,
	appearance.colors.tokyo_night.sky,
	appearance.colors.tokyo_night.teal,
	appearance.colors.tokyo_night.green,
	appearance.colors.tokyo_night.yellow,
	appearance.colors.tokyo_night.peach,
	appearance.colors.tokyo_night.rosewater,
	appearance.colors.tokyo_night.flamingo,
	appearance.colors.tokyo_night.pink,
	appearance.colors.tokyo_night.maroon,
	appearance.colors.tokyo_night.red,
}

local ordered_indices = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D" }

local query_workspaces =
	"aerospace list-workspaces --all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"

-- Root is used to handle event subscriptions
local root = sbar.add("item", { drawing = false })
local workspaces = {}
local workspace_order = {}
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

local function withWindows(f)
	local open_windows = {}
	local has_fullscreen = {}
	-- Include the window ID in the query so we can track unique windows
	local get_windows =
		"aerospace list-windows --monitor all --format '%{workspace}%{app-name}%{window-id}%{window-is-fullscreen}' --json"
	local query_visible_workspaces =
		"aerospace list-workspaces --visible --monitor all --format '%{workspace}%{monitor-appkit-nsscreen-screens-id}' --json"
	local get_focus_workspaces = "aerospace list-workspaces --focused"
	sbar.exec(get_windows, function(workspace_and_windows)
		-- Use a set to track unique window IDs
		local processed_windows = {}

		for _, entry in ipairs(workspace_and_windows) do
			local workspace_index = entry.workspace
			local app = entry["app-name"]
			local window_id = entry["window-id"]

			if entry["window-is-fullscreen"] then
				has_fullscreen[workspace_index] = true
			end

			-- Only process each window ID once
			if not processed_windows[window_id] then
				processed_windows[window_id] = true

				if open_windows[workspace_index] == nil then
					open_windows[workspace_index] = {}
				end

				-- Check if this app is already in the list for this workspace
				local app_exists = false
				for _, existing_app in ipairs(open_windows[workspace_index]) do
					if existing_app == app then
						app_exists = true
						break
					end
				end

				-- Only add the app if it's not already in the list
				if not app_exists then
					table.insert(open_windows[workspace_index], app)
				end
			end
		end

		sbar.exec(get_focus_workspaces, function(focused_workspaces)
			sbar.exec(query_visible_workspaces, function(visible_workspaces)
				local args = {
					open_windows = open_windows,
					focused_workspaces = focused_workspaces,
					visible_workspaces = visible_workspaces,
					has_fullscreen = has_fullscreen,
				}
				f(args)
			end)
		end)
	end)
end

local function updateWindow(workspace_index, args)
	local open_windows = args.open_windows[workspace_index]
	local focused_workspaces = args.focused_workspaces
	local visible_workspaces = args.visible_workspaces

	if open_windows == nil then
		open_windows = {}
	end

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
		for _, visible_workspace in ipairs(visible_workspaces) do
			if no_app and workspace_index == visible_workspace["workspace"] then
				local monitor_id = visible_workspace["monitor-appkit-nsscreen-screens-id"]
				icon_line = " —"
				workspaces[workspace_index]:set({
					drawing = true,
					["label.string"] = icon_line,
					display = monitor_id,
				})
				return
			end
		end
		if no_app and workspace_index ~= focused_workspaces then
			workspaces[workspace_index]:set({
				drawing = false,
			})
			return
		end
		if no_app and workspace_index == focused_workspaces then
			icon_line = " —"
			workspaces[workspace_index]:set({
				drawing = true,
				["label.string"] = icon_line,
			})
		end

		workspaces[workspace_index]:set({
			drawing = true,
			["label.string"] = icon_line,
		})
	end)
end

local function updateWindows()
	withWindows(function(args)
		for workspace_index, _ in pairs(workspaces) do
			updateWindow(workspace_index, args)
		end

		-- Dynamic gradient: collect visible workspaces in creation order
		local visible = {}
		for _, ws_idx in ipairs(workspace_order) do
			local open = args.open_windows[ws_idx]
			local has_apps = open and #open > 0
			local is_visible = has_apps

			if not is_visible then
				for _, vw in ipairs(args.visible_workspaces) do
					if vw["workspace"] == ws_idx then
						is_visible = true
						break
					end
				end
			end
			if not is_visible and ws_idx == args.focused_workspaces then
				is_visible = true
			end

			if is_visible then
				table.insert(visible, ws_idx)
			end
		end

		-- Assign border colors
		sbar.animate("tanh", 10, function()
			for i, ws_idx in ipairs(visible) do
				local fullscreen = args.has_fullscreen[ws_idx]
				local border_color, border_width
				if fullscreen then
					border_color = appearance.colors.tokyo_night.accent_opaque
					border_width = 4
				else
					local idx = i % #border_gradient
					if idx == 0 then
						idx = #border_gradient
					end
					border_color = border_gradient[idx]
					border_width = 2
				end
				workspaces[ws_idx]:set({
					background = { border_color = border_color, border_width = border_width },
					icon = { color = border_color, highlight_color = appearance.colors.tokyo_night.mauve },
				})
			end
		end)
	end)
end

local function updateWorkspaceMonitor()
	local workspace_monitor = {}
	sbar.exec(query_workspaces, function(workspaces_and_monitors)
		for _, entry in ipairs(workspaces_and_monitors) do
			local space_index = entry.workspace
			local monitor_id = math.floor(entry["monitor-appkit-nsscreen-screens-id"])
			workspace_monitor[space_index] = monitor_id
		end
		for workspace_index, _ in pairs(workspaces) do
			workspaces[workspace_index]:set({
				display = workspace_monitor[workspace_index],
			})
		end
	end)
end

sbar.exec(query_workspaces, function(workspaces_and_monitors)
	for i, entry in ipairs(workspaces_and_monitors) do
		local workspace_index = entry.workspace
		local style = appearance.styles.workspace

		local border_idx = i % #border_gradient
		if border_idx == 0 then
			border_idx = #border_gradient
		end
		local border_color = border_gradient[border_idx]

		local bg = {
			color = style.background.color,
			drawing = style.background.drawing,
			corner_radius = style.background.corner_radius,
			border_width = style.background.border_width,
			border_color = border_color,
		}

		local workspace = sbar.add("item", "workspace." .. workspace_index, {
			background = bg,
			click_script = "aerospace workspace " .. workspace_index,
			drawing = false, -- Hide all items at first
			padding_left = 2,
			padding_right = 2,
			icon = {
				color = style.icon.color,
				highlight_color = style.icon.highlight_color,
				font = style.icon.font_icon,
				padding_left = style.icon.padding_left,
				padding_right = style.icon.padding_right,
				drawing = true,
				string = workspace_index
					.. (workspace_names[workspace_index] and ": " .. workspace_names[workspace_index] or ""),
			},
			label = {
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

	sbar.add("item", "i3", {
		position = "left",
		padding_left = 2,
		padding_right = 2,
		icon = {
			string = "Powered by ",
			font = "Hack Nerd Font:Bold:10.0",
			padding_left = 6,
			padding_right = 6,
			color = appearance.colors.active.deep_blue,
		},
		label = { drawing = false },
		background = {
			drawing = false,
		},
	})

	-- Initial setup
	updateWindows()
	updateWorkspaceMonitor()

	-- Subscribe to window creation/destruction events
	root:subscribe("aerospace_workspace_change", function()
		updateWindows()
	end)

	-- Subscribe to front app changes too
	root:subscribe("front_app_switched", function()
		updateWindows()
	end)

	root:subscribe("display_change", function()
		updateWorkspaceMonitor()
		updateWindows()
	end)

	root:subscribe("aerospace_fullscreen_change", updateWindows)

	root:subscribe("aerospace_mode_change", function(env)
		sbar.exec("aerospace list-modes --current", function(result)
			local is_service = result:match("service") ~= nil
			mode_item:set({ drawing = is_service })
		end)
	end)

	sbar.exec("aerospace list-workspaces --focused", function(focused_workspace)
		focused_workspace = focused_workspace:match("^%s*(.-)%s*$")
		workspaces[focused_workspace]:set({
			icon = { highlight = true },
			label = { highlight = true },
		})
	end)
end)
