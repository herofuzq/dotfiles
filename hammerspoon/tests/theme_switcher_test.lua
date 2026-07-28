local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;" .. package.path

local switcher = require("theme_switcher")

local canonical = switcher.state_content("everforest")
assert(canonical:find("# 可选主题：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox", 1, true))
assert(canonical:find("scheme=everforest\n", 1, true))
assert(switcher.state_content("dracula") == nil)

local temp_path = os.tmpname()
os.remove(temp_path)
local ok, err = switcher.write_state_atomic(temp_path, "kanagawa")
assert(ok, tostring(err))
local file = assert(io.open(temp_path, "r"))
local written = file:read("*a")
file:close()
os.remove(temp_path)
assert(written == switcher.state_content("kanagawa"))

local sequence = {}
local current = "gruvbox"
local image_calls = {}
local preview_image = {}
local controller = switcher.create({
	theme = {
		scheme_names = { "catppuccin", "tokyonight", "rosepine", "everforest", "kanagawa", "gruvbox" },
		is_valid_scheme = function(name)
			return name == "catppuccin"
				or name == "tokyonight"
				or name == "rosepine"
				or name == "everforest"
				or name == "kanagawa"
				or name == "gruvbox"
		end,
		current_scheme = function() return current end,
		current_flavor = function() return "dark" end,
		set_scheme = function(name)
			sequence[#sequence + 1] = "theme:" .. name
			current = name
			return true
		end,
	},
	write_state = function(_, name)
		sequence[#sequence + 1] = "write:" .. name
		return true
	end,
	state_path = "/tmp/theme_scheme_test",
	command = {
		sketchybar = function(args)
			sequence[#sequence + 1] = "sketchybar:" .. table.concat(args, " ")
			return true
		end,
	},
	notification = {
		show = function(text)
			sequence[#sequence + 1] = "notify:" .. text
		end,
	},
	image_for_scheme = function(name, flavor)
		image_calls[#image_calls + 1] = name .. ":" .. flavor
		if name == "rosepine" then
			error("render failed")
		end
		return preview_image
	end,
})

assert(controller.switch_to("gruvbox") == false, "当前主题应为 no-op")
assert(controller.switch_to("dracula") == false, "未知主题应被拒绝")
assert(#sequence == 0)
assert(controller.switch_to("everforest") == true)
assert(sequence[1] == "write:everforest")
assert(sequence[2] == "theme:everforest")
assert(sequence[3] == "sketchybar:--trigger theme_scheme_change SCHEME=everforest")
assert(sequence[4] == "notify:Theme · Everforest")

local choices = controller.choices()
assert(#choices == 6)
assert(choices[4].text == "✓ Everforest")
assert(choices[1].image == preview_image)
assert(choices[3].image == nil, "预览生成失败时应退回纯文字")
assert(image_calls[1] == "catppuccin:dark")
assert(image_calls[6] == "gruvbox:dark")

local failed_theme_calls = 0
local failed = switcher.create({
	theme = {
		scheme_names = { "gruvbox", "everforest" },
		is_valid_scheme = function(name) return name == "gruvbox" or name == "everforest" end,
		current_scheme = function() return "gruvbox" end,
		set_scheme = function()
			failed_theme_calls = failed_theme_calls + 1
			return true
		end,
	},
	write_state = function() return false, "permission denied" end,
	state_path = "/unwritable/theme_scheme",
	command = { sketchybar = function() error("must not notify SketchyBar") end },
	notification = { show = function() end },
})
assert(failed.switch_to("everforest") == false)
assert(failed_theme_calls == 0, "写入失败时 Hammerspoon 不应切换")

print("theme_switcher_test: ok")
