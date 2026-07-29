package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

-- sync_pill_heights 内部才 require("sketchybar")，mock 成记录调用
local calls = {}
package.preload["sketchybar"] = function()
	return {
		animate = function(_, _, callback) callback() end,
		bar = function() end,
		default = function(props) calls[#calls + 1] = { kind = "default", props = props } end,
		set = function(name, props) calls[#calls + 1] = { kind = "set", name = name, props = props } end,
	}
end

local appearance = require("appearance")
local settings = require("settings")

-- ========== register + sync：bar 高度变化后所有登记项被重设 ==========
appearance.register_pill("widgets.battery")
appearance.register_pill("widgets.system")

local function assert_sync(expected_height)
	assert(#calls == 3, "sync 应产生 1 次 default + 2 次 set，实际 " .. #calls)
	local saw_default, seen = false, {}
	for _, c in ipairs(calls) do
		if c.kind == "default" then
			assert(c.props.background.height == expected_height, "default 高度应为 settings.height - 4")
			saw_default = true
		else
			seen[c.name] = c.props.background.height
		end
	end
	assert(saw_default, "应刷新 sbar.default 供之后创建的 item 使用")
	assert(seen["widgets.battery"] == expected_height, "widgets.battery 背景高度未同步")
	assert(seen["widgets.system"] == expected_height, "widgets.system 背景高度未同步")
end

settings.height = 40
appearance.sync_pill_heights()
assert_sync(36)

-- 再次变化：跟随最新 settings.height
calls = {}
settings.height = 30
appearance.sync_pill_heights()
assert_sync(26)

-- ========== 防漂移：用 pill_bg() 的源码文件必须登记 register_pill( ==========
-- 新增 pill item/bracket 时必须把文件加入本清单（与 theme_test owner_sources 同一约定）。
local pill_files = {
	"sketchybar/.config/sketchybar/items/widgets/battery.lua",
	"sketchybar/.config/sketchybar/items/widgets/sys.lua",
	"sketchybar/.config/sketchybar/items/widgets/input_method.lua",
	"sketchybar/.config/sketchybar/items/widgets/wechat.lua",
	"sketchybar/.config/sketchybar/items/widgets/network.lua",
}
for _, path in ipairs(pill_files) do
	local f = assert(io.open(path, "r"), "无法打开 " .. path)
	local src = f:read("*a")
	f:close()
	assert(src:find("pill_bg()", 1, true), path .. " 应使用 pill_bg()（清单已过期）")
	assert(src:find("register_pill(", 1, true), path .. " 用了 pill_bg() 但未 register_pill")
end

print("pill_height_test: ok")
