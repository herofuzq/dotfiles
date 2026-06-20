local M = {}

function M.find(candidates, fallback)
	for _, path in ipairs(candidates) do
		if hs.fs.attributes(path, "mode") == "file" then
			return path
		end
	end
	return fallback
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
