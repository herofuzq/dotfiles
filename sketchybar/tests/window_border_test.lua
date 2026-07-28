package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

local commands = {}
package.preload["sketchybar"] = function()
	return {
		exec = function(command)
			commands[#commands + 1] = command
		end,
		bar = function() end,
	}
end

local appearance = require("appearance")
local window_border = require("helpers.window_border")

assert(
	window_border.command(0xffa7c080, "/Users/Test User")
		== "BORDERS_ACTIVE_COLOR='0xffa7c080' '/Users/Test User/.config/borders/bordersrc'"
)
assert(
	window_border.command(0xff123abc, "/tmp/O'Brien")
		== "BORDERS_ACTIVE_COLOR='0xff123abc' '/tmp/O'\\''Brien/.config/borders/bordersrc'"
)

window_border.install()

local registered = {}
for _, name in ipairs(appearance.registered_names()) do
	registered[name] = true
end
assert(registered.window_border, "window_border 未注册主题 owner")
assert(#commands == 1, "install 应推送一次当前主题色")
assert(
	commands[1] == window_border.command(appearance.colors.identity.window_border, os.getenv("HOME")),
	"install 应推送当前主题的 window_border"
)

print("window_border_test: ok")
