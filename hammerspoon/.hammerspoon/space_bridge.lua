-- ============================================================
-- Space Bridge: 监听 macOS 原生 Space 变化，推送数据给 sketchybar
-- 仅在 aerospace 未运行时激活（由 spaces.lua 双模式检测配合）
-- ============================================================

local DATA_FILE = "/tmp/sketchybar_spaces.json"
local last_data = ""

local function collectSpaceData()
	local all = hs.spaces.allSpaces()
	local cur_id = hs.spaces.focusedSpace()

	local spaces = {}
	for _, s in ipairs(all) do
		local wins = {}
		for _, w in ipairs(s:windows()) do
			local app = w:application()
			wins[#wins + 1] = {
				id = w:id(),
				app = app and app:name() or "?",
				title = w:title() or "",
			}
		end
		spaces[#spaces + 1] = {
			id = s:id(),
			mc_id = tonumber(s:getMissionControlID()) or 0,
			display = s:screen():name(),
			windows = wins,
		}
	end

	local data = hs.json.encode({ focused = cur_id, spaces = spaces })
	if data == last_data then return end
	last_data = data

	local f = io.open(DATA_FILE, "w")
	if f then f:write(data); f:close() end
	hs.execute("/opt/homebrew/bin/sketchybar --trigger space_changed 2>/dev/null")
end

-- 监听 Space 变化
local watcher = hs.spaces.watcher.new(collectSpaceData)
watcher:start()

-- 监听窗口变化
local wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowCreated, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowDestroyed, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowMoved, function() hs.timer.doAfter(0.3, collectSpaceData) end)

-- 监听屏幕参数变化（插拔显示器）
local screenWatcher = hs.screen.watcher.new(function()
	hs.timer.doAfter(0.5, collectSpaceData)
end)
screenWatcher:start()

-- 初始收集
hs.timer.doAfter(1, collectSpaceData)

print("[space_bridge] macOS Space 监听已启动 → " .. DATA_FILE)

-- 监听 sketchybar 的空间切换请求（带焦点）
local SWITCH_FILE = "/tmp/sketchybar_space_switch"
local switchWatcher = hs.pathwatcher.new("/tmp/", function(files)
	for _, f in ipairs(files) do
		if f == SWITCH_FILE then
			local fh = io.open(f, "r")
			if fh then
				local mc_id = tonumber(fh:read("*a"))
				fh:close()
				os.remove(f)
				if mc_id then
					local all = hs.spaces.allSpaces()
					for _, s in ipairs(all) do
						if tonumber(s:getMissionControlID()) == mc_id then
							local wins = s:windows()
							if #wins > 0 then wins[1]:focus() end
							hs.spaces.gotoSpace(s)
							break
						end
					end
				end
			end
		end
	end
end)
switchWatcher:start()
