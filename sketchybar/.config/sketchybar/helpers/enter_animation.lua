-- ========== Bar/Item 启动显隐 ==========
-- 由 init.lua 在 sbar.end_config() 之后调用一次:
--   1) bar 从启动阶段的透明状态切到目标颜色 (color + border)
--   2) 登记的 item 统一设为 drawing=true
--
-- 说明：之前这里使用 sbar.delay + sbar.animate 做 stagger 渐入。
-- 实测卡死时 sample 显示 Lua timer 中的 animate 会和 SketchyBar 的 routine
-- 事件同步 IPC 互等；启动显隐属于纯视觉效果，优先改成无 timer 的稳定路径。
local sbar = require("sketchybar")
local appearance = require("appearance")

local M = {}

local _pending = {}

function M.register(name, opts)
	opts = opts or {}
	-- 事件订阅根等控制项必须始终隐藏，不能被揭示动画改成可见。
	if opts.hidden then
		return
	end
	_pending[#_pending + 1] = { name = name }
end

function M.run()
	for i, p in ipairs(_pending) do
		sbar.set(p.name, { drawing = true })
	end
end

function M.run_bar()
	sbar.bar({
		color = appearance.colors.bar_bg,
		border_color = appearance.colors.border,
		border_width = 2,
	})
end

function M.spawn(name, opts)
	sbar.set(name, { drawing = true })
end

return M
