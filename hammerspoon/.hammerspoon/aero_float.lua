-- ============================================================
-- Aerospace 浮动窗口 → 置顶（通过 BetterTouchTool）
-- reload 时自动从 aerospace.toml 解析 if.app-id + layout floating，
-- 与手动维护的标题规则 + com.apple.* 合并。
-- 需要 BTT 命名 trigger: always-on-top
-- ============================================================

-- ---- 解析 aerospace.toml ----
local function parseAeroFloatRules(tomlPath)
	local f = io.open(tomlPath, "r")
	if not f then return {} end
	local content = f:read("*a")
	f:close()

	local rules = {}
	-- 按 [[on-window-detected]] 分块
	local pos, block, newPos = 1
	while pos <= #content do
		newPos = content:find("%[%[on%-window%-detected%]%]", pos)
		if not newPos then break end
		local blockEnd = content:find("%[%[", newPos + 1)
		blockEnd = blockEnd or (#content + 1)
		block = content:sub(newPos, blockEnd - 1)

		local appId = block:match('if%.app%-id%s*=%s*"([^"]+)"')
		local hasFloating = block:find("layout floating", 1, true)
		if appId and hasFloating then
			rules[appId] = true
		end
		pos = blockEnd
	end

	return rules
end

local HOME = os.getenv("HOME")
local TOML = HOME .. "/dotfiles/aerospace/.config/aerospace/aerospace.toml"

-- ---- 自动规则（从 toml 解析） + 手动补充 ----
local FLOAT_RULES = parseAeroFloatRules(TOML)

-- 以下为 aerospace.toml 中解析不到的标题条件规则（手动维护）
FLOAT_RULES["com.tencent.xinWeChat"] = { titleNot = "^%s*微信%s*$" }
FLOAT_RULES["com.alibaba.DingTalkMac"] = { titleNot = "钉钉" }
FLOAT_RULES["com.mac.utility.media.hub"] = { titleMatch = "视频播放器" }

local TITLE_FLOAT_PATTERNS = {
	"(setting|设置|LuLu|lulu|滴答|会议|钉钉会议)",
	"(Picture.in.Picture|画中画)",
}

-- 黑名单：即使命中规则也不 pin
local EXCLUDE = {
	["org.hammerspoon.Hammerspoon"] = true,
}

-- ---- 匹配 ----
local function getBundleID(win)
	if not win then return nil end
	local ok, app = pcall(function() return win:application() end)
	if ok and app then
		local ok2, bid = pcall(function() return app:bundleID() end)
		if ok2 and bid then return bid end
	end
	local okPid, pid = pcall(function() return win:pid() end)
	if okPid and type(pid) == "number" and pid > 0 then
		local app2 = hs.application.applicationForPID(pid)
		if app2 then
			local ok3, bid3 = pcall(function() return app2:bundleID() end)
			if ok3 and bid3 then return bid3 end
		end
	end
	return nil
end

local function isFloatWindow(win)
	if not win then return false end
	local bid = getBundleID(win)
	if not bid then return false end
	if EXCLUDE[bid] then return false end
	if bid:find("apple", 1, true) then return true end
	local rule = FLOAT_RULES[bid]
	if rule == true then return true end
	if type(rule) == "table" then
		local title = win:title() or ""
		if rule.titleNot and title:find(rule.titleNot) then return false end
		if rule.titleMatch and not title:find(rule.titleMatch) then return false end
		return true
	end
	local title = win:title() or ""
	for _, pat in ipairs(TITLE_FLOAT_PATTERNS) do
		if title:find(pat) then return true end
	end
	return false
end

-- ---- BTT 触发器 ----
local function bttPin()
	hs.applescript('tell application "BetterTouchTool" to trigger_named "always-on-top"')
end

-- ---- 置顶状态 ----
local _topWinId = nil

local function setTopmost(win, bid)
	local wid = win:id()
	if _topWinId == wid then return end
	_topWinId = wid
	bttPin()
	print("[AeroFloat] " .. (bid or "?") .. " id=" .. wid)
end

-- ---- 回调 ----
local function onFocusChanged(window, _, _)
	if not window then return end
	local bid = getBundleID(window)
	if bid and isFloatWindow(window) then
		setTopmost(window, bid)
	end
end

local function onWindowDestroyed(window)
	if window and _topWinId and window:id() == _topWinId then
		_topWinId = nil
	end
end

-- ---- Space 切换 ----
local function onSpaceChange()
	local wins = hs.window.allWindows()
	for _, w in ipairs(wins) do
		if isFloatWindow(w) then
			local wid = w:id()
			if wid and _topWinId ~= wid then
				setTopmost(w, getBundleID(w))
			end
			return
		end
	end
	_topWinId = nil
end

-- ---- 启动 ----
_AeroFloatFilter = hs.window.filter.new()
_AeroFloatFilter:subscribe(hs.window.filter.windowFocused, onFocusChanged)
_AeroFloatFilter:subscribe(hs.window.filter.windowDestroyed, onWindowDestroyed)
_SpaceWatcher = hs.spaces.watcher.new(onSpaceChange)
_SpaceWatcher:start()

do local n=0;for _ in pairs(FLOAT_RULES)do n=n+1 end;print("[AeroFloat] "..n.." 条规则 (自动解析 + com.apple.*)")end
