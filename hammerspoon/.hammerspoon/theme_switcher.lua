-- 原子切换共享 scheme，并以异步事件通知 SketchyBar。
-- 可选主题：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox

local M = {}

local display_names = {
	catppuccin = "Catppuccin",
	tokyonight = "Tokyo Night",
	rosepine = "Rosé Pine",
	everforest = "Everforest",
	kanagawa = "Kanagawa",
	gruvbox = "Gruvbox",
}

local valid_schemes = {
	catppuccin = true,
	tokyonight = true,
	rosepine = true,
	everforest = true,
	kanagawa = true,
	gruvbox = true,
}

function M.state_content(scheme)
	if not valid_schemes[scheme] then
		return nil
	end
	return table.concat({
		"# 可选主题：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox",
		"# 深浅模式跟随 macOS，不需要在这里设置。",
		"scheme=" .. scheme,
		"",
	}, "\n")
end

local function ensure_parent_directory(path)
	local parent = path:match("^(.*)/[^/]+$")
	if not parent or parent == "" then
		return true
	end
	if not (_G.hs and hs.fs) then
		local probe = io.open(parent .. "/.", "r")
		if probe then probe:close() end
		return probe ~= nil
	end
	local current = ""
	for part in parent:gmatch("[^/]+") do
		current = current .. "/" .. part
		if not hs.fs.attributes(current) then
			local ok, err = hs.fs.mkdir(current)
			if not ok then
				return false, tostring(err)
			end
		end
	end
	return true
end

function M.write_state_atomic(path, scheme)
	local content = M.state_content(scheme)
	if not content then
		return false, "invalid scheme"
	end
	if type(path) ~= "string" or path == "" then
		return false, "invalid state path"
	end
	local directory_ok, directory_error = ensure_parent_directory(path)
	if not directory_ok then
		return false, directory_error
	end

	local temporary = string.format("%s.tmp.%d.%d", path, os.time(), math.random(100000, 999999))
	local file, open_error = io.open(temporary, "w")
	if not file then
		return false, tostring(open_error)
	end
	local wrote, write_error = file:write(content)
	if not wrote then
		file:close()
		os.remove(temporary)
		return false, tostring(write_error)
	end
	local closed, close_error = file:close()
	if not closed then
		os.remove(temporary)
		return false, tostring(close_error)
	end
	local renamed, rename_error = os.rename(temporary, path)
	if not renamed then
		os.remove(temporary)
		return false, tostring(rename_error)
	end
	return true
end

function M.create(deps)
	local theme = assert(deps.theme)
	local write_state = deps.write_state or M.write_state_atomic
	local state_path = deps.state_path
	local command = assert(deps.command)
	local notification = assert(deps.notification)

	local controller = {}

	function controller.choices()
		local current = theme.current_scheme()
		local choices = {}
		for _, name in ipairs(theme.scheme_names) do
			local display = display_names[name] or name
			choices[#choices + 1] = {
				text = (name == current and "✓ " or "") .. display,
				scheme = name,
			}
		end
		return choices
	end

	function controller.switch_to(scheme)
		if not theme.is_valid_scheme(scheme) or scheme == theme.current_scheme() then
			return false
		end

		local ok, err = write_state(state_path, scheme)
		if not ok then
			print("[Theme] 写入状态失败: " .. tostring(err))
			notification.show("Theme · 保存失败", "error", 1.5)
			return false
		end

		theme.set_scheme(scheme)
		local started, start_error = command.sketchybar({
			"--trigger",
			"theme_scheme_change",
			"SCHEME=" .. scheme,
		}, function(exit_code, _, stderr)
			if exit_code ~= 0 then
				print("[Theme] SketchyBar 更新失败: " .. tostring(stderr or exit_code))
			end
		end)
		if not started then
			print("[Theme] 无法通知 SketchyBar: " .. tostring(start_error))
		end

		notification.show("Theme · " .. (display_names[scheme] or scheme), "neutral", 1.0)
		return true
	end

	return controller
end

function M.install()
	local theme = require("theme")
	local controller = M.create({
		theme = theme,
		write_state = M.write_state_atomic,
		state_path = theme.state_path(),
		command = require("command"),
		notification = require("notification_hud"),
	})
	local chooser = hs.chooser.new(function(choice)
		if choice and choice.scheme then
			controller.switch_to(choice.scheme)
		end
	end)
	hs.hotkey.bind({ "cmd", "ctrl", "alt", "shift" }, "t", function()
		chooser:choices(controller.choices())
		chooser:show()
	end)
	return controller
end

return M
