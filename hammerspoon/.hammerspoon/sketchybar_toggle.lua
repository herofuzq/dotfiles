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
	return (stdout or ""):match('"hidden":%s*"(%w+)"') == "on"
end

hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "b", function()
	-- 异步链：先查 hidden 状态 → 翻 → 通知
	hs.task.new(SKETCHYBAR_BIN, function(_, qstdout)
		local next_state = parseHidden(qstdout) and "off" or "on"
		hs.task.new(SKETCHYBAR_BIN, function()
			hs.alert.show("▣ sketchybar 显示已切换", 0.5)
		end, { "--bar", "hidden=" .. next_state }):start()
	end, { "--query", "bar" }):start()
end)
