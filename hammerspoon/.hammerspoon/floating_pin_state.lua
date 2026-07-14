-- Runtime switch for automatic AeroSpace floating-window pinning.

local M = {}

if _floatingPinEnabled == nil then
	_floatingPinEnabled = true
end

function M.isEnabled()
	return _floatingPinEnabled == true
end

function M.toggle()
	_floatingPinEnabled = not M.isEnabled()
	return _floatingPinEnabled
end

function M.setEnabled(enabled)
	_floatingPinEnabled = enabled == true
	return _floatingPinEnabled
end

return M
