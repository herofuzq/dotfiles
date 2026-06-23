local M = {}

local function shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function is_executable(path)
	local f = io.popen("test -x " .. shell_quote(path) .. " && echo 1")
	if not f then
		return false
	end
	local r = f:read("*a") or ""
	f:close()
	return r:sub(1, 1) == "1"
end

function M.find(candidates, fallback)
	for _, path in ipairs(candidates) do
		if is_executable(path) then
			return path
		end
	end
	-- fallback 是无路径的程序名（如 "sketchybar"），交给 hs.task.new 走 PATH 解析。
	-- 不能用 test -x 卡它：test -x 不查 PATH，自编译装到 ~/bin 的 binary 会漏。
	if fallback then
		return fallback
	end
	return nil
end

function M.start(executable, args, callback)
	local ok, task = pcall(hs.task.new, executable, callback, args)
	if not ok or not task then
		return false, tostring(task)
	end
	local started, result = pcall(function() return task:start() end)
	if not started or not result then
		return false, tostring(result)
	end
	return true
end

local sketchybar = M.find({
	"/opt/homebrew/bin/sketchybar",
	"/usr/local/bin/sketchybar",
}, "sketchybar")

function M.sketchybar(args, callback)
	return M.start(sketchybar, args, callback)
end

function M.triggerSketchybar(event, callback, fields)
	local args = { "--trigger", event }
	for key, value in pairs(fields or {}) do
		args[#args + 1] = tostring(key) .. "=" .. tostring(value)
	end
	return M.sketchybar(args, callback)
end

return M
