-- ============================================================
-- Hammerspoon 入口
-- 各功能拆分到独立 .lua 文件，通过 require 加载
-- ============================================================

-- hs.reload() 安全清理：先停止旧模块的全局 watcher/eventtap/filter，
-- 避免每次 reload 累积监听器导致重复触发。
if _HammerspoonReloadCount and _HammerspoonReloadCount > 0 then
	local function safeStop(ref)
		if ref then
			pcall(function() ref:stop() end)
		end
	end
	local function safeUnsubscribe(ref)
		if ref then
			pcall(function() ref:unsubscribe() end)
		end
	end
	safeStop(_CapsGuardTap)
	safeStop(_InputTap)
	safeStop(_WarnWatcher)
	safeStop(_InputSourceWatcher)
	safeStop(_WPSAppWatcher)
	safeStop(_WpsTap)
	safeStop(_WpsRecoverTimer)
	safeStop(_WakeWatcher)
	safeStop(_ScreenWatcher)
	safeStop(_windowWatcher_retryTimer)
	_windowWatcher_retryTimer = nil
	if _pendingTimer then
		pcall(function() _pendingTimer:stop() end)
		_pendingTimer = nil
	end
	safeUnsubscribe(_windowWatcher_filter)
end
_HammerspoonReloadCount = (_HammerspoonReloadCount or 0) + 1

require("caps_guard") -- 防止 Caps Lock 状态从 Raycast Hyper 映射中漏出
require("input") -- 输入法切换 + 终端中文提醒（必须在 wps 之前）
require("wps") -- WPS 右键自动切英文（通过 input 模块接口调用）
require("audio") -- 外接显示器自动切换音频输出
require("window_watcher") -- 浮窗安全区归位
require("floating_focus") -- Hyper+P 按需聚焦当前工作区的 floating 窗口
require("sketchybar_toggle") -- cmd+ctrl+opt+b 切换 sketchybar 显示/隐藏
