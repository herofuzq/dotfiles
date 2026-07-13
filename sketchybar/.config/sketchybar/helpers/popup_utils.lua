-- ========== Popup 状态管理通用工具 ==========
-- 为 calendar / battery / sys 等单 popup widget 提供统一的"固定/悬停/延迟隐藏"逻辑
local sbar = require("sketchybar")
local timing = require("helpers.timing")
local M = {}

function M.new_state()
	return { pinned = false, hovering = false, hovered_items = {}, exit_gen = 0 }
end

function M.schedule_hide(state, hide_fn)
	if state.pinned then
		return
	end
	state.exit_gen = state.exit_gen + 1
	local gen = state.exit_gen
	sbar.delay(timing.POPUP_HIDE_DELAY_S, function()
		if state.exit_gen ~= gen then
			return
		end
		if state.hovering or state.pinned then
			return
		end
		hide_fn()
	end)
end

-- 给 popup 子项批量绑定 hover 事件，替代各 widget 中重复的 mouse.entered / mouse.exited 模版代码。
-- items: 要绑定的 item 列表（可以是 sbar item 对象，也可以是 table）。
-- state: popup_utils.new_state() 返回的状态表。
-- scheduleHide_fn: widget 本地的延迟隐藏函数（包装了 popup_utils.schedule_hide）。
function M.bind_popup_hover(items, state, scheduleHide_fn)
	for _, item in ipairs(items) do
		item:subscribe("mouse.entered", function()
			state.exit_gen = state.exit_gen + 1
			if not state.hovered_items[item] then
				state.hovered_items[item] = true
			end
			state.hovering = true
		end)
		item:subscribe("mouse.exited", function()
			state.hovered_items[item] = nil
			state.hovering = next(state.hovered_items) ~= nil
			scheduleHide_fn()
		end)
	end
end

return M
