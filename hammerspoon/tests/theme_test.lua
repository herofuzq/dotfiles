local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;"
	.. repo_root .. "sketchybar/.config/sketchybar/?.lua;"
	.. package.path

package.preload["sketchybar"] = function()
	return {
		animate = function(_, _, callback) callback() end,
		bar = function() end,
	}
end

local theme = require("theme")
local appearance = require("appearance")

local expected_names = {
	"catppuccin",
	"tokyonight",
	"rosepine",
	"everforest",
	"kanagawa",
	"gruvbox",
}
assert(table.concat(theme.scheme_names, ",") == table.concat(expected_names, ","))
assert(theme.default_scheme == "gruvbox")
assert(theme.parse_scheme_state("# comment\nscheme=everforest\n") == "everforest")
assert(theme.parse_scheme_state(" scheme = rosepine ") == "rosepine")
assert(theme.parse_scheme_state("scheme=dracula") == nil)
assert(theme.parse_scheme_state(nil) == nil)
assert(theme.parse_interface_style("Dark") == "dark")
assert(theme.parse_interface_style(nil) == "light")
local valid_path = os.tmpname()
local valid_file = assert(io.open(valid_path, "w"))
assert(valid_file:write("scheme=everforest\n"))
valid_file:close()
local valid_scheme, valid_error = theme.read_scheme(valid_path)
os.remove(valid_path)
assert(valid_scheme == "everforest" and valid_error == nil, "合法状态文件不应附带错误")
local missing_scheme, missing_error = theme.read_scheme("/tmp/dotfiles-hs-theme-state-does-not-exist")
assert(missing_scheme == nil and missing_error == "missing")
local unreadable_scheme, unreadable_error = theme.read_scheme("/dev/null/theme_scheme")
assert(unreadable_scheme == nil and unreadable_error:find("unreadable:", 1, true) == 1)

-- Hammerspoon 只复制 HUD 所需的 6 个槽；数值必须与 SketchyBar 色板完全一致。
local slots = { "base", "surface0", "subtext1", "green", "yellow", "red" }
for scheme_name, mapping in pairs(theme.schemes) do
	for _, flavor in ipairs({ "dark", "light" }) do
		local theme_palette = theme.raw_palettes[mapping[flavor]]
		local sketchybar_palette = appearance.palette[appearance.schemes[scheme_name][flavor]]
		for _, slot in ipairs(slots) do
			assert(
				theme_palette[slot] == sketchybar_palette[slot],
				scheme_name .. "." .. flavor .. "." .. slot .. " 与 SketchyBar 不一致"
			)
		end
	end
end

local dark = theme.build_colors("everforest", "dark")
assert(dark.background.alpha == 0.42)
assert(dark.text.alpha == 1.0)
assert(dark.progress_green.alpha == 0.9)
assert(dark.empty.alpha == 0.52)
assert(dark.tones.success.alpha == 1.0)

local calls = 0
local latest
theme.subscribe("test", function(colors)
	calls = calls + 1
	latest = colors
end)
assert(calls == 1, "subscribe 应立即提供当前颜色")

local start_scheme = theme.current_scheme()
local other_scheme = start_scheme == "kanagawa" and "everforest" or "kanagawa"
assert(theme.set_scheme(start_scheme) == false)
assert(theme.set_scheme("dracula") == false)
assert(calls == 1)
assert(theme.set_scheme(other_scheme) == true)
assert(calls == 2 and theme.current_scheme() == other_scheme)
assert(latest == theme.colors())

local start_flavor = theme.current_flavor()
local other_flavor = start_flavor == "dark" and "light" or "dark"
assert(theme.set_flavor(start_flavor) == false)
assert(theme.set_flavor(other_flavor) == true)
assert(calls == 3 and theme.current_flavor() == other_flavor)

-- 分布式外观通知不保证必达；wake 事件必须做一次相同的无轮询复检。
local interface_style = other_flavor == "dark" and nil or "Dark"
local distributed_callback
local wake_callback
_G.hs = {
	host = {
		interfaceStyle = function() return interface_style end,
	},
	distributednotifications = {
		new = function(callback, name)
			assert(name == "AppleInterfaceThemeChangedNotification")
			distributed_callback = callback
			return { start = function(self) return self end }
		end,
	},
	caffeinate = {
		watcher = {
			systemDidWake = 1,
			new = function(callback)
				wake_callback = callback
				return { start = function(self) return self end }
			end,
		},
	},
}
theme.start()
assert(type(distributed_callback) == "function")
assert(type(wake_callback) == "function", "theme.start 应注册 wake 外观复检")
wake_callback(hs.caffeinate.watcher.systemDidWake)
assert(theme.current_flavor() == theme.parse_interface_style(interface_style))

print("hammerspoon_theme_test: ok")
