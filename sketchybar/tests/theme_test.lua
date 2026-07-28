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

-- press / count
assert(cm.press == mocha.yellow)
assert(cl.press == latte.yellow)
assert(cm.count == mocha.peach) -- 计数统一色
assert(cl.count == latte.peach)

-- identity 登记表（C 两级制：内容型保留强调色，状态型常规态回归中性）
assert(cm.identity.apple == mocha.mauve)
assert(cm.identity.front_app == mocha.mauve)
assert(cm.identity.music_icon == mocha.peach) -- bar 上唯一保留的固定强调色
assert(cm.identity.music_text == mocha.text)
assert(cm.identity.sys_icon == mocha.text)
assert(cm.identity.sys_info == mocha.subtext1)
assert(cm.identity.calendar_month == mocha.text)
assert(cm.identity.input_default == mocha.text)
assert(cm.identity.input_a == mocha.text)
assert(cm.identity.input_zh == mocha.green)
assert(cm.identity.input_ch == mocha.text)
assert(cm.identity.input_en == mocha.text)
assert(cm.identity.network == mocha.sapphire) -- 常态连接也有信号色
assert(cm.identity.network_hotspot == mocha.mauve) -- 状态信号色保留
assert(cm.identity.clash_all == mocha.mauve)
assert(cm.identity.clash_sys == mocha.sapphire)
assert(cm.identity.spaces_mode == mocha.text) -- 与 apple 图标同色
assert(cm.identity.spaces_ws == mocha.text)
assert(cm.identity.spaces_service == mocha.text) -- 与 apple 图标同色
assert(cm.identity.spaces_win_highlight == mocha.red)
-- latte 抽查（防止复制粘贴错行）
assert(cl.identity.apple == latte.mauve)
assert(cl.identity.front_app == latte.mauve)
assert(cl.identity.music_icon == latte.peach)
assert(cl.identity.input_a == latte.text)
assert(cl.identity.network == latte.sapphire)
assert(cl.identity.spaces_win_highlight == latte.red)

-- tokyonight 色板：关键槽位抽查（官方值）
local storm = appearance.palette.tokyonight_storm
local day = appearance.palette.tokyonight_day
assert(storm.text == 0xffc0caf5 and storm.base == 0xff24283b and storm.mauve == 0xffbb9af7)
assert(day.text == 0xff3760bf and day.base == 0xffe1e2e7 and day.red == 0xfff52a65)
local cs = appearance.build_colors(storm)
local cd = appearance.build_colors(day)
assert(cs.identity.music_icon == storm.peach)
assert(cd.status.ok == day.green)
-- scheme 映射
assert(appearance.schemes.catppuccin.dark == "mocha")
assert(appearance.schemes.catppuccin.light == "latte")
assert(appearance.schemes.tokyonight.dark == "tokyonight_storm")
assert(appearance.schemes.tokyonight.light == "tokyonight_day")

-- rosepine / everforest / kanagawa / gruvbox 色板：关键槽位抽查（官方值）
local rp = appearance.palette.rosepine
local rpd = appearance.palette.rosepine_dawn
assert(rp.base == 0xff191724 and rp.text == 0xffe0def4 and rp.mauve == 0xffc4a7e7)
assert(rp.crust == 0xff16141f) -- _nc
assert(rpd.base == 0xfffaf4ed and rpd.text == 0xff464261 and rpd.red == 0xffb4637a)
local efd = appearance.palette.everforest_dark
local efl = appearance.palette.everforest_light
assert(efd.base == 0xff2d353b and efd.text == 0xffd3c6aa and efd.green == 0xffa7c080)
assert(efl.base == 0xfffdf6e3 and efl.text == 0xff5c6a72 and efl.blue == 0xff3a94c5)
local kaw = appearance.palette.kanagawa_wave
local kal = appearance.palette.kanagawa_lotus
assert(kaw.base == 0xff1f1f28 and kaw.text == 0xffdcd7ba and kaw.blue == 0xff7e9cd8)
assert(kal.base == 0xfff2ecbc and kal.text == 0xff545464 and kal.red == 0xffc84053)
local gbd = appearance.palette.gruvbox_dark
local gbl = appearance.palette.gruvbox_light
assert(gbd.base == 0xff282828 and gbd.text == 0xffebdbb2 and gbd.red == 0xfffb4934)
assert(gbl.base == 0xfffbf1c7 and gbl.text == 0xff3c3836 and gbl.green == 0xff79740e)
-- 新 scheme 映射
assert(appearance.schemes.rosepine.dark == "rosepine" and appearance.schemes.rosepine.light == "rosepine_dawn")
assert(appearance.schemes.everforest.dark == "everforest_dark" and appearance.schemes.everforest.light == "everforest_light")
assert(appearance.schemes.kanagawa.dark == "kanagawa_wave" and appearance.schemes.kanagawa.light == "kanagawa_lotus")
assert(appearance.schemes.gruvbox.dark == "gruvbox_dark" and appearance.schemes.gruvbox.light == "gruvbox_light")

-- 每套 scheme 只登记一个代表色角色，dark/light 自动取各自 palette 的对应值。
local border_roles = {
	catppuccin = "mauve",
	tokyonight = "blue",
	rosepine = "rosewater",
	everforest = "green",
	kanagawa = "blue",
	gruvbox = "peach",
}
for scheme_name, role in pairs(border_roles) do
	local scheme = appearance.schemes[scheme_name]
	assert(scheme.window_border == role, scheme_name .. " window_border 角色错误")
	for _, flavor in ipairs({ "dark", "light" }) do
		local p = appearance.palette[scheme[flavor]]
		local colors = appearance.build_colors(p, scheme.window_border)
		assert(
			colors.identity.window_border == p[role],
			scheme_name .. "." .. flavor .. " window_border 颜色错误"
		)
		assert(colors.identity.apple == colors.identity.window_border, scheme_name .. "." .. flavor .. " apple 颜色错误")
		assert(
			colors.identity.front_app == colors.identity.window_border,
			scheme_name .. "." .. flavor .. " front_app 颜色错误"
		)
		assert(colors.identity.spaces_ws == p.text, scheme_name .. "." .. flavor .. " workspace 编号不应跟随强调色")
	end
end

-- 每个色板必须填满 26 槽（结构一致，防漏槽/笔误多槽）
for name, p in pairs(appearance.palette) do
	local n = 0
	for _ in pairs(p) do
		n = n + 1
	end
	assert(n == 26, name .. " 色板槽位数 " .. n .. " ≠ 26")
end

-- 当前生效表与 active flavor 对应色板一致（加载即同步检测）
local active_built = appearance.build_colors(appearance.flavor_palette(appearance.active))
assert(appearance.colors.status.ok == active_built.status.ok)
assert(appearance.colors.identity.music_text == active_built.identity.music_text)
assert(appearance.colors.press == active_built.press)
local active_scheme = appearance.schemes[appearance.scheme]
local active_palette = appearance.palette[active_scheme[appearance.active]]
assert(appearance.colors.identity.window_border == active_palette[active_scheme.window_border])

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

-- 全部色板：build_colors 输出不得有 nil 叶值（色板缺槽位会导致颜色 nil）
local function assert_no_nil(t, what)
	for k, v in pairs(t) do
		if type(v) == "table" then
			assert_no_nil(v, what .. "." .. tostring(k))
		else
			assert(v ~= nil, what .. "." .. tostring(k) .. " 为 nil（色板缺槽位）")
		end
	end
end
for name, p in pairs(appearance.palette) do
	assert_no_nil(appearance.build_colors(p), "palette." .. name)
end

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

-- 起点 flavor 无关：当前系统是深色/浅色都可能（加载即检测）
local start_theme = appearance.active
local other_theme = start_theme == "dark" and "light" or "dark"
local start_palette = appearance.flavor_palette(start_theme)
local other_palette = appearance.flavor_palette(other_theme)

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
assert(cached.identity.music_text == other_palette.text)
-- 旧主题值无残留
assert(cached.status.ok ~= start_palette.green)

-- 往返切换恢复起点主题
assert(appearance.switch_theme(start_theme) == true)
assert(probe_calls == 2)
assert(cached.status.ok == start_palette.green)
assert(cached.identity.spaces_win_highlight == start_palette.red)

-- ========== 阶段三：系统外观检测解析 ==========
assert(appearance.parse_apple_interface_style("Dark") == "dark")
assert(appearance.parse_apple_interface_style("") == "light") -- 键不存在（浅色）
assert(appearance.parse_apple_interface_style(nil) == "light") -- pcall 失败
assert(appearance.parse_apple_interface_style("Light") == "light") -- 异常输出不误判深色
-- 同步检测必须返回合法 flavor（真实读一次系统状态）
local detected = appearance.detect_system_theme_sync()
assert(detected == "dark" or detected == "light")
assert(detected == appearance.active, "加载时 active 应与同步检测一致")

-- ========== owner 注册静态检查（防旧架构式名单漂移）==========
-- 已知 owner 必须在源文件中注册；新增主题相关模块必须同步加入本清单。
local owner_sources = {
	["appearance.core"] = "sketchybar/.config/sketchybar/appearance.lua",
	window_border = "sketchybar/.config/sketchybar/helpers/window_border.lua",
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
