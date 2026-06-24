-- ========== Popup 弹出/收起：纯渐隐，无位移 ==========
-- 统一规范：所有内容切换动画 = 24 帧 / 200ms linear
--   - 不用 tanh：tanh 曲线在"长动画 + alpha 渐隐"场景下前 80% 时间几乎不可见，后 20% 突然"长出来"，视觉上是瞬时出现
--   - 不用 y_offset：用户要求"渐隐感"，不要位移
--
-- 调用方只需传 background_color（默认 appearance.colors.pill_bg），动画内部自动处理 alpha。
-- 已存在的 on_prepare_show / on_show / on_hide / on_hidden 钩子仍可用（比如改 popup item 的 icon/label 颜色）。
local appearance = require("appearance")
local sbar = require("sketchybar")

local M = {}

-- 统一动画帧数：24 帧 @ 120Hz = 200ms
local DEFAULT_FRAMES = 24

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
			parent:set({ popup = { background = { color = color } } })
			if options.on_show then
				options.on_show()
			end
		end)
	end

	function controller:hide(animated)
		generation = generation + 1
		local current_generation = generation
		if not animated then
			visible = false
			parent:set({ popup = { drawing = false } })
			if options.on_hidden then
				options.on_hidden()
			end
			return
		end

		local color = background_color()
		sbar.animate("linear", frames, function()
			parent:set({
				popup = {
					background = { color = appearance.with_alpha(color, 0) },
				},
			})
			if options.on_hide then
				options.on_hide()
			end
		end)
		sbar.delay(frames / 120, function()
			if generation ~= current_generation then
				return
			end
			visible = false
			parent:set({ popup = { drawing = false } })
			if options.on_hidden then
				options.on_hidden()
			end
		end)
	end

	function controller:is_visible()
		return visible
	end

	return controller
end

return M
