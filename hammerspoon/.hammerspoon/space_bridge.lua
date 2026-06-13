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
	local cur_id = hs.spaces.focusedSpace()
	-- hs.spaces.allSpaces() 在 macOS 26 Tahoe 返回空，改用手动分组
	local spaces_map = {}
	for _, w in ipairs(hs.window.allWindows()) do
		local app = w:application()
		if app and w:isStandard() then
			local spaceIDs = w:spaces()
			for _, sid in ipairs(spaceIDs or {}) do
				if not spaces_map[sid] then spaces_map[sid] = { id = sid, windows = {} } end
				spaces_map[sid].windows[#spaces_map[sid].windows + 1] = {
					id = w:id(), app = app:name() or "?", title = w:title() or ""
				}
			end
		end
	end
	-- 补充 mc_id：尝试从 allSpaces 获取，失败则用 ID 作为 mc_id
	local all = hs.spaces.allSpaces()
	for _, s in ipairs(all) do
		local sid = s:id()
		if spaces_map[sid] then
			spaces_map[sid].mc_id = tonumber(s:getMissionControlID()) or sid
		end
	end
	-- 转为数组
	local spaces = {}
	for _, s in pairs(spaces_map) do
		s.mc_id = s.mc_id or s.id
		s.display = hs.screen.mainScreen():name()
		spaces[#spaces + 1] = s
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
