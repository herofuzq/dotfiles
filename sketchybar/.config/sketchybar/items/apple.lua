-- ========== Apple Logo 按钮（最左侧） ==========
-- icon 宽度 = Dock 可见宽度，随 Dock 内容/隐藏状态自适应
-- 如需调整边框粗细，改下面的 border_width 即可，icon padding 会自动重算
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")
local timing = require("helpers.timing")
local startup = require("helpers.startup")

local border_width = 0 -- 无背景无边框
local icon_width = 15
local dock_sync_generation = 0

local function compute_icon_pad(dock_w, dock_hidden)
	if dock_hidden == 1 then
		return 10, 10
	else
		local pad = math.floor((dock_w - icon_width - 2 * border_width - 4) / 2)
		return pad, pad
	end
end

local icon_pad_left, icon_pad_right = compute_icon_pad(settings.initial_dock_width())

local apple = sbar.add("item", "apple", {
	padding_left = 5,
	padding_right = 5,
	icon = {
		string = icons.apple,
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = 18.0,
		},
		padding_left = icon_pad_left,
		padding_right = icon_pad_right,
		color = colors.green,
		y_offset = 1,
	},
	label = { drawing = false },
	background = { drawing = false },
})

local current_pad_left, current_pad_right = icon_pad_left, icon_pad_right
local function refresh_icon_padding()
	settings.refresh_dock_width(function(dock_width, dock_hidden)
		local left_pad, right_pad = compute_icon_pad(dock_width, dock_hidden)
		if left_pad == current_pad_left and right_pad == current_pad_right then
			return
		end
		current_pad_left, current_pad_right = left_pad, right_pad
		startup.after_reveal("apple.padding", function()
			apple:set({ icon = { padding_left = left_pad, padding_right = right_pad } })
		end)
	end)
end

refresh_icon_padding()

apple:subscribe("mouse.clicked", function()
	sbar.delay(0, function()
		local frames = math.max(1, math.floor(timing.STANDARD_DURATION_FRAMES / 2))
		sbar.animate("linear", frames, function()
			apple:set({ icon = { color = colors.yellow } })
		end)
		sbar.delay(timing.frames_to_seconds(frames), function()
			sbar.animate("linear", frames, function()
				apple:set({ icon = { color = colors.green } })
			end)
		end)
	end)
	sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
end)

-- 显示器切换时重新检测 Dock 宽度，动态调整 icon padding。
-- 只响应 display_change；普通唤醒不应触发整套显示器同步。
apple:subscribe("display_change", function()
	dock_sync_generation = dock_sync_generation + 1
	local gen = dock_sync_generation
	for _, delay in ipairs({ 0.25, 1.25 }) do
		sbar.delay(delay, function()
			if dock_sync_generation ~= gen then
				return
			end
			refresh_icon_padding()
		end)
	end
end)
