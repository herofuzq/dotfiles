-- ============================================================
-- WPS 右键自动切英文 → 菜单消失后恢复中文
-- 仅在 WPS 激活时监听，不影响其他应用性能。
-- ============================================================

-- ---- 配置 ----
local WPS_APPS = {
	["com.kingsoft.wpsoffice.mac"] = true,
}
local input = require("input")
local notification = require("notification_hud")

-- ---- 内部状态 ----
local _switched = false
local RECOVER_DELAY = 0.3
-- hs.reload() 安全：_wpsTap / _recoverTimer 需要暴露为全局变量，
-- 让 init.lua 在 reload 时停止旧实例（模块级 local reload 后无法访问旧作用域）。
_WpsTap = nil
_WpsRecoverTimer = nil
local _sessionGeneration = 0

local function scheduleChineseRecovery(generation)
	if _WpsRecoverTimer then _WpsRecoverTimer:stop() end
	_WpsRecoverTimer = hs.timer.doAfter(RECOVER_DELAY, function()
		_WpsRecoverTimer = nil
		if generation ~= _sessionGeneration or not _switched then return end
		input.switchToChineseAsync(function(success)
			if generation ~= _sessionGeneration then return end
			if success then
				_switched = false
				notification.show("中文输入", "success", 0.5)
			end
		end)
	end)
end

-- ---- eventtap 管理 ----

local function createWPSTap()
	if _WpsTap then return end
	_WpsTap = hs.eventtap.new(
		{
			hs.eventtap.event.types.rightMouseDown,
			hs.eventtap.event.types.leftMouseDown,
			hs.eventtap.event.types.keyDown,
		},
		function(event)
			local etype = event:getType()
			if etype == hs.eventtap.event.types.rightMouseDown then
				_sessionGeneration = _sessionGeneration + 1
			end
			local generation = _sessionGeneration
			if etype == hs.eventtap.event.types.rightMouseDown then
				input.isChineseAsync(function(isChinese)
					if generation ~= _sessionGeneration or not isChinese then return end
					_switched = true
					input.switchToEnglishAsync(function(success)
						if generation ~= _sessionGeneration then return end
						if success then
							notification.show("英文输入", "success", 0.5)
						else
							_switched = false
						end
					end)
				end)
			elseif _switched then
				if etype == hs.eventtap.event.types.leftMouseDown then
					-- 等原生右键菜单关闭后再发送输入源快捷键，避免被菜单吞掉。
					scheduleChineseRecovery(generation)
				elseif etype == hs.eventtap.event.types.keyDown then
					-- trailing-edge 防抖：0.3 秒无键盘事件后恢复中文。
					scheduleChineseRecovery(generation)
				end
			end
			return false
		end
	)
	_WpsTap:start()
end

local function destroyWPSTap()
	_sessionGeneration = _sessionGeneration + 1
	if _WpsRecoverTimer then _WpsRecoverTimer:stop(); _WpsRecoverTimer = nil end
	if _switched then
		input.switchToChineseAsync()
		_switched = false
	end
	if _WpsTap then
		_WpsTap:stop()
		_WpsTap = nil
	end
end

-- ---- 应用激活/失活监听 ----

local function isWPSApp(app)
	if not app then return false end
	local ok, bundleID = pcall(function() return app:bundleID() end)
	return ok and WPS_APPS[bundleID] == true
end

_WPSAppWatcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated then
		if isWPSApp(app) then
			createWPSTap()
		end
	elseif event == hs.application.watcher.deactivated then
		if isWPSApp(app) then
			destroyWPSTap()
		end
	end
end)
_WPSAppWatcher:start()

-- ---- 启动时检查 ----
do
	local front = hs.application.frontmostApplication()
	if isWPSApp(front) then
		createWPSTap()
	end
end
