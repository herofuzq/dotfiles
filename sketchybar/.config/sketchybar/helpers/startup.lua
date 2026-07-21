-- ========== SketchyBar 启动协调 ==========
-- 统一管理启动时序：隐藏、批量注册、首屏就绪屏障、揭示。
local sbar = require("sketchybar")

local M = {}
local reveal_complete = false
local reveal_started = false
local pending_order = {}
local pending_callbacks = {}
local waiters = {}
local waiter_count = 0
local ready_callback

-- 外部查询可以在 reload 时并行运行，但它们的普通 set 会取消同属性的渐入。
-- 按组件保留最新一次 UI 提交，启动动画结束后再统一放行。
function M.after_reveal(key, callback)
	if reveal_complete then
		callback()
		return
	end
	if pending_callbacks[key] == nil then
		pending_order[#pending_order + 1] = key
	end
	pending_callbacks[key] = callback
end

-- 注册首屏依赖，返回一个幂等完成函数。失败和成功都必须调用完成函数；
-- 总超时会兜底放行，因此单个外部命令不能永久隐藏 bar。
function M.track(key)
	if reveal_started or waiters[key] ~= nil then
		return function() end
	end
	waiters[key] = false
	waiter_count = waiter_count + 1
	local done = false
	return function()
		if done then return end
		done = true
		if waiters[key] == false then
			waiters[key] = true
			waiter_count = waiter_count - 1
		end
		if waiter_count == 0 and ready_callback then
			local callback = ready_callback
			ready_callback = nil
			callback(false)
		end
	end
end

-- bar 尚未显示，可以安全提交真实字符串/计数。回调保留到渐入结束，
-- 这样在屏障超时边界晚到的状态仍会以最新值收尾。
local function prime_pending()
	for _, key in ipairs(pending_order) do
		local callback = pending_callbacks[key]
		if callback then
			local ok, err = pcall(callback)
			if not ok then
				io.stderr:write("sketchybar: startup prime failed: " .. tostring(err) .. "\n")
			end
		end
	end
end

function M.when_ready(callback)
	local timing = require("helpers.timing")
	local launched = false
	local function launch(timed_out)
		if launched then return end
		launched = true
		reveal_started = true
		ready_callback = nil
		prime_pending()
		callback(timed_out)
	end
	if waiter_count == 0 then
		sbar.delay(0, function() launch(false) end)
	else
		ready_callback = launch
		sbar.delay(timing.STARTUP_READY_TIMEOUT_SECONDS, function()
			launch(true)
		end)
	end
end

local function finish_reveal()
	if reveal_complete then
		return
	end
	reveal_complete = true
	for _, key in ipairs(pending_order) do
		local callback = pending_callbacks[key]
		if callback then
			local ok, err = pcall(callback)
			if not ok then
				io.stderr:write("sketchybar: startup callback failed: " .. tostring(err) .. "\n")
			end
		end
	end
	pending_order = {}
	pending_callbacks = {}
end

function M.hide()
	-- This runs before helper compilation or item creation. Keep it dependency-free.
	sbar.bar({
		hidden = "on",
		height = 0,
		color = 0x00000000,
		border_color = 0x00000000,
		border_width = 0,
		blur_radius = 0,
	})
end

function M.configure(load_items)
	sbar.begin_config()
	load_items()
	sbar.end_config()
end

function M.reveal()
	local appearance = require("appearance")
	local settings = require("settings")
	local timing = require("helpers.timing")

	-- 普通 reload 复用 settings.lua 首次读取的高度；显示器/唤醒事件
	-- 由 spaces.lua 的 display sync 单独重新检测，避免每次 reload 重复 fork。
	local bar_color = appearance.colors.bar_bg
	local border_color = appearance.colors.border
	sbar.bar({
		hidden = "off",
		height = settings.height,
		color = appearance.with_alpha(bar_color, 0),
		border_color = appearance.with_alpha(border_color, 0),
		border_width = 2,
		blur_radius = 15,
	})

	sbar.animate("linear", timing.ENTER_BAR_FADE_FRAMES, function()
		sbar.bar({
			color = bar_color,
			border_color = border_color,
		})
	end)
	sbar.delay(timing.frames_to_seconds(timing.ENTER_BAR_FADE_FRAMES), finish_reveal)

	-- AppKit's display query may wait briefly after wake/display changes. The first
	-- frame uses the valid cache; the real value corrects itself asynchronously.
	settings.refresh_bar_height(function(height)
		M.after_reveal("bar.height", function()
			if height and height > 0 and height ~= settings.height then
				settings.height = height
				sbar.bar({ height = height })
			end
		end)
	end)
end

return M
