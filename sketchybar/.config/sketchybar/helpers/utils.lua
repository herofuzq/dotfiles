-- ========== 通用工具函数 ==========
-- 提供 shell_quote 等跨模块共享的基础函数，避免重复定义。
local M = {}

function M.shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- 临时文件路径：优先 $TMPDIR，否则 /tmp。name 不要带前导斜杠。
function M.tmp_path(name)
	local base = os.getenv("TMPDIR") or "/tmp"
	base = base:gsub("/+$", "")
	return base .. "/" .. tostring(name)
end

-- sysctl -n kern.boottime 输出形如：
--   { sec = 1785589567, usec = 410328 } Sat Aug  1 21:06:07 2026
function M.parse_boot_epoch(output)
	if type(output) ~= "string" then
		return nil
	end
	return tonumber(output:match("sec%s*=%s*(%d+)"))
end

return M
