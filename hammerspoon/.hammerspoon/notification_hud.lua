-- Shared transient notification HUD.
-- It uses the same position and geometry as the input-method indicator.

local HUD_WIDTH = 212
local HUD_HEIGHT = 26
local HUD_BOTTOM_OFFSET = 30
local HUD_CORNER_RADIUS = 10
local HUD_FADE_OUT_DURATION = 0.16

local MOCHA_BASE = { red = 30 / 255, green = 30 / 255, blue = 46 / 255 }
local MOCHA_SUBTEXT1 = { red = 186 / 255, green = 194 / 255, blue = 222 / 255 }
local MOCHA_GREEN = { red = 166 / 255, green = 227 / 255, blue = 161 / 255 }
local MOCHA_YELLOW = { red = 249 / 255, green = 226 / 255, blue = 175 / 255 }
local MOCHA_RED = { red = 243 / 255, green = 139 / 255, blue = 168 / 255 }

local HUD_BG = { red = MOCHA_BASE.red, green = MOCHA_BASE.green, blue = MOCHA_BASE.blue, alpha = 0.42 }
local TONE_COLORS = {
	neutral = { red = MOCHA_SUBTEXT1.red, green = MOCHA_SUBTEXT1.green, blue = MOCHA_SUBTEXT1.blue, alpha = 1.0 },
	success = { red = MOCHA_GREEN.red, green = MOCHA_GREEN.green, blue = MOCHA_GREEN.blue, alpha = 1.0 },
	warning = { red = MOCHA_YELLOW.red, green = MOCHA_YELLOW.green, blue = MOCHA_YELLOW.blue, alpha = 1.0 },
	error = { red = MOCHA_RED.red, green = MOCHA_RED.green, blue = MOCHA_RED.blue, alpha = 1.0 },
}

local M = {}
local hud
local hideTimer
local generation = 0

local function hudFrame()
	local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	local frame = screen:fullFrame()
	return {
		x = frame.x + math.floor((frame.w - HUD_WIDTH) / 2),
		y = frame.y + frame.h - HUD_HEIGHT - HUD_BOTTOM_OFFSET,
		w = HUD_WIDTH,
		h = HUD_HEIGHT,
	}
end

local function deleteHud(current)
	if not current then
		return
	end
	pcall(function() current:hide(HUD_FADE_OUT_DURATION) end)
	hs.timer.doAfter(HUD_FADE_OUT_DURATION + 0.02, function()
		pcall(function() current:delete() end)
	end)
end

local function clearHud()
	if hideTimer then
		hideTimer:stop()
		hideTimer = nil
	end
	if hud then
		local current = hud
		hud = nil
		deleteHud(current)
	end
end

local function resumeInputHud()
	if _inputHudResume then
		pcall(_inputHudResume)
	end
end

function M.show(text, tone, duration)
	generation = generation + 1
	local currentGeneration = generation
	clearHud()
	if _inputHudSuspend then
		pcall(_inputHudSuspend)
	end

	hud = hs.canvas.new(hudFrame())
	if not hud then
		resumeInputHud()
		return
	end
	local elements = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = HUD_BG,
			roundedRectRadii = { xRadius = HUD_CORNER_RADIUS, yRadius = HUD_CORNER_RADIUS },
			frame = { x = 0, y = 0, w = HUD_WIDTH, h = HUD_HEIGHT },
		},
		{
			type = "text",
			text = text,
			textFont = "SF Pro Text",
			textSize = 13,
			textColor = TONE_COLORS[tone] or TONE_COLORS.neutral,
			textAlignment = "center",
			frame = { x = 8, y = 5, w = HUD_WIDTH - 16, h = 18 },
		},
	}
	hud:appendElements(table.unpack(elements))
	hud:level(hs.canvas.windowLevels.overlay)
	hud:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
	hud:show()

	hideTimer = hs.timer.doAfter(duration or 0.80, function()
		if currentGeneration ~= generation then
			return
		end
		hideTimer = nil
		clearHud()
		resumeInputHud()
	end)
end

function M.hide()
	generation = generation + 1
	clearHud()
	resumeInputHud()
end

return M
