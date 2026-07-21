local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local added = {}
local applied = {}
local objects = {}
local bars = {}
local delayed = {}
local function last_applied(name)
	for index = #applied, 1, -1 do
		if applied[index].name == name then return applied[index] end
	end
end

local sbar = {
	add = function(...)
		local args = { ... }
		added[args[2]] = args
		local name = args[2]
		objects[name] = {
			set = function(_, props) applied[#applied + 1] = { name = name, props = props } end,
		}
		return objects[name]
	end,
	set = function(name, props) applied[#applied + 1] = { name = name, props = props } end,
	animate = function(_, _, callback) callback() end,
	bar = function(props) bars[#bars + 1] = props end,
	delay = function(_, callback) delayed[#delayed + 1] = callback end,
}
package.preload["sketchybar"] = function() return sbar end
package.preload["appearance"] = function()
	return {
		colors = { bar_bg = 0x3311111b, border = 0x336c7086 },
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

animation.transition(0.3)
assert((last_applied("demo").props.icon.color >> 24) == 0, "runtime transition must conceal current icon")
assert((bars[1].color >> 24) == 0, "runtime transition must conceal bar")

-- sbar.set 与 item:set 共用同一个运行时颜色闸门。
sbar.set("demo", { icon = { color = 0xaa010203 } })
assert((last_applied("demo").props.icon.color >> 24) == 0, "late runtime color must remain concealed")
objects.demo:set({ label = { color = 0xaa040506 } })
assert((last_applied("demo").props.label.color >> 24) == 0, "late item:set color must remain concealed")

delayed[1]()
assert(last_applied("demo").props.icon.color == 0xaa010203, "fade target must use latest runtime color")
assert(last_applied("demo").props.label.color == 0xaa040506, "fade target must include latest item:set color")
assert(bars[#bars].color == 0x3311111b, "runtime transition must restore bar color")
delayed[2]()
assert(last_applied("demo").props.icon.color == 0xaa010203, "finalizer must preserve latest runtime color")

print("enter_animation_test: ok")
