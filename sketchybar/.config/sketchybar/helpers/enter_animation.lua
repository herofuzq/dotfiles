-- ========== Bar/Item 渐入动画 ==========
-- 由 init.lua 在 sbar.end_config() 之后调用一次:
--   1) bar 从完全透明渐入到目标颜色 (color + border)   533ms
--   2) bar 渐入完成后,登记的 item 逐个 set drawing=true  200ms + stagger
--
-- "渐隐感"实现:
--  - bar 用 linear 渐入(0x00000000 → 0x3311111b),这本身就有"渐隐"
--  - item 在 bar 内部 stagger 出现,看起来"陆续从 bar 中浮出"
--  - 不动 y_offset、不动 background 颜色,避免改变 item 默认外观
--  - 不动 drawing 初始状态: item 创建时 drawing 是什么就是什么,
--    reload 时 enter_animation.run() 立即把它们设 false,bar 渐入完成后逐个 set true
--
-- 帧率假设: 所有动画按 120Hz 固定算(ProMotion)。
--  - 120Hz 设备:动画时长 = 帧数 / 120
--  - 60Hz 设备:动画时长 = 帧数 / 60(看起来稍慢但稳定)
local sbar = require("sketchybar")
local appearance = require("appearance")
local timing = require("helpers.timing")

local M = {}

-- @120Hz: BAR 533ms, REVEAL 总约 200ms+stagger
local STAGGER_FRAMES = 4
local BAR_FRAMES = 64
local REVEAL_FRAMES = 24

local _pending = {}

function M.register(name, opts)
	opts = opts or {}
	-- 事件订阅根等控制项必须始终隐藏，不能被揭示动画改成可见。
	if opts.hidden then
		return
	end
	_pending[#_pending + 1] = { name = name }
end

-- 立即把登记的 item 设为 drawing=false(bar 渐入期间不可见)
-- 然后在 run_bar 完成后逐个 set drawing=true
function M.run()
	for i, p in ipairs(_pending) do
		sbar.set(p.name, { drawing = false })
	end
end

-- Bar 颜色渐入 + item 揭示
function M.run_bar()
	sbar.animate("linear", BAR_FRAMES, function()
		sbar.bar({
			color = appearance.colors.bar_bg,
			border_color = appearance.colors.border,
			border_width = 2,
		})
		-- bar 渐入完成,逐个把 item 设为可见
		for i, p in ipairs(_pending) do
			local delay = timing.frames_to_seconds((i - 1) * STAGGER_FRAMES)
			sbar.delay(delay, function()
				sbar.animate("linear", REVEAL_FRAMES, function()
					sbar.set(p.name, { drawing = true })
				end)
			end)
		end
	end)
end

-- 动态创建的 item(workspaces)在 add 后立即调,触发延迟揭示
function M.spawn(name, opts)
	sbar.set(name, { drawing = false })
	sbar.animate("linear", REVEAL_FRAMES, function()
		sbar.set(name, { drawing = true })
	end)
end

return M
