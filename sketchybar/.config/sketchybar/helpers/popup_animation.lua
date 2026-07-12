-- ========== Popup 弹出/收起：纯渐隐，无位移 ==========
-- 统一规范：所有内容切换动画跟随 timing.STANDARD_DURATION_FRAMES
--   - 不用 tanh：tanh 曲线在"长动画 + alpha 渐隐"场景下前 80% 时间几乎不可见，后 20% 突然"长出来"，视觉上是瞬时出现
--   - 不用 y_offset：用户要求"渐隐感"，不要位移
--
-- 调用方只需传 background_color（默认 appearance.colors.pill_bg），动画内部自动处理 alpha。
-- 已存在的 on_prepare_show / on_show / on_hide / on_hidden 钩子仍可用（比如改 popup item 的 icon/label 颜色）。
local appearance = require("appearance")
local timing = require("helpers.timing")
local sbar = require("sketchybar")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local M = {}

-- 统一动画帧数：12 帧 @ 120Hz = 100ms
local DEFAULT_FRAMES = timing.STANDARD_DURATION_FRAMES
local SKETCHYBAR_BIN = os.getenv("SKETCHYBAR_BIN")
	or find_binary(
		{ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" },
		"/opt/homebrew/bin/sketchybar"
	)

local function hide_popup_via_cli(parent)
	if not parent or not parent.name then
		return false
	end
	sbar.exec(SKETCHYBAR_BIN .. " --set " .. shell_quote(parent.name) .. " popup.drawing=off >/dev/null 2>&1")
	return true
end

local function fire_on_hidden(options)
	if options and options.on_hidden then
		options.on_hidden()
	end
end

function M.new(parent, options)
	options = options or {}
	local frames = options.frames or DEFAULT_FRAMES
	local generation = 0
	local visible = false

	local function background_color()
		if type(options.background_color) == "function" then
			return options.background_color()
		end
		return options.background_color or appearance.colors.pill_bg
	end

	local controller = {}

	function controller:show()
		generation = generation + 1
		local current_generation = generation
		local color = background_color()
		if visible then
			-- hide 动画进行中被 show 打断：generation 递增已使 hide 的
			-- delay 回调失效，但 in-flight 的渐隐 animate 仍在跑。
			-- 这里直接 set popup 到目标颜色（snap），覆盖竞态的渐隐动画，
			-- 避免 popup 在用户 hover 回来时继续变暗甚至消失。
			parent:set({
				popup = {
					drawing = true,
					background = { color = color },
				},
			})
			if options.on_prepare_show then
				options.on_prepare_show()
			end
			if options.on_show then
				options.on_show()
			end
			return
		end
		visible = true
		-- 先把背景设为透明，再线性渐入到目标 alpha
		parent:set({
			popup = {
				drawing = true,
				background = { color = appearance.with_alpha(color, 0) },
			},
		})
		if options.on_prepare_show then
			options.on_prepare_show()
		end
		sbar.animate("linear", frames, function()
			if generation ~= current_generation then
				return
			end
			parent:set({ popup = { background = { color = color } } })
			if options.on_show then
				options.on_show()
			end
		end)
	end

	function controller:hide(animated)
		generation = generation + 1
		visible = false
		if animated and hide_popup_via_cli(parent) then
			-- CLI 异步关 popup 也要跑清理钩子（如 sys 停 watcher）
			fire_on_hidden(options)
			return
		end
		parent:set({ popup = { drawing = false } })
		fire_on_hidden(options)
	end

	-- 鼠标离开触发的延迟隐藏在 Lua timer 里运行；如果此时 SketchyBar 正在派发
	-- routine / mouse 事件，同步 parent:set 可能形成双向 IPC 等待。
	-- 这里改走外部 CLI 的异步 --set，让 Lua 回调立即返回，优先保证稳定。
	function controller:hide_async()
		generation = generation + 1
		visible = false
		if not hide_popup_via_cli(parent) then
			parent:set({ popup = { drawing = false } })
		end
		-- 与 hide() 一致：关 popup 后总是调用 on_hidden（sys_watch 停进程等）
		fire_on_hidden(options)
	end

	function controller:is_visible()
		return visible
	end

	return controller
end

return M
