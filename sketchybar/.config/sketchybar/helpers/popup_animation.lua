-- ========== Popup 弹出/收起 ==========
-- show：背景 color alpha 线性渐入（无 y_offset）。
-- hide / hide_async：瞬时关闭，没有渐出动画；通过下一事件循环提交状态。
--   原因：timer/mouse 回调里同步 parent:set 可能与 SketchyBar 事件 IPC 互等（#794）。
-- generation：延迟提交前校验代数，避免旧 hide 关掉刚显示的 popup。
local appearance = require("appearance")
local timing = require("helpers.timing")
local sbar = require("sketchybar")

local M = {}

local DEFAULT_FRAMES = timing.STANDARD_DURATION_FRAMES

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

	local function defer_set(gen, props, callback)
		sbar.delay(0, function()
			if generation ~= gen then
				return
			end
			parent:set(props)
			if callback then
				callback()
			end
		end)
	end

	function controller:show()
		generation = generation + 1
		local current_generation = generation
		local color = background_color()
		if visible then
			defer_set(current_generation, {
				popup = {
					drawing = true,
					background = { color = color },
				},
			}, function()
				if options.on_prepare_show then
					options.on_prepare_show()
				end
				if options.on_show then
					options.on_show()
				end
			end)
			return
		end
		visible = true
		defer_set(current_generation, {
			popup = {
				drawing = true,
				background = { color = appearance.with_alpha(color, 0) },
			},
		}, function()
			if options.on_prepare_show then
				options.on_prepare_show()
			end
		end)
		sbar.animate("linear", frames, function()
			if generation ~= current_generation then
				return
			end
			defer_set(current_generation, { popup = { background = { color = color } } }, function()
				if options.on_show then
					options.on_show()
				end
			end)
		end)
	end

	function controller:hide(_use_cli)
		generation = generation + 1
		visible = false
		defer_set(generation, { popup = { drawing = false } }, function()
			fire_on_hidden(options)
		end)
	end

	function controller:hide_async()
		generation = generation + 1
		visible = false
		defer_set(generation, { popup = { drawing = false } }, function()
			fire_on_hidden(options)
		end)
	end

	function controller:is_visible()
		return visible
	end

	return controller
end

return M
