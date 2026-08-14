local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
local config_module_path = repo_root .. "sketchybar/.config/sketchybar/?.lua;"
package.path = config_module_path .. repo_root .. "sketchybar/.config/sketchybar/?/init.lua;" .. package.path

-- switch_theme 内部才 require("sketchybar")，mock 成 animate 立即执行回调
local bar_calls = {}
package.preload["sketchybar"] = function()
	return {
		animate = function(_, _, callback) callback() end,
		bar = function(props) bar_calls[#bar_calls + 1] = props end,
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

-- 共享状态文件只保存 scheme；注释、空行和首尾空白不影响解析。
local expected_scheme_names = {
	"catppuccin",
	"tokyonight",
	"rosepine",
	"everforest",
	"kanagawa",
	"gruvbox",
}
assert(table.concat(appearance.scheme_names, ",") == table.concat(expected_scheme_names, ","))
assert(
	appearance.parse_scheme_state([[
# 可选主题：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox

scheme=everforest
]]) == "everforest"
)
assert(appearance.parse_scheme_state("  scheme = kanagawa  \n") == "kanagawa")
assert(appearance.parse_scheme_state("scheme=dracula\n") == nil)
assert(appearance.parse_scheme_state("# scheme=gruvbox\n") == nil)
assert(appearance.parse_scheme_state(nil) == nil)
local missing_scheme, missing_error = appearance.read_scheme_state("/tmp/dotfiles-theme-state-does-not-exist")
assert(missing_scheme == nil and missing_error == "missing")
local unreadable_scheme, unreadable_error = appearance.read_scheme_state("/dev/null/theme_scheme")
assert(unreadable_scheme == nil and unreadable_error:find("unreadable:", 1, true) == 1)

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
assert(#bar_calls > 0, "theme switch must touch the bar")
assert(bar_calls[#bar_calls].border_color ~= nil, "theme switch must recolor the bar border")

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

-- scheme 热切换与 flavor 热切换共享同一注册表和原地更新约束。
local start_scheme = appearance.scheme
local other_scheme = start_scheme == "everforest" and "gruvbox" or "everforest"
local calls_before_scheme_switch = probe_calls
local scheme_colors = appearance.build_colors(
	appearance.palette[appearance.schemes[other_scheme][appearance.active]],
	appearance.schemes[other_scheme].window_border
)

assert(appearance.switch_scheme(start_scheme) == false, "同色系应为 no-op")
assert(appearance.switch_scheme("dracula") == false, "未知色系应为 no-op")
assert(probe_calls == calls_before_scheme_switch, "scheme no-op 不应触发回调")

assert(appearance.switch_scheme(other_scheme) == true)
assert(appearance.scheme == other_scheme)
assert(probe_calls == calls_before_scheme_switch + 1)
assert(cached == appearance.colors and cached.status == status_ref and cached.identity == identity_ref)
assert(cached.status.ok == scheme_colors.status.ok)
assert(cached.identity.window_border == scheme_colors.identity.window_border)

assert(appearance.switch_scheme(start_scheme) == true)
assert(appearance.scheme == start_scheme)
assert(probe_calls == calls_before_scheme_switch + 2)

-- ========== 阶段三：系统外观探测 ==========
-- 探测结果只有在命令完整成功、输出为已知标签时才可信。
assert(appearance.parse_system_theme_probe_result("dark\n", 0) == "dark")
assert(appearance.parse_system_theme_probe_result(" light \n", 0) == "light")
assert(appearance.parse_system_theme_probe_result(nil, nil) == nil)
assert(appearance.parse_system_theme_probe_result("", nil) == nil)
assert(appearance.parse_system_theme_probe_result("", 0) == nil)
assert(appearance.parse_system_theme_probe_result("dark", 1) == nil)
assert(appearance.parse_system_theme_probe_result("light", 143) == nil)
assert(appearance.parse_system_theme_probe_result("Light", 0) == nil)

local original_theme = appearance.active
if appearance.active ~= "dark" then
	assert(appearance.switch_theme("dark") == true)
end
local calls_before_invalid_probe = probe_calls
assert(appearance.apply_system_theme_probe_result("", 143) == nil)
assert(appearance.active == "dark", "无效探测必须保持当前主题")
assert(probe_calls == calls_before_invalid_probe, "无效探测不能触发颜色重涂")
assert(appearance.apply_system_theme_probe_result("light\n", 0) == true)
assert(appearance.active == "light", "有效探测必须应用新主题")
if original_theme == "dark" then
	assert(appearance.switch_theme("dark") == true)
end

-- 完整 NSGlobalDomain 成功后，key 存在且为 Dark 才是深色；
-- 有效 plist 缺 key 才是正常浅色。空/坏 plist、错类型、未知值和 producer
-- 非零（即使带部分 stdout）都必须保持 unknown，不能误切浅色。
local plist_prefix = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>]]
local plist_suffix = [[</dict></plist>]]
local function shell_single_quote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end
local function run_probe_fixture(plist, producer_exit, style_extractor)
	local producer = "/usr/bin/printf %s " .. shell_single_quote(plist or "")
	if producer_exit and producer_exit ~= 0 then
		producer = producer .. "; exit " .. tostring(producer_exit)
	end
	local command = appearance.build_system_theme_probe_command(producer, style_extractor)
	local pipe = assert(io.popen(command))
	local output = pipe:read("*a")
	local _, _, exit_code = pipe:close()
	return appearance.parse_system_theme_probe_result(output, exit_code), exit_code
end

local dark_plist = plist_prefix .. "<key>AppleInterfaceStyle</key><string>Dark</string>" .. plist_suffix
local light_plist = plist_prefix .. "<key>Unrelated</key><true/>" .. plist_suffix
local bool_plist = plist_prefix .. "<key>AppleInterfaceStyle</key><true/>" .. plist_suffix
local unknown_plist = plist_prefix .. "<key>AppleInterfaceStyle</key><string>Light</string>" .. plist_suffix
local newline_plist = plist_prefix .. "<key>AppleInterfaceStyle</key><string>Dark&#10;</string>" .. plist_suffix
local array_plist = [[<?xml version="1.0"?><plist version="1.0"><array><string>Dark</string></array></plist>]]
local string_plist = [[<?xml version="1.0"?><plist version="1.0"><string>Dark</string></plist>]]

assert(run_probe_fixture(dark_plist, 0) == "dark")
assert(run_probe_fixture(light_plist, 0) == "light")
local _, empty_exit = run_probe_fixture("", 0)
assert(empty_exit ~= 0, "空 global domain 必须是 unknown")
local _, truncated_exit = run_probe_fixture(plist_prefix, 0)
assert(truncated_exit ~= 0, "损坏 plist 必须是 unknown")
local _, bool_exit = run_probe_fixture(bool_plist, 0)
assert(bool_exit ~= 0, "AppleInterfaceStyle 错类型必须是 unknown")
local _, unknown_exit = run_probe_fixture(unknown_plist, 0)
assert(unknown_exit ~= 0, "AppleInterfaceStyle 未知值必须是 unknown")
local _, newline_exit = run_probe_fixture(newline_plist, 0)
assert(newline_exit ~= 0, "带尾随换行的 Dark 不能被 shell 命令替换吞掉后误接受")
local _, array_exit = run_probe_fixture(array_plist, 0)
assert(array_exit ~= 0, "合法 array 根节点不能误判为 key 缺失")
local _, string_exit = run_probe_fixture(string_plist, 0)
assert(string_exit ~= 0, "合法 string 根节点不能误判为 key 缺失")
local _, producer_exit = run_probe_fixture(dark_plist, 7)
assert(producer_exit ~= 0, "producer 非零不能接受部分 stdout")
local _, extractor_exit = run_probe_fixture(dark_plist, 0, "/usr/bin/printf 'Dark\\n'; exit 7")
assert(extractor_exit ~= 0, "extractor 输出完整值后非零也必须是 unknown")

-- 同步入口从 stdout 中的唯一精确状态帧取结果，不依赖
-- popen:close() 的子进程状态（SbarLua 将 SIGCHLD 设为 SIG_IGN）。
assert(appearance.parse_system_theme_sync_result(
	"dark\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=0\n"
) == "dark")
assert(appearance.parse_system_theme_sync_result(
	"light\n\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=0\n"
) == "light")
assert(appearance.parse_system_theme_sync_result("dark\n") == nil, "missing status frame must be unknown")
assert(appearance.parse_system_theme_sync_result(
	"dark\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=nope\n"
) == nil, "malformed status frame must be unknown")
assert(appearance.parse_system_theme_sync_result(
	"dark\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=7\n"
) == nil, "nonzero embedded status must be unknown")
assert(appearance.parse_system_theme_sync_result(
	"dark\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=0\n"
		.. "__SKETCHYBAR_THEME_SYNC_STATUS_v1__=0\n"
) == nil, "duplicate status frame must be unknown")
assert(appearance.parse_system_theme_sync_result(
	"dark\n__SKETCHYBAR_THEME_SYNC_STATUS_v1__=0\ntrailing"
) == nil, "data after the status frame must be unknown")

-- 真实 shell wrapper 先产生 status 0/7 帧，再确定性模拟 ECHILD。
-- 这同时验证帧的真实形状和 close 无法给出退出状态时的解析边界，
-- 不依赖已部署的 SbarLua 或它的安装路径。
do
	local original_popen = io.popen
	local function capture_real_frame(command)
		local pipe = assert(original_popen(appearance.build_system_theme_sync_command(command)))
		local output = pipe:read("*a")
		pipe:close()
		return output
	end
	local success_frame = capture_real_frame("/usr/bin/printf 'dark\\n'")
	local failure_frame = capture_real_frame("/usr/bin/printf 'dark\\n'; exit 7")
	assert(appearance.parse_system_theme_sync_result(success_frame) == "dark",
		"real status-0 wrapper must emit a valid dark frame")
	assert(appearance.parse_system_theme_sync_result(failure_frame) == nil,
		"real nonzero wrapper status must remain unknown")

	local function detect_with_unavailable_close(frame, close_throws)
		local detected
		local ok, err = xpcall(function()
			io.popen = function()
				return {
					read = function(_, mode)
						assert(mode == "*a")
						return frame
					end,
					close = function()
						if close_throws then
							error("close unavailable")
						end
						return nil, "No child processes", 10
					end,
				}
			end
			detected = appearance.detect_system_theme_sync("/usr/bin/false")
		end, debug.traceback)
		io.popen = original_popen
		assert(ok, err)
		return detected
	end

	assert(detect_with_unavailable_close(success_frame, false) == "dark",
		"embedded status must survive unavailable popen close status")
	assert(detect_with_unavailable_close(failure_frame, false) == nil,
		"embedded nonzero status must remain authoritative when close has no status")
	assert(detect_with_unavailable_close(success_frame, true) == "dark",
		"embedded status must survive a throwing close cleanup")
end

assert(appearance.detect_system_theme_sync("/usr/bin/printf 'dark\\n'") == "dark")
assert(appearance.detect_system_theme_sync("/usr/bin/printf 'light\\n'") == "light")
assert(appearance.detect_system_theme_sync("/usr/bin/printf 'dark\\n'; exit 7") == nil)
assert(appearance.detect_system_theme_sync("/usr/bin/false") == nil)
assert(appearance.detect_initial_system_theme("/usr/bin/false") == "dark")
local detected = appearance.detect_initial_system_theme()
assert(detected == "dark" or detected == "light")
assert(detected == appearance.active, "加载时 active 应与同步检测或 fallback 一致")

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

-- 运行时 scheme 切换必须走自定义事件，不 reload SketchyBar。
do
	local f = assert(io.open("sketchybar/.config/sketchybar/init.lua", "r"))
	local src = f:read("*a")
	f:close()
	assert(src:find('sbar.add("event", "theme_scheme_change")', 1, true), "init.lua 缺少 theme_scheme_change 事件")
	assert(src:find("function(output, exit_code)", 1, true), "主题探测回调必须接收 exit_code")
	assert(
		src:find("apply_system_theme_probe_result(output, exit_code)", 1, true),
		"主题探测回调必须按 output + exit_code 解析"
	)
	assert(
		src:find('theme_trigger:subscribe("theme_scheme_change"', 1, true),
		"theme_trigger 未订阅 theme_scheme_change"
	)
	assert(src:find("read_scheme_state()", 1, true), "theme_scheme_change 应读取最终状态文件")
	assert(not src:find("switch_scheme(env.SCHEME)", 1, true), "theme_scheme_change 不应信任可能乱序的事件参数")
end

print("theme_test: ok")
