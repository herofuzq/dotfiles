-- ========== Popup 回调工具 ==========
-- Popup 统一由点击切换；这里只保留跨事件循环提交 UI 的能力。
local sbar = require("sketchybar")
local M = {}

-- Mouse callbacks arrive synchronously over SbarLua's Mach channel. Return
-- before sending UI mutations back to SketchyBar to avoid upstream deadlock #794.
function M.defer(callback)
	sbar.delay(0, callback)
end

return M
