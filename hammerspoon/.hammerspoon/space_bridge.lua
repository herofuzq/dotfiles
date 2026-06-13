-- ============================================================
-- Space Bridge: 监听 macOS 原生 Space 变化
-- 跟踪窗口聚焦事件缓存活跃窗口，空间切换时自动聚焦
-- ============================================================

local DATA_FILE = "/tmp/sketchybar_spaces.json"
local last_data = ""
local lastActiveWindows = {}

-- 跟踪窗口聚焦，缓存每桌面上次活跃窗口
hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(win)
	if win then
		local spaceID = hs.spaces.focusedSpace()
		if spaceID and spaceID ~= -1 then
			lastActiveWindows[spaceID] = win
		end
	end
end)

local function collectSpaceData()
	local all = hs.spaces.allSpaces()
	local cur_id = hs.spaces.focusedSpace()
	local spaces = {}
	for _, s in ipairs(all) do
		local mc_id = tonumber(s:getMissionControlID()) or 0
		local wins = {}
		for _, w in ipairs(s:windows()) do
			local app = w:application()
			wins[#wins + 1] = { id = w:id(), app = app and app:name() or "?", title = w:title() or "" }
		end
		spaces[#spaces + 1] = { id = s:id(), mc_id = mc_id, display = s:screen():name(), windows = wins }
	end
	local data = hs.json.encode({ focused = cur_id, spaces = spaces })
	if data == last_data then return end
	last_data = data
	local f = io.open(DATA_FILE, "w")
	if f then f:write(data); f:close() end
	hs.execute("/opt/homebrew/bin/sketchybar --trigger space_changed 2>/dev/null")
end

-- 切换空间时自动聚焦该桌面上次活跃窗口
hs.spaces.watcher.new(function()
	hs.timer.doAfter(0.15, function()
		local spaceID = hs.spaces.focusedSpace()
		if not spaceID or spaceID == -1 then return end
		local target = lastActiveWindows[spaceID]
		if target and target:isVisible() then
			target:focus()
		else
			for _, w in ipairs(hs.window.allWindows()) do
				if w:isVisible() and w:screen() == hs.screen.mainScreen() then
					w:focus()
					break
				end
			end
		end
		collectSpaceData()
	end)
end):start()

-- 窗口变化 → 更新数据
local wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowCreated, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowDestroyed, function() hs.timer.doAfter(0.3, collectSpaceData) end)

local screenWatcher = hs.screen.watcher.new(function() hs.timer.doAfter(0.5, collectSpaceData) end)
screenWatcher:start()

hs.timer.doAfter(1, collectSpaceData)

print("[space_bridge] macOS Space 监听已启动 → " .. DATA_FILE)
