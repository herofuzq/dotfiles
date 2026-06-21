local appearance = require("appearance")
local sbar = require("sketchybar")

local M = {}

function M.new(parent, options)
	options = options or {}
	-- @120Hz: 默认 133ms(macOS 标准菜单弹出节奏)
	local frames = options.frames or 16
	local y_offset = options.y_offset or 2
	local hidden_y_offset = options.hidden_y_offset or (y_offset + 3)
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
		if visible then
			return
		end
		visible = true
		local color = background_color()
		parent:set({
			popup = {
				drawing = true,
				y_offset = hidden_y_offset,
				background = { color = appearance.with_alpha(color, 0) },
			},
		})
		if options.on_prepare_show then
			options.on_prepare_show()
		end
		sbar.animate("tanh", frames, function()
			parent:set({ popup = { y_offset = y_offset, background = { color = color } } })
			if options.on_show then
				options.on_show()
			end
		end)
	end

	function controller:hide(animated)
		generation = generation + 1
		local current_generation = generation
		visible = false
		if not animated then
			parent:set({ popup = { drawing = false } })
			if options.on_hidden then
				options.on_hidden()
			end
			return
		end

		local color = background_color()
		sbar.animate("tanh", frames, function()
			parent:set({
				popup = {
					y_offset = hidden_y_offset,
					background = { color = appearance.with_alpha(color, 0) },
				},
			})
			if options.on_hide then
				options.on_hide()
			end
		end)
		sbar.delay(frames / 120, function()
			if generation ~= current_generation or visible then
				return
			end
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
