-- ========== 当前输入法显示 ==========
-- 通过 macism 命令行工具获取当前输入法 ID，映射为友好的短名称
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

-- 输入法 ID → 显示名 + 颜色 的映射表
local im_map = {
	["com.apple.keylayout.ABC"] = { label = "ABC", color = colors.blue },
	["com.tencent.inputmethod.wetype.pinyin"] = { label = "拼音", color = colors.green },
}

local input_method = sbar.add("item", "widgets.input_method", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	icon = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = settings.padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.tokyo_night.bg3_opaque,
	},
	label = {
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = fonts.font_fira.size,
		},
		padding_left = 0,
		padding_right = settings.padding.icon_label_item.label.padding_right,
		color = colors.tokyo_night.bg3_opaque,
	},
	background = {
		color = colors.tokyo_night.bar_bg,
		corner_radius = 10,
		border_color = colors.tokyo_night.input_border,
		border_width = 2,
	},
})

-- 根据输入法 ID 更新图标和文字
local function update_display(im_id)
	-- 如果 ID 不在映射表中，取最后一段作为名称（如 "com.apple.keylayout.ABC" → "ABC"）
	local im = im_map[im_id] or { label = im_id:match("[^.]+$") or "?", color = colors.tokyo_night.bg3_opaque }
	input_method:set({
		icon = { string = "⌨", color = im.color },
		label = { string = im.label, color = im.color },
	})
end

-- 调用 macism 获取当前输入法 ID
local function check_status()
	sbar.exec("macism", function(im_id)
		update_display(im_id:match("^%s*(.-)%s*$"))  -- 去除首尾空白
	end)
end

input_method:subscribe("input_method_change", check_status)  -- 输入法切换时刷新
input_method:subscribe("system_woke", check_status)          -- 系统唤醒时刷新
check_status()                                                -- 启动时主动查一次

-- 点击切换输入法（快捷键 ctrl+opt+cmd+Q）
input_method:subscribe("mouse.clicked", function()
	sbar.exec([[osascript -e 'tell application "System Events" to keystroke "q" using {command down, control down, option down}']])
end)
