-- ============================================================
-- Space Bridge: 监听 Space 变化，推送数据 + 主动聚焦切换
-- ============================================================

local DATA_FILE = "/tmp/sketchybar_spaces.json"
local SWITCH_FILE = "/tmp/sketchybar_space_switch"
local last_data = ""
local keyCodes = { 18, 19, 20, 21, 23, 22 }

local function collectSpaceData()
	local cur_id = hs.spaces.focusedSpace()
	local spaces_map = {}
	for _, w in ipairs(hs.window.allWindows()) do
		local app = w:application()
		if app and w:isStandard() then
			local spaceIDs = w:spaces()
			for _, sid in ipairs(spaceIDs or {}) do
				if not spaces_map[sid] then spaces_map[sid] = { id = sid, windows = {} } end
				spaces_map[sid].windows[#spaces_map[sid].windows + 1] = {
					id = w:id(), app = app:name() or "?", title = w:title() or "" }
			end
		end
	end
	local spaces = {}
	for _, s in pairs(spaces_map) do
		s.mc_id = s.id; s.display = hs.screen.mainScreen():name()
		spaces[#spaces + 1] = s
	end
	local data = hs.json.encode({ focused = cur_id, spaces = spaces })
	if data == last_data then return end
	last_data = data
	local f = io.open(DATA_FILE, "w")
	if f then f:write(data); f:close() end
	hs.execute("/opt/homebrew/bin/sketchybar --trigger space_changed 2>/dev/null")
end

hs.spaces.watcher.new(function() hs.timer.doAfter(0.2, collectSpaceData) end):start()
local wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowCreated, function() hs.timer.doAfter(0.3, collectSpaceData) end)
wf:subscribe(hs.window.filter.windowDestroyed, function() hs.timer.doAfter(0.3, collectSpaceData) end)
hs.screen.watcher.new(function() hs.timer.doAfter(0.5, collectSpaceData) end):start()
hs.timer.doAfter(1, collectSpaceData)

-- 主动空间切换：发快捷键 + 延迟聚焦前台窗口
hs.timer.new(0.3, function()
	local fh = io.open(SWITCH_FILE, "r")
	if not fh then return end
	local mc_id = tonumber(fh:read("*a"))
	fh:close()
	os.remove(SWITCH_FILE)
	if not mc_id or mc_id < 1 or mc_id > 6 then return end
	hs.eventtap.keyStroke({"cmd", "ctrl", "alt"}, tostring(mc_id))
	hs.timer.doAfter(0.4, function()
		local app = hs.application.frontmostApplication()
		if app and app:name() ~= "通知中心" then app:activate() end
	end)
end):start()

print("[space_bridge] macOS Space 监听已启动 → " .. DATA_FILE)
