local M = {}

local function shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function is_executable(path)
	-- 用 hs.fs.attributes 代替 io.popen("test -x")，避免阻塞主线程。
	-- mode 格式如 "-rwxr-xr-x"，第 4 个字符是 owner execute bit。
	local attr = hs.fs.attributes(path)
	if not attr then
		return false
	end
	local mode = attr.mode or ""
	return #mode >= 4 and mode:sub(4, 4) == "x"
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
