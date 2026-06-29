local M = {}

local function path_exists(path)
	local attr = hs.fs.attributes(path)
	return attr ~= nil
end

function M.find(candidates, fallback)
	for _, path in ipairs(candidates) do
		if path_exists(path) then
			return path
		end
	end

	-- hs.task.new 需要可访问的 launch path；裸命令名不会可靠走 shell PATH。
	if fallback and fallback:find("/", 1, true) and path_exists(fallback) then
		return fallback
	end

	return nil
end

function M.start(executable, args, callback)
	if not executable then
		return false, "executable not found"
	end
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

local aerospace = M.find({
	"/opt/homebrew/bin/aerospace",
	"/usr/local/bin/aerospace",
}, "aerospace")

function M.sketchybar(args, callback)
	return M.start(sketchybar, args, callback)
end

function M.aerospace(args, callback)
	return M.start(aerospace, args, callback)
end

function M.triggerSketchybar(event, callback, fields)
	local args = { "--trigger", event }
	for key, value in pairs(fields or {}) do
		args[#args + 1] = tostring(key) .. "=" .. tostring(value)
	end
	return M.sketchybar(args, callback)
end

return M
