package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

-- switch_theme 内部才 require("sketchybar")，mock 成 animate 立即执行回调
package.preload["sketchybar"] = function()
	return {
		animate = function(_, _, callback) callback() end,
		bar = function() end,
	}
end

local appearance = require("appearance")

-- ========== 阶段一：identity/status 语义层数值与原硬编码值逐一相等 ==========

local mocha = appearance.palette.mocha
local latte = appearance.palette.latte
local cm = appearance.build_colors(mocha)
local cl = appearance.build_colors(latte)

-- status 层（两主题各验一遍）
assert(cm.status.ok == mocha.green)
assert(cm.status.error == mocha.red)
assert(cm.status.warn == mocha.yellow)
assert(cm.status.caution == mocha.peach)
assert(cl.status.ok == latte.green)
assert(cl.status.error == latte.red)
assert(cl.status.warn == latte.yellow)
assert(cl.status.caution == latte.peach)

-- press
assert(cm.press == mocha.yellow)
assert(cl.press == latte.yellow)

-- identity 登记表（迁移前各 widget 的实际用色，抽查关键项）
assert(cm.identity.apple == mocha.green)
assert(cm.identity.music_icon == mocha.peach)
assert(cm.identity.music_text == mocha.yellow)
assert(cm.identity.sys_icon == mocha.mauve)
assert(cm.identity.sys_info == mocha.peach)
assert(cm.identity.calendar_month == mocha.mauve)
assert(cm.identity.input_default == mocha.sapphire)
assert(cm.identity.input_a == mocha.blue)
assert(cm.identity.input_zh == mocha.green)
assert(cm.identity.input_ch == mocha.mauve)
assert(cm.identity.input_en == mocha.mauve)
assert(cm.identity.network == mocha.sapphire)
assert(cm.identity.network_hotspot == mocha.mauve)
assert(cm.identity.clash_all == mocha.mauve)
assert(cm.identity.clash_sys == mocha.sapphire)
assert(cm.identity.spaces_mode == mocha.sapphire)
assert(cm.identity.spaces_ws == mocha.peach)
assert(cm.identity.spaces_service == mocha.sapphire)
assert(cm.identity.spaces_win_highlight == mocha.red)
-- latte 抽查（防止复制粘贴错行）
assert(cl.identity.apple == latte.green)
assert(cl.identity.music_icon == latte.peach)
assert(cl.identity.input_a == latte.blue)
assert(cl.identity.spaces_win_highlight == latte.red)

-- 当前生效表与 active 对应色板一致（加载即同步检测，active 随系统主题）
local active_built = appearance.build_colors(appearance.palette[appearance.active])
assert(appearance.colors.status.ok == active_built.status.ok)
assert(appearance.colors.identity.music_text == active_built.identity.music_text)
assert(appearance.colors.press == active_built.press)

-- ========== 两主题 key 集合完全一致（原地更新的前置约束）==========

local function key_set(t)
	local keys = {}
	for k in pairs(t) do
		keys[k] = true
	end
	return keys
end

local function assert_same_keys(a, b, what)
	local ka, kb = key_set(a), key_set(b)
	for k in pairs(ka) do
		assert(kb[k], what .. ": mocha 有而 latte 缺 key " .. tostring(k))
	end
	for k in pairs(kb) do
		assert(ka[k], what .. ": latte 有而 mocha 缺 key " .. tostring(k))
	end
end

assert_same_keys(cm, cl, "top")
assert_same_keys(cm.status, cl.status, "status")
assert_same_keys(cm.identity, cl.identity, "identity")

-- ========== 阶段二：原地更新 + 注册表 + 反弹 ==========

-- appearance.core 在 appearance.lua 加载时即注册
local registered = {}
for _, name in ipairs(appearance.registered_names()) do
	registered[name] = true
end
assert(registered["appearance.core"], "appearance.core 未注册")

-- 注册一个探针回调，验证 switch_theme 调用恰好一次且收到新色板
local probe_calls = 0
local probe_color
appearance.register_colors("test.probe", function(C)
	probe_calls = probe_calls + 1
	probe_color = C.status.ok
end)

-- 缓存表引用（模拟各 widget 顶部的 local colors = appearance.colors）
local cached = appearance.colors
local status_ref = cached.status
local identity_ref = cached.identity

-- 起点主题无关：当前系统是深色/浅色都可能（加载即检测）
local start_theme = appearance.active
local other_theme = start_theme == "mocha" and "latte" or "mocha"
local start_palette = appearance.palette[start_theme]
local other_palette = appearance.palette[other_theme]

assert(appearance.switch_theme(start_theme) == false, "同主题应为 no-op")
assert(appearance.switch_theme("dracula") == false, "未知主题应为 no-op")
assert(probe_calls == 0, "no-op 不应触发回调")

assert(appearance.switch_theme(other_theme) == true)
assert(probe_calls == 1, "switch_theme 应调每个回调恰好一次")
assert(probe_color == other_palette.green, "回调应收到新色板")

-- 原地更新：表对象与子表对象均为同一引用
assert(cached == appearance.colors, "M.colors 表对象被替换（会反弹）")
assert(cached.status == status_ref, "status 子表对象被替换")
assert(cached.identity == identity_ref, "identity 子表对象被替换")
-- 缓存引用读到新值（状态刷新路径不反弹的关键）
assert(cached.status.ok == other_palette.green)
assert(cached.identity.music_text == other_palette.yellow)
-- 旧主题值无残留
assert(cached.status.ok ~= start_palette.green)

-- 往返切换恢复起点主题
assert(appearance.switch_theme(start_theme) == true)
assert(probe_calls == 2)
assert(cached.status.ok == start_palette.green)
assert(cached.identity.spaces_win_highlight == start_palette.red)

-- ========== 阶段三：系统外观检测解析 ==========
assert(appearance.parse_apple_interface_style("Dark") == "mocha")
assert(appearance.parse_apple_interface_style("") == "latte") -- 键不存在（浅色）
assert(appearance.parse_apple_interface_style(nil) == "latte") -- pcall 失败
assert(appearance.parse_apple_interface_style("Light") == "latte") -- 异常输出不误判深色
-- 同步检测必须返回合法主题名（真实读一次系统状态）
local detected = appearance.detect_system_theme_sync()
assert(detected == "mocha" or detected == "latte")
assert(detected == appearance.active, "加载时 active 应与同步检测一致")

-- ========== owner 注册静态检查（防旧架构式名单漂移）==========
-- 已知 owner 必须在源文件中注册；新增主题相关模块必须同步加入本清单。
local owner_sources = {
	["appearance.core"] = "sketchybar/.config/sketchybar/appearance.lua",
	apple = "sketchybar/.config/sketchybar/items/apple.lua",
	spaces = "sketchybar/.config/sketchybar/items/spaces.lua",
	borders = "sketchybar/.config/sketchybar/helpers/borders.lua",
	calendar = "sketchybar/.config/sketchybar/items/calendar.lua",
	git = "sketchybar/.config/sketchybar/items/git.lua",
	services = "sketchybar/.config/sketchybar/items/services.lua",
	media = "sketchybar/.config/sketchybar/items/widgets/media.lua",
	network = "sketchybar/.config/sketchybar/items/widgets/network.lua",
	input_method = "sketchybar/.config/sketchybar/items/widgets/input_method.lua",
	clash_tun = "sketchybar/.config/sketchybar/items/widgets/clash_tun.lua",
	battery = "sketchybar/.config/sketchybar/items/widgets/battery.lua",
	sys = "sketchybar/.config/sketchybar/items/widgets/sys.lua",
	["status_widget.social"] = "sketchybar/.config/sketchybar/items/widgets/wechat.lua", -- social bracket 背景
}
for name, path in pairs(owner_sources) do
	local f = assert(io.open(path, "r"), "无法打开 " .. path)
	local src = f:read("*a")
	f:close()
	assert(src:find('register_colors("' .. name .. '"', 1, true), path .. " 缺少 register_colors(\"" .. name .. "\")")
end
-- status_widget 工厂按实例名动态注册 status_widget.dingtalk/wechat
do
	local f = assert(io.open("sketchybar/.config/sketchybar/status_widget.lua", "r"))
	local src = f:read("*a")
	f:close()
	assert(src:find('register_colors("status_widget."', 1, true), "status_widget.lua 缺少按实例名的注册")
end

print("theme_test: ok")
