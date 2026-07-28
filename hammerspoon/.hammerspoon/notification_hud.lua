-- Shared transient notification HUD.
-- It uses the same position and geometry as the input-method indicator.

local theme = require("theme")

local HUD_WIDTH = 212
local HUD_HEIGHT = 26
local HUD_BOTTOM_OFFSET = 30
local HUD_LANE_GAP = 8
local HUD_CORNER_RADIUS = 10
local HUD_FADE_OUT_DURATION = 0.16

local HUD_COLORS = theme.colors()

local M = {}
local hud
local hudTone = "neutral"
local hideTimer
local generation = 0

theme.subscribe("notification_hud", function(colors)
	HUD_COLORS = colors
	if hud then
		hud:elementAttribute(1, "fillColor", HUD_COLORS.background)
		hud:elementAttribute(2, "textColor", HUD_COLORS.tones[hudTone] or HUD_COLORS.tones.neutral)
	end
end)

local function hudFrame()
	local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
	local frame = screen:fullFrame()
	return {
		x = frame.x + math.floor((frame.w - HUD_WIDTH) / 2),
		-- Keep transient feedback above the persistent input-method lane.
		y = frame.y + frame.h - (HUD_HEIGHT * 2) - HUD_BOTTOM_OFFSET - HUD_LANE_GAP,
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

function M.show(text, tone, duration)
	generation = generation + 1
	local currentGeneration = generation
	clearHud()
	hudTone = tone or "neutral"

	hud = hs.canvas.new(hudFrame())
	if not hud then
		return
	end
	local elements = {
		{
			type = "rectangle",
			action = "fill",
			fillColor = HUD_COLORS.background,
			roundedRectRadii = { xRadius = HUD_CORNER_RADIUS, yRadius = HUD_CORNER_RADIUS },
			frame = { x = 0, y = 0, w = HUD_WIDTH, h = HUD_HEIGHT },
		},
		{
			type = "text",
			text = text,
			textFont = "SF Pro Text",
			textSize = 13,
			textColor = HUD_COLORS.tones[hudTone] or HUD_COLORS.tones.neutral,
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
	end)
end

function M.hide()
	generation = generation + 1
	clearHud()
end

return M
