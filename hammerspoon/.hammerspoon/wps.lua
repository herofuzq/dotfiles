-- ============================================================
-- WPS 右键自动切英文 → 菜单消失后恢复中文
-- 仅在 WPS 激活时监听，不影响其他应用性能。
-- ============================================================

-- ---- 配置 ----
local WPS_APPS = {
	["com.kingsoft.wpsoffice.mac"] = true,
}

-- ---- 内部状态 ----
local _switched = false
local _wpsTap = nil
local _recoverTimer = nil   -- trailing-edge 防抖：连续 keyDown 时只最后一次触发恢复

-- ---- eventtap 管理 ----

local function createWPSTap()
	if _wpsTap then return end
	_wpsTap = hs.eventtap.new(
		{ hs.eventtap.event.types.rightMouseDown,
		  hs.eventtap.event.types.leftMouseDown,
		  hs.eventtap.event.types.keyDown },
		function(event)
			local etype = event:getType()
			if etype == hs.eventtap.event.types.rightMouseDown then
				if _FcitxInput.isChinese() then
					_FcitxInput.switchToEnglishAsync()
					_switched = true
					hs.alert.show("⚠ ABC", 0.5)
				end
			elseif _switched then
				if etype == hs.eventtap.event.types.leftMouseDown then
					if _recoverTimer then _recoverTimer:stop(); _recoverTimer = nil end
					_FcitxInput.switchToChineseAsync()
					_switched = false
					hs.alert.show("⚠ 中文", 0.5)
				elseif etype == hs.eventtap.event.types.keyDown then
					-- trailing-edge 防抖：每次 key 都重置定时器，0.3s 无输入才恢复中文
					if _recoverTimer then _recoverTimer:stop() end
					_recoverTimer = hs.timer.doAfter(0.3, function()
						_recoverTimer = nil
						if _switched then
							_FcitxInput.switchToChineseAsync()
							_switched = false
							hs.alert.show("⚠ 中文", 0.5)
						end
					end)
				end
			end
			return false
		end
	)
	_wpsTap:start()
end

local function destroyWPSTap()
	if not _wpsTap then return end
	if _recoverTimer then _recoverTimer:stop(); _recoverTimer = nil end
	if _switched then
		_FcitxInput.switchToChineseAsync()
		_switched = false
	end
	_wpsTap:stop()
	_wpsTap = nil
end

-- ---- 应用激活/失活监听 ----

local function isWPSApp(app)
	return app and WPS_APPS[app:bundleID()]
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
