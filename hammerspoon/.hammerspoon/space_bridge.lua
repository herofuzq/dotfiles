-- ============================================================
-- Space Bridge: 监听 macOS 原生 Space 变化，推送数据给 sketchybar
-- 缓存每桌面窗口，调 w:focus() 触发原生切换+聚焦
-- ============================================================

local DATA_FILE = "/tmp/sketchybar_spaces.json"
local SWITCH_FILE = "/tmp/sketchybar_space_switch"
local last_data = ""

-- 缓存：mc_id(1-6) → 最近活跃的 hs.window 对象
local cachedWindows = {}

local function collectSpaceData()
	local all = hs.spaces.allSpaces()
	local cur_id = hs.spaces.focusedSpace()

	local spaces = {}
	for _, s in ipairs(all) do
		local mc_id = tonumber(s:getMissionControlID()) or 0
		local wins = {}
		local firstWin = nil
		for _, w in ipairs(s:windows()) do
			local app = w:application()
			wins[#wins + 1] = { id = w:id(), app = app and app:name() or "?", title = w:title() or "" }
			if not firstWin then firstWin = w end
		end
		-- 缓存第一个窗口用于后续聚焦切换
		if firstWin and mc_id > 0 then cachedWindows[mc_id] = firstWin end
		spaces[#spaces + 1] = { id = s:id(), mc_id = mc_id, display = s:screen():name(), windows = wins }
	end

	local data = hs.json.encode({ focused = cur_id, spaces = spaces })
	if data == last_data then return end
	last_data = data

	local f = io.open(DATA_FILE, "w")
	if f then f:write(data); f:close() end
	hs.execute("/opt/homebrew/bin/sketchybar --trigger space_changed 2>/dev/null")
end

-- 监听 Space 变化
local watcher = hs.spaces.watcher.new(function()
	hs.timer.doAfter(0.2, collectSpaceData)
end)
watcher:start()

-- 监听窗口变化
local wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowCreated, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowDestroyed, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowMoved, function() hs.timer.doAfter(0.3, collectSpaceData) end)

local screenWatcher = hs.screen.watcher.new(function() hs.timer.doAfter(0.5, collectSpaceData) end)
screenWatcher:start()

hs.timer.doAfter(1, collectSpaceData)

-- 处理 sketchybar 的空间切换请求：用缓存窗口 focus() 触发原生切换
hs.timer.new(0.3, function()
	local fh = io.open(SWITCH_FILE, "r")
	if not fh then return end
	local mc_id = tonumber(fh:read("*a"))
	fh:close()
	os.remove(SWITCH_FILE)
	if not mc_id then return end

	local w = cachedWindows[mc_id]
	if w then
		-- w:focus() 触发 macOS 原生空间切换 + 聚焦，无需 gotoSpace
		w:focus()
	else
		-- 冷启动：该桌面还没有缓存窗口，用 gotoSpace 兜底
		local all = hs.spaces.allSpaces()
		for _, s in ipairs(all) do
			if tonumber(s:getMissionControlID()) == mc_id then
				hs.spaces.gotoSpace(s)
				break
			end
		end
	end
end):start()

print("[space_bridge] macOS Space 监听已启动 → " .. DATA_FILE)
