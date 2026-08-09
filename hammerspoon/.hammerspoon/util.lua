-- Shared utilities for Hammerspoon modules.
-- Keep this file free of `hs` references so the unit tests can load it directly.

local M = {}

-- Atomic file write: write beside `path`, then rename over it.
-- Returns true on success, or false, err on failure.
function M.atomic_write(path, content)
	local temporary = string.format("%s.tmp.%d.%d", path, os.time(), math.random(100000, 999999))
	local file, open_error = io.open(temporary, "w")
	if not file then
		return false, tostring(open_error)
	end
	local wrote, write_error = file:write(content)
	if not wrote then
		file:close()
		os.remove(temporary)
		return false, tostring(write_error)
	end
	local closed, close_error = file:close()
	if not closed then
		os.remove(temporary)
		return false, tostring(close_error)
	end
	local renamed, rename_error = os.rename(temporary, path)
	if not renamed then
		os.remove(temporary)
		return false, tostring(rename_error)
	end
	return true
end

-- Bundle IDs skipped by both window rescue and floating-focus selection.
M.SKIP_BUNDLE_IDS = {
	["pl.maketheweb.cleanshotx"] = true,
}

-- Geometry shared by input.lua and notification_hud.lua.
M.hud = {
	width = 212,
	height = 26,
	bottom_offset = 30,
	corner_radius = 10,
	fade_out_duration = 0.16,
}

return M
