-- ========== jankyborders 主题联动 ==========
-- SketchyBar 是边框的运行与配色负责人：首次加载启动，主题切换时热更新。
local sbar = require("sketchybar")
local appearance = require("appearance")
local shell_quote = require("helpers.utils").shell_quote

local M = {}

function M.command(color, home)
	local active_color = string.format("0x%08x", color)
	local bordersrc = home .. "/.config/borders/bordersrc"
	return "BORDERS_ACTIVE_COLOR=" .. shell_quote(active_color) .. " " .. shell_quote(bordersrc)
end

function M.install()
	local function apply(C)
		sbar.exec(M.command(C.identity.window_border, os.getenv("HOME")))
	end

	appearance.register_colors("window_border", apply)
	apply(appearance.colors)
end

return M
