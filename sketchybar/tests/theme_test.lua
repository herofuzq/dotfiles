package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

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

-- 当前生效表（active = mocha）与 build_colors(mocha) 一致
assert(appearance.colors.status.ok == cm.status.ok)
assert(appearance.colors.identity.music_text == cm.identity.music_text)
assert(appearance.colors.press == cm.press)

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

print("theme_test: ok")
