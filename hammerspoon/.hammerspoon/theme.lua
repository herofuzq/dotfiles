-- Hammerspoon 主题服务。
-- 可选主题：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox
-- scheme 从共享状态文件读取；dark/light 始终独立跟随 macOS。

local M = {}

M.default_scheme = "gruvbox"
M.scheme_names = {
	"catppuccin",
	"tokyonight",
	"rosepine",
	"everforest",
	"kanagawa",
	"gruvbox",
}

M.schemes = {
	catppuccin = { dark = "mocha", light = "latte" },
	tokyonight = { dark = "tokyonight_storm", light = "tokyonight_day" },
	rosepine = { dark = "rosepine", light = "rosepine_dawn" },
	everforest = { dark = "everforest_dark", light = "everforest_light" },
	kanagawa = { dark = "kanagawa_wave", light = "kanagawa_lotus" },
	gruvbox = { dark = "gruvbox_dark", light = "gruvbox_light" },
}

-- HUD 只使用这 6 个槽。数值与 SketchyBar appearance.lua 保持一致，
-- hammerspoon/tests/theme_test.lua 会逐项对照，防止两边漂色。
M.raw_palettes = {
	mocha = {
		base = 0xff1e1e2e, surface0 = 0xff313244, subtext1 = 0xffbac2de,
		green = 0xffa6e3a1, yellow = 0xfff9e2af, red = 0xfff38ba8,
	},
	latte = {
		base = 0xffeff1f5, surface0 = 0xffccd0da, subtext1 = 0xff5c5f77,
		green = 0xff40a02b, yellow = 0xffdf8e1d, red = 0xffd20f39,
	},
	tokyonight_storm = {
		base = 0xff24283b, surface0 = 0xff292e42, subtext1 = 0xffa9b1d6,
		green = 0xff9ece6a, yellow = 0xffe0af68, red = 0xfff7768e,
	},
	tokyonight_day = {
		base = 0xffe1e2e7, surface0 = 0xffc4c8da, subtext1 = 0xff6172b0,
		green = 0xff587539, yellow = 0xff8c6c3e, red = 0xfff52a65,
	},
	rosepine = {
		base = 0xff191724, surface0 = 0xff26233a, subtext1 = 0xff908caa,
		green = 0xff95b1ac, yellow = 0xfff6c177, red = 0xffeb6f92,
	},
	rosepine_dawn = {
		base = 0xfffaf4ed, surface0 = 0xfff2e9e1, subtext1 = 0xff797593,
		green = 0xff6d8f89, yellow = 0xffea9d34, red = 0xffb4637a,
	},
	everforest_dark = {
		base = 0xff2d353b, surface0 = 0xff343f44, subtext1 = 0xff9da9a0,
		green = 0xffa7c080, yellow = 0xffdbbc7f, red = 0xffe67e80,
	},
	everforest_light = {
		base = 0xfffdf6e3, surface0 = 0xffefebd4, subtext1 = 0xff829181,
		green = 0xff8da101, yellow = 0xffdfa000, red = 0xfff85552,
	},
	kanagawa_wave = {
		base = 0xff1f1f28, surface0 = 0xff2a2a37, subtext1 = 0xffc8c093,
		green = 0xff98bb6c, yellow = 0xffe6c384, red = 0xffe46876,
	},
	kanagawa_lotus = {
		base = 0xfff2ecbc, surface0 = 0xffe7dba0, subtext1 = 0xff716e61,
		green = 0xff6f894e, yellow = 0xff77713f, red = 0xffc84053,
	},
	gruvbox_dark = {
		base = 0xff282828, surface0 = 0xff3c3836, subtext1 = 0xffd5c4a1,
		green = 0xffb8bb26, yellow = 0xfffabd2f, red = 0xfffb4934,
	},
	gruvbox_light = {
		base = 0xfffbf1c7, surface0 = 0xffebdbb2, subtext1 = 0xff504945,
		green = 0xff79740e, yellow = 0xffb57614, red = 0xff9d0006,
	},
}

local function color(value, alpha)
	return {
		red = ((value >> 16) & 0xff) / 255,
		green = ((value >> 8) & 0xff) / 255,
		blue = (value & 0xff) / 255,
		alpha = alpha,
	}
end

function M.is_valid_scheme(name)
	return M.schemes[name] ~= nil
end

function M.parse_scheme_state(content)
	if type(content) ~= "string" then
		return nil
	end
	for line in content:gmatch("[^\r\n]+") do
		local name = line:match("^%s*scheme%s*=%s*([%w_-]+)%s*$")
		if name then
			return M.is_valid_scheme(name) and name or nil
		end
	end
	return nil
end

function M.state_path()
	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/dotfiles/theme_scheme") or nil
end

function M.read_scheme(path)
	path = path or M.state_path()
	if not path then
		return nil, "HOME unavailable"
	end
	local file, open_error = io.open(path, "r")
	if not file then
		local message = tostring(open_error)
		if message:find("No such file or directory", 1, true) then
			return nil, "missing"
		end
		return nil, "unreadable: " .. message
	end
	local content = file:read("*a")
	file:close()
	local scheme = M.parse_scheme_state(content)
	if not scheme then
		return nil, "invalid"
	end
	return scheme
end

function M.parse_interface_style(style)
	return style == "Dark" and "dark" or "light"
end

local function detect_flavor()
	if _G.hs and hs.host and hs.host.interfaceStyle then
		return M.parse_interface_style(hs.host.interfaceStyle())
	end
	return "light"
end

function M.build_colors(scheme, flavor)
	local mapping = M.schemes[scheme] or M.schemes[M.default_scheme]
	local palette = M.raw_palettes[mapping[flavor]] or M.raw_palettes[mapping.light]
	return {
		background = color(palette.base, 0.42),
		text = color(palette.subtext1, 1.0),
		progress_green = color(palette.green, 0.9),
		progress_yellow = color(palette.yellow, 0.9),
		progress_red = color(palette.red, 0.9),
		empty = color(palette.surface0, 0.52),
		tones = {
			neutral = color(palette.subtext1, 1.0),
			success = color(palette.green, 1.0),
			warning = color(palette.yellow, 1.0),
			error = color(palette.red, 1.0),
		},
	}
end

local stored_scheme, stored_error = M.read_scheme()
if stored_error == "invalid" then
	print("[Theme] 无效的主题状态，回退到 " .. M.default_scheme)
elseif stored_error and stored_error ~= "missing" then
	print("[Theme] 无法读取主题状态: " .. stored_error)
end

local current_scheme = stored_scheme or M.default_scheme
local current_flavor = detect_flavor()
local current_colors = M.build_colors(current_scheme, current_flavor)
local subscribers = {}
local appearance_watcher
local wake_watcher

local function notify_subscribers()
	for name, callback in pairs(subscribers) do
		local ok, err = pcall(callback, current_colors)
		if not ok then
			print("[Theme] 更新 " .. name .. " 失败: " .. tostring(err))
		end
	end
end

function M.colors()
	return current_colors
end

function M.current_scheme()
	return current_scheme
end

function M.current_flavor()
	return current_flavor
end

function M.subscribe(name, callback)
	subscribers[name] = callback
	callback(current_colors)
end

function M.set_scheme(scheme)
	if not M.is_valid_scheme(scheme) or scheme == current_scheme then
		return false
	end
	current_scheme = scheme
	current_colors = M.build_colors(current_scheme, current_flavor)
	notify_subscribers()
	return true
end

function M.set_flavor(flavor)
	if (flavor ~= "dark" and flavor ~= "light") or flavor == current_flavor then
		return false
	end
	current_flavor = flavor
	current_colors = M.build_colors(current_scheme, current_flavor)
	notify_subscribers()
	return true
end

function M.refresh_system_style()
	return M.set_flavor(detect_flavor())
end

function M.start()
	if appearance_watcher or not (_G.hs and hs.distributednotifications) then
		return appearance_watcher
	end
	appearance_watcher = hs.distributednotifications.new(
		function() M.refresh_system_style() end,
		"AppleInterfaceThemeChangedNotification"
	)
	appearance_watcher:start()
	if hs.caffeinate and hs.caffeinate.watcher then
		wake_watcher = hs.caffeinate.watcher.new(function(event)
			if event == hs.caffeinate.watcher.systemDidWake then
				M.refresh_system_style()
			end
		end)
		wake_watcher:start()
	end
	return appearance_watcher
end

return M
