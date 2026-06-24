-- ========== 查找可执行文件路径 ==========
-- 在候选路径列表中找到第一个可执行文件，找不到则返回 fallback。
--
-- 用 `test -x` 而非 `io.open`：可读性无法区分可执行文件与目录或非可执行脚本，
-- 也能避免 0 权限的同名文件误判。代价：每次调用会 fork 一次 sh -c "test -x ..."，
-- 实际延迟 < 5ms，可忽略。
--
-- 注意：本模块与 hammerspoon/command.lua 同名函数 find()，但运行环境不同：
--   - hammerspoon 用 hs.fs.attributes(path, "mode") == "file"
--   - 这里用 io.popen + sh test -x
-- 两套实现不能合并，否则会引入 hammerspoon 在 sketchybar Lua 里被 require 的依赖。
local shell_quote = require("helpers.utils").shell_quote

local M = {}

function M.find(candidates, fallback)
	for _, path in ipairs(candidates) do
		local f = io.popen("test -x " .. shell_quote(path) .. " && echo 1")
		if f then
			local r = f:read("*a") or ""
			f:close()
			if r:sub(1, 1) == "1" then
				return path
			end
		end
	end
	return fallback
end

return M
