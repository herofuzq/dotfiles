-- ========== Popup 弹出/收起：纯渐隐，无位移 ==========
-- 统一规范：所有内容切换动画跟随 timing.STANDARD_DURATION_FRAMES
--   - 不用 tanh：tanh 曲线在"长动画 + alpha 渐隐"场景下前 80% 时间几乎不可见，后 20% 突然"长出来"
--   - 不用 y_offset：只要渐隐感
--
-- hide 走 CLI 异步是为了避免 mouse/timer 回调里同步 parent:set 与 SketchyBar 事件互等（#794）。
-- 用 generation 协调 show/hide：若 hide CLI 完成时 generation 已变（用户又 hover 回来），
-- 则重新把 popup 打开，避免「晚到的 hide」关掉刚显示的 popup。
local appearance = require("appearance")
local timing = require("helpers.timing")
local sbar = require("sketchybar")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local M = {}

local DEFAULT_FRAMES = timing.STANDARD_DURATION_FRAMES
local SKETCHYBAR_BIN = os.getenv("SKETCHYBAR_BIN")
	or find_binary(
		{ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" },
		"/opt/homebrew/bin/sketchybar"
	)

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

	local function hide_via_cli_async(gen)
		if not parent or not parent.name then
			if generation == gen then
				parent:set({ popup = { drawing = false } })
				fire_on_hidden(options)
			end
			return
		end
		-- CLI 异步执行；完成回调里校验 generation，避免与 show 竞态
		sbar.exec(
			SKETCHYBAR_BIN .. " --set " .. shell_quote(parent.name) .. " popup.drawing=off >/dev/null 2>&1",
			function()
				if generation ~= gen then
					-- 期间已 show：把可能被 CLI 关掉的 popup 拉回来
					local color = background_color()
					parent:set({
						popup = {
							drawing = true,
							background = { color = color },
						},
					})
					return
				end
				fire_on_hidden(options)
			end
		)
	end

	local controller = {}

	function controller:show()
		generation = generation + 1
		local current_generation = generation
		local color = background_color()
		if visible then
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
		if animated then
			-- 名称保留 animated；实际为即时 CLI 关（避免 timer 内同步 set 死锁）
			hide_via_cli_async(generation)
			return
		end
		parent:set({ popup = { drawing = false } })
		fire_on_hidden(options)
	end

	function controller:hide_async()
		generation = generation + 1
		visible = false
		hide_via_cli_async(generation)
	end

	function controller:is_visible()
		return visible
	end

	return controller
end

return M
