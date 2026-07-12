-- ========== Popup 弹出/收起 ==========
-- show：背景 color alpha 线性渐入（无 y_offset）。
-- hide / hide_async：瞬时关闭（CLI 异步 popup.drawing=off），没有渐出动画。
--   原因：timer/mouse 回调里同步 parent:set 可能与 SketchyBar 事件 IPC 互等（#794）。
-- generation：hide CLI 完成时若 generation 已变（用户又 show），则把 popup 拉回，
--   避免「晚到的 hide」关掉刚显示的 popup。on_hidden 在 hide 路径校验 generation 后触发。
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
