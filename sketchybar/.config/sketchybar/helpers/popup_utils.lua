-- ========== Popup 状态管理通用工具 ==========
-- 为 calendar / battery / sys 等单 popup widget 提供统一的"固定/悬停/延迟隐藏"逻辑
local sbar = require("sketchybar")
local M = {}

function M.new_state()
	return { pinned = false, hovering = false, exit_gen = 0 }
end

function M.schedule_hide(state, hide_fn)
	if state.pinned then
		return
	end
	state.exit_gen = state.exit_gen + 1
	local gen = state.exit_gen
	sbar.delay(0.2, function()
		if state.exit_gen ~= gen then
			return
		end
		if state.hovering or state.pinned then
			return
		end
		hide_fn()
	end)
end

return M
