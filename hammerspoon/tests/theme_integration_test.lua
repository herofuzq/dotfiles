local function read(path)
	local file = assert(io.open(path, "r"))
	local content = file:read("*a")
	file:close()
	return content
end

local input = read("hammerspoon/.hammerspoon/input.lua")
assert(input:find('local theme = require("theme")', 1, true))
assert(input:find('theme.subscribe("input_hud"', 1, true))
assert(not input:find("MOCHA_", 1, true), "input.lua 不应保留固定 Mocha 配色")
assert(input:find('_inputHud:elementAttribute(1, "fillColor"', 1, true), "现有 Input HUD 背景未原地重染")
assert(input:find('_inputHud:elementAttribute(2, "textColor"', 1, true), "现有 Input HUD 文字未原地重染")

local notification = read("hammerspoon/.hammerspoon/notification_hud.lua")
assert(notification:find('local theme = require("theme")', 1, true))
assert(notification:find('theme.subscribe("notification_hud"', 1, true))
assert(not notification:find("MOCHA_", 1, true), "notification_hud.lua 不应保留固定 Mocha 配色")
assert(notification:find('hud:elementAttribute(1, "fillColor"', 1, true), "现有通知背景未原地重染")
assert(notification:find('hud:elementAttribute(2, "textColor"', 1, true), "现有通知文字未原地重染")

local init = read("hammerspoon/.hammerspoon/init.lua")
local theme_start = assert(init:find('require("theme").start()', 1, true))
local input_load = assert(init:find('require("input")', 1, true))
local switcher_install = assert(init:find('require("theme_switcher").install()', 1, true))
assert(theme_start < input_load, "theme 必须在 HUD consumer 之前启动")
assert(switcher_install > input_load, "选择器应在 HUD consumer 注册后安装")

local switcher = read("hammerspoon/.hammerspoon/theme_switcher.lua")
assert(
	switcher:find('chooser:placeholderText("Theme · " .. flavor_label .. " · follows macOS")', 1, true),
	"主题选择器标题应显示当前 macOS flavor"
)

print("theme_integration_test: ok")
