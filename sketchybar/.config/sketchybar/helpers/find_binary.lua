-- ========== 查找可执行文件路径 ==========
-- 在候选路径列表中找到第一个可执行文件，找不到则返回 fallback。
--
-- 用 `test -x` 而非 `io.open`：可读性无法区分可执行文件与目录或非可执行脚本。
-- 结果按「候选列表 + fallback」缓存，避免每个 widget require 时重复 fork。
--
-- 注意：本模块与 hammerspoon/command.lua 同名函数 find()，但运行环境不同，勿合并。
local shell_quote = require("helpers.utils").shell_quote

local M = {}
local _cache = {}

local function cache_key(candidates, fallback)
	return table.concat(candidates, "\0") .. "\0" .. tostring(fallback or "")
end

function M.find(candidates, fallback)
	local key = cache_key(candidates, fallback)
	if _cache[key] ~= nil then
		-- 用 false 标记「无结果」，避免每次都重扫
		local hit = _cache[key]
		return hit ~= false and hit or fallback
	end

	for _, path in ipairs(candidates) do
		local f = io.popen("test -x " .. shell_quote(path) .. " && echo 1")
		if f then
			local r = f:read("*a") or ""
			f:close()
			if r:sub(1, 1) == "1" then
				_cache[key] = path
				return path
			end
		end
	end

	_cache[key] = false
	return fallback
end

return M
