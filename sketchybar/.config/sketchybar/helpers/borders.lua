-- ========== 中央调色器 ==========
-- 根据当前可见工作区数量，从预置色库中选取对应配色方案，
-- 为所有中间 item（spaces + 7 个 widget）统一分配边框颜色。
-- apple（gradient1）和 calendar（gradient18）不受影响。
local sbar = require("sketchybar")

-- 7 个静态 widget 的 item name（按 bar 上从左到右顺序）
local widget_order = {
	"front_app",
	"widgets.input_method",
	"widgets.battery",
	"widgets.wechat",
	"widgets.dingtalk",
	"widgets.clash_tun",
	"widgets.sys",
}

-- 4 套预置色值 [spaces数量] = { 全部中间 item 颜色（按序） }
local color_sets = {
	[6] = {
		0xffd4afa2, 0xffc7bda0, 0xffb8c9a1, 0xffa1d0ab, 0xff94cfb2, 0xff8ec8b8, -- spaces
		0xff86bec1, 0xff7cb2c9, 0xff74a1c5, 0xff6f8ebc, 0xff6e7bad, 0xff666492, 0xff5b4c73, -- widgets
	},
	[7] = {
		0xffd4afa2, 0xffc8bba0, 0xffbbc7a0, 0xffa6cea8, 0xff95d1b0, 0xff90cbb5, 0xff8ac3bc, -- spaces
		0xff81b9c6, 0xff79abc7, 0xff729bc4, 0xff6f8ab9, 0xff6e78ab, 0xff656290, 0xff5b4c73, -- widgets
	},
	[8] = {
		0xffd4afa2, 0xffc9bba0, 0xffbfc79f, 0xffabcda7, 0xff97d3af, 0xff92cdb4, 0xff8ec8b9, 0xff86bec1, -- spaces
		0xff7eb5ca, 0xff77a6c6, 0xff7097c3, 0xff6f86b6, 0xff6e76a9, 0xff64618e, 0xff5b4c73, -- widgets
	},
	[9] = {
		0xffd4afa2, 0xffcabaa0, 0xffc0c59f, 0xffafcba5, 0xff9cd1ac, 0xff94cfb2, 0xff8fcab7, 0xff89c2bd, 0xff82bac5, -- spaces
		0xff7bafc8, 0xff74a1c5, 0xff6f92bf, 0xff6e83b3, 0xff6c73a5, 0xff635f8c, 0xff5b4c73, -- widgets
	},
}

function distribute(visible_workspace_names)
	local n = #visible_workspace_names
	local set = color_sets[n]
	if not set then
		return
	end

	-- 分配工作区颜色（前 n 个）— 同时设置边框和图标色
	for i, name in ipairs(visible_workspace_names) do
		sbar.set(name, {
			background = { border_color = set[i], border_width = 2 },
			icon = { color = set[i] },
		})
	end

	-- 分配静态 widget 颜色（后续 7 个）— 仅设置边框色
	for i, name in ipairs(widget_order) do
		sbar.set(name, { background = { border_color = set[n + i] } })
	end
end

return { distribute = distribute }
