local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;" .. package.path

local calls = {}
local focused_window_id

local windows = {
	[42] = {
		isStandard = function() return true end,
		focus = function() focused_window_id = 42 end,
	},
}

local window_api = {
	frontmostWindow = function() return nil end,
}
setmetatable(window_api, {
	__call = function(_, id) return windows[id] end,
})

_G.hs = {
	window = window_api,
	hotkey = {
		bind = function()
			return { delete = function() end }
		end,
	},
}

package.loaded.command = {
	aerospace = function(args, callback)
		calls[#calls + 1] = args
		callback(0, "42|com.example.Float|5Term|floating|floating\n")
		return true
	end,
}
package.loaded.notification_hud = { show = function() end }

package.loaded.floating_focus = nil
local floating_focus = require("floating_focus")
floating_focus.focus()

assert(#calls == 1, "Hyper+P should issue one AeroSpace query, got " .. tostring(#calls))
assert(calls[1][1] == "list-windows", "the single query should request focused-workspace windows")
assert(focused_window_id == 42, "the eligible floating window should still receive focus")

print("floating_focus_test: ok")
