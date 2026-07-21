local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local added = {}
local applied = {}
local sbar = {
	add = function(...)
		local args = { ... }
		added[args[2]] = args
		return {}
	end,
	set = function(name, props) applied[#applied + 1] = { name = name, props = props } end,
	animate = function(_, _, callback) callback() end,
}
package.preload["sketchybar"] = function() return sbar end
package.preload["appearance"] = function()
	return {
		with_alpha = function(color, alpha)
			return (color & 0x00ffffff) | (math.floor(alpha * 255) * 0x1000000)
		end,
	}
end

local animation = require("helpers.enter_animation")
animation.install()
sbar.add("item", "demo", {
	drawing = false, -- workspace items start hidden, then their snapshot decides visibility
	icon = { color = 0xff112233 },
	label = { color = 0xff223344 },
	background = { color = 0xaa334455, border_color = 0xbb445566 },
})

sbar.add("bracket", "hidden-background", { "demo" }, {
	background = { drawing = false, color = 0xaa556677 },
})

local initial = added.demo[3]
assert((initial.icon.color >> 24) == 0)
assert((initial.label.color >> 24) == 0)
assert((initial.background.color >> 24) == 0)
assert((initial.background.border_color >> 24) == 0)

animation.update_target("demo", {
	icon = { color = 0xee667788 },
	label = { color = 0xdd778899 },
	background = { drawing = true, color = 0xcc8899aa, border_color = 0xbb99aabb },
})
animation.prepare()
animation.conceal()
animation.run()
assert(#applied == 2, "hidden backgrounds must not be animated")
assert(applied[1].name == "demo" and (applied[1].props.icon.color >> 24) == 0)
assert(applied[1].props.drawing == nil, "fade must not change item drawing")
assert(applied[2].name == "demo")
assert(applied[2].props.icon.color == 0xee667788)
assert(applied[2].props.label.color == 0xdd778899)
assert(applied[2].props.background.color == 0xcc8899aa)
assert(applied[2].props.background.border_color == 0xbb99aabb)
assert(applied[2].props.background.drawing == nil, "fade must not change background drawing")
assert(applied[2].props.drawing == nil, "fade must not restore add-time drawing")

print("enter_animation_test: ok")
