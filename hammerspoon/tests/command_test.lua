local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;" .. package.path

local launched_path
local launched_args

hs = {
	fs = {
		attributes = function(path)
			if path == "/opt/homebrew/bin/ya" then
				return { mode = "file" }
			end
			return nil
		end,
	},
	task = {
		new = function(path, _, args)
			launched_path = path
			launched_args = args
			return {
				start = function()
					return true
				end,
			}
		end,
	},
}

local command = require("command")
local ok = command.ya({ "emit-to", "0", "app:theme" })

assert(ok == true)
assert(launched_path == "/opt/homebrew/bin/ya")
assert(table.concat(launched_args, " ") == "emit-to 0 app:theme")

print("command_test.lua OK")
