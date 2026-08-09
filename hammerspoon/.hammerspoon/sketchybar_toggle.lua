-- ============================================================
-- cmd+ctrl+opt + b → 切换 Sketchybar 显示/隐藏
-- hyper = cmd+ctrl+opt（由 Raycast 定义，按键穿透到 Hammerspoon）
-- ============================================================

local command = require("command")
local notification = require("notification_hud")

local VERIFY_DELAY = 0.2

-- 从 sketchybar --query bar 的 JSON 输出中解析 hidden 状态
local function parseHidden(stdout)
	local ok, data = pcall(hs.json.decode, stdout or "")
	if not ok or type(data) ~= "table" or type(data.hidden) ~= "string" then
		return nil
	end
	return data.hidden == "on"
end

local function startSketchybarTask(args, callback)
	local started, err = command.sketchybar(args, callback)
	if not started then
		print("[SketchybarToggle] 命令启动失败: " .. tostring(err))
		notification.show("SketchyBar：切换失败", "error", 1.0)
		return false
	end
	return true
end

-- 写入后回读真实 hidden，按实际状态提示，避免“设置成功但未生效”时提示相反。
local function verifyAndNotify()
	startSketchybarTask({ "--query", "bar" }, function(exitCode, qstdout, stderr)
		local hidden = parseHidden(qstdout)
		if exitCode ~= 0 or hidden == nil then
			print("[SketchybarToggle] 回读失败: " .. tostring(stderr or exitCode))
			notification.show("SketchyBar：状态未知", "warning", 1.0)
			return
		end
		notification.show(hidden and "SketchyBar：隐藏" or "SketchyBar：显示", "success", 0.5)
	end)
end

hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "b", function()
	-- 异步链：先查 hidden 状态 → 翻 → 延迟回读确认 → 通知
	startSketchybarTask({ "--query", "bar" }, function(exitCode, qstdout, stderr)
		local hidden = parseHidden(qstdout)
		if exitCode ~= 0 or hidden == nil then
			print("[SketchybarToggle] 查询失败: " .. tostring(stderr or exitCode))
			notification.show("SketchyBar：读取失败", "error", 1.0)
			return
		end
		local nextState = hidden and "off" or "on"
		startSketchybarTask({ "--bar", "hidden=" .. nextState }, function(setExitCode, _, setStderr)
			if setExitCode == 0 then
				hs.timer.doAfter(VERIFY_DELAY, verifyAndNotify)
			else
				print("[SketchybarToggle] 设置失败: " .. tostring(setStderr or setExitCode))
				notification.show("SketchyBar：切换失败", "error", 1.0)
			end
		end)
	end)
end)
