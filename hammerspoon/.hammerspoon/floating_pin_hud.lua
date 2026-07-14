local notification = require("notification_hud")
local M = {}

function M.show(enabled)
	notification.show(enabled and "浮动置顶：开启" or "浮动置顶：关闭", enabled and "success" or "warning", 0.80)
end

return M
