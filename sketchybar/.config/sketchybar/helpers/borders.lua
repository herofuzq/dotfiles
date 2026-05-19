-- ========== 中央调色器 ==========
-- 根据当前可见工作区数量，从预置色库中选取对应配色方案，
-- 统一分配所有 item 的边框颜色（含 apple 和 calendar）。
local sbar = require("sketchybar")

-- 所有 item 的 item name（按 bar 上从左到右顺序，apple 最左，calendar 最右）
local apple_item = "apple"

local widget_order = {
	"front_app",
	"widgets.input_method",
	"widgets.battery",
	"widgets.wechat",
	"widgets.dingtalk",
	"widgets.clash_tun",
	"widgets.sys",
}

local calendar_item = "calendar"

-- 5 套预置色值 [spaces数量] = { apple, spaces..., widgets..., calendar }
-- 11 个关键色均匀分布在 N 个 item 上，apple/calendar 固定为两端
local color_sets = {
	[5] = {
		0xfff38ba8, -- apple
		0xffec9bab, 0xfff3aa98, 0xfff9c193, 0xfff2e2ad, 0xffb2e2a3, -- spaces
		0xff9ae2c1, 0xff8fdfdd, 0xff85d8eb, 0xff75c8eb, 0xff82b9f5, 0xff9cb8fb, 0xffb9b8fc, -- widgets
		0xffcba6f7, -- calendar
	},
	[6] = {
		0xfff38ba8, -- apple (固定)
		0xffed9aaa, 0xfff1a89c, 0xfff9b98c, 0xfff9dba9, 0xffc9e2a7, 0xffa0e2af, -- spaces
		0xff94e2d5, 0xff8cdde4, 0xff80d3eb, 0xff77c4ee, 0xff86b6f8, 0xffa1b9fc, 0xffbab7fc, -- widgets
		0xffcba6f7, -- calendar (固定)
	},
	[7] = {
		0xfff38ba8, -- apple
		0xffed99aa, 0xfff0a69f, 0xfffab387, 0xfff9d2a1, 0xffdde2aa, 0xffa6e3a1, 0xff9ae2c3, -- spaces
		0xff90e0dc, 0xff89dceb, 0xff7bceeb, 0xff7bc0f0, 0xff89b4fa, 0xffa5bafc, 0xffbbb6fb, -- widgets
		0xffcba6f7, -- calendar
	},
	[8] = {
		0xfff38ba8, -- apple
		0xffee98aa, 0xffeea4a2, 0xfff8b08b, 0xfff9ca9b, 0xffeee2ad, 0xffbae2a4, 0xff9fe2b4, 0xff94e2d5, -- spaces
		0xff8ddee2, 0xff83d6eb, 0xff76c9eb, 0xff7ebdf3, 0xff8eb5fa, 0xffa9bbfd, 0xffbcb5fb, -- widgets
		0xffcba6f7, -- calendar
	},
	[9] = {
		0xfff38ba8, -- apple
		0xffee97aa, 0xffeda3a5, 0xfff6ae8f, 0xfff9c395, 0xfff9dfac, 0xffcde2a7, 0xffa3e2a7, 0xff99e2c5, 0xff90e0db, -- spaces
		0xff8adce8, 0xff7fd2eb, 0xff75c5ec, 0xff81baf5, 0xff93b6fa, 0xffacbcfd, 0xffbdb4fb, -- widgets
		0xffcba6f7, -- calendar
	},
}

function distribute(visible_workspace_names)
	local n = #visible_workspace_names
	local set = color_sets[n]
	if not set then
		return
	end

	-- apple（固定，索引 1）
	sbar.set(apple_item, { background = { border_color = set[1] }, icon = { color = set[1] } })

	-- 工作区（索引 2 ~ n+1）
	for i, name in ipairs(visible_workspace_names) do
		sbar.set(name, {
			background = { border_color = set[1 + i], border_width = 2 },
			icon = { color = set[1 + i] },
		})
	end

	-- 静态 widget（索引 n+2 ~ n+8）
	for i, name in ipairs(widget_order) do
		sbar.set(name, { background = { border_color = set[1 + n + i] } })
	end

	-- calendar（固定，索引 n+9）
	sbar.set(calendar_item, { background = { border_color = set[n + 9] } })
end

return { distribute = distribute }
