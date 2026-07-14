-- Hyper+P toggles automatic floating-window pinning.

local state = require("floating_pin_state")
local hud = require("floating_pin_hud")

if _floatingPinToggleHotkey then
	_floatingPinToggleHotkey:delete()
end

_floatingPinToggleHotkey = hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "p", function()
	local enabled = state.toggle()
	hud.show(enabled)
	print("[floating_pin_toggle] automatic BTT pin " .. (enabled and "enabled" or "disabled"))
	if enabled then
		if _floatingLevelReconcile then
			_floatingLevelReconcile(true)
		end
	elseif _floatingLevelUnpinAll then
		_floatingLevelUnpinAll()
	end
end)

return true
