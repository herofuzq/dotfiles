-- ============================================================
-- cmd+ctrl+opt + b → 切换 Sketchybar 显示/隐藏
-- hyper = cmd+ctrl+opt（由 Raycast 定义，按键穿透到 Hammerspoon）
-- ============================================================

-- 复用 window_watcher.lua 的路径解析风格
local function findSketchybar()
	local candidates = { "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" }
	for _, p in ipairs(candidates) do
		if hs.fs.attributes(p, "mode") == "file" then return p end
	end
	return "sketchybar" -- fallback to PATH
end
local SKETCHYBAR_BIN = findSketchybar()

-- 从 sketchybar --query bar 的 JSON 输出中解析 hidden 状态
local function parseHidden(stdout)
	local ok, data = pcall(hs.json.decode, stdout or "")
	if not ok or type(data) ~= "table" or type(data.hidden) ~= "string" then
		return nil
	end
	return data.hidden == "on"
end

local function startSketchybarTask(args, callback)
	local ok, task = pcall(hs.task.new, SKETCHYBAR_BIN, callback, args)
	if not ok or not task then
		hs.alert.show("Sketchybar 命令启动失败", 1.0)
		return false
	end
	local started, result = pcall(function() return task:start() end)
	if not started or not result then
		hs.alert.show("Sketchybar 命令启动失败", 1.0)
		return false
	end
	return true
end

hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "b", function()
	-- 异步链：先查 hidden 状态 → 翻 → 通知
	startSketchybarTask({ "--query", "bar" }, function(exitCode, qstdout, stderr)
		local hidden = parseHidden(qstdout)
		if exitCode ~= 0 or hidden == nil then
			print("[SketchybarToggle] 查询失败: " .. tostring(stderr or exitCode))
			hs.alert.show("无法读取 Sketchybar 状态", 1.0)
			return
		end
		local nextState = hidden and "off" or "on"
		startSketchybarTask({ "--bar", "hidden=" .. nextState }, function(setExitCode, _, setStderr)
			if setExitCode == 0 then
				hs.alert.show("▣ Sketchybar 显示已切换", 0.5)
			else
				print("[SketchybarToggle] 设置失败: " .. tostring(setStderr or setExitCode))
				hs.alert.show("Sketchybar 切换失败", 1.0)
			end
		end)
	end)
end)
