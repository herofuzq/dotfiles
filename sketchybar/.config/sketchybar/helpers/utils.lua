-- ========== 通用工具函数 ==========
-- 提供 shell_quote 等跨模块共享的基础函数，避免重复定义。
local M = {}

function M.shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

return M
