-- ========== SketchyBar 启动协调 ==========
-- 统一管理启动时序：隐藏、批量注册、揭示。
-- 外部状态查询由各 item 自己异步 hydrate，不放进这里的关键路径。
local sbar = require("sketchybar")

local M = {}

function M.hide()
	-- This runs before helper compilation or item creation. Keep it dependency-free.
	sbar.bar({
		hidden = "on",
		height = 0,
		color = 0x00000000,
		border_color = 0x00000000,
		border_width = 0,
		blur_radius = 0,
	})
end

function M.configure(load_items)
	sbar.begin_config()
	load_items()
	sbar.end_config()
end

function M.reveal()
	local appearance = require("appearance")
	local settings = require("settings")
	local timing = require("helpers.timing")

	-- 普通 reload 复用 settings.lua 首次读取的高度；显示器/唤醒事件
	-- 由 spaces.lua 的 display sync 单独重新检测，避免每次 reload 重复 fork。
	local bar_color = appearance.colors.bar_bg
	local border_color = appearance.colors.border
	sbar.bar({
		hidden = "off",
		height = settings.height,
		color = appearance.with_alpha(bar_color, 0),
		border_color = appearance.with_alpha(border_color, 0),
		border_width = 2,
		blur_radius = 15,
	})

	sbar.animate("linear", timing.ENTER_BAR_FADE_FRAMES, function()
		sbar.bar({
			color = bar_color,
			border_color = border_color,
		})
	end)

	-- AppKit's display query may wait briefly after wake/display changes. The first
	-- frame uses the valid cache; the real value corrects itself asynchronously.
	settings.refresh_bar_height(function(height)
		if height and height > 0 and height ~= settings.height then
			settings.height = height
			sbar.bar({ height = height })
		end
	end)
end

return M
