local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local added = {}
local applied = {}
local objects = {}
local bars = {}
local delayed = {}
local ops = {} -- set 与 bar 的统一顺序日志，用于断言 hidden/alpha 的先后
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
			set = function(_, props)
				applied[#applied + 1] = { name = name, props = props }
				ops[#ops + 1] = { t = "set", name = name, props = props }
			end,
		}
		return objects[name]
	end,
	set = function(name, props)
		applied[#applied + 1] = { name = name, props = props }
		ops[#ops + 1] = { t = "set", name = name, props = props }
	end,
	animate = function(_, _, callback) callback() end,
	bar = function(props)
		bars[#bars + 1] = props
		ops[#ops + 1] = { t = "bar", props = props }
	end,
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

-- 运行时完成门控：hold 压透明，release(token) 才渐入（不再是固定计时器）。
local token = animation.hold()
assert((last_applied("demo").props.icon.color >> 24) == 0, "hold must conceal current icon")
assert((bars[1].color >> 24) == 0, "hold must conceal bar")

-- sbar.set 与 item:set 共用同一个运行时颜色闸门。
sbar.set("demo", { icon = { color = 0xaa010203 } })
assert((last_applied("demo").props.icon.color >> 24) == 0, "late runtime color must remain concealed")
objects.demo:set({ label = { color = 0xaa040506 } })
assert((last_applied("demo").props.label.color >> 24) == 0, "late item:set color must remain concealed")

-- 过期 token 不能释放当前 hold。
local bar_count = #bars
local applied_count = #applied
animation.release(token + 1)
assert(#bars == bar_count, "stale token must not release the hold")
assert(#applied == applied_count, "stale token must not apply anything")
local stale_completed = false
animation.release(token + 1, function() stale_completed = true end)
assert(not stale_completed, "stale token must not run release completion")

-- 正常 release：渐入目标使用 hold 期间的最新颜色。
animation.release(token)
assert(last_applied("demo").props.icon.color == 0xaa010203, "fade target must use latest runtime color")
assert(last_applied("demo").props.label.color == 0xaa040506, "fade target must include latest item:set color")
assert(bars[#bars].color == 0x3311111b, "release must restore bar color")

-- 超时兜底与正常 release 竞速：只放一次（delayed[1] 是 hold 排程的超时回调）。
local applied_count = #applied
delayed[1]()
assert(#applied == applied_count, "hold timeout after release must be a no-op")

-- finalizer 恢复最新色并结束运行时闸门。
delayed[2]()
assert(last_applied("demo").props.icon.color == 0xaa010203, "finalizer must preserve latest runtime color")

-- 每次 hold 铸造新 token；旧 token 不能释放新 hold。
local token2 = animation.hold()
assert(token2 ~= token, "each hold must mint a new token")
animation.release(token)
assert((last_applied("demo").props.icon.color >> 24) == 0, "old token must not release the new hold")

-- 无人 release 时，超时兜底强制放行（delayed[3] 是第二次 hold 的超时回调）。
delayed[3]()
assert((last_applied("demo").props.icon.color >> 24) ~= 0, "hold timeout must force release as fallback")
delayed[4]() -- 第二次 release 的 finalizer

-- no_timeout hold（system_will_sleep 预遮罩）：不排程兜底超时。
local delayed_count = #delayed
local token3 = animation.hold({ no_timeout = true })
assert(#delayed == delayed_count, "no_timeout hold must not schedule a fallback timeout")
animation.release(token3)
delayed[#delayed]() -- release 的 finalizer

-- hidden 门控：hold({hidden=true}) 隐藏整条 bar；release 必须先 item alpha 0、
-- 再 hidden=off（背景同步 alpha 0），最后渐入恢复（reload 同款顺序）。
local htoken = animation.hold({ hidden = true })
local last_bar = bars[#bars]
assert(last_bar.hidden == "on", "hidden hold must set bar hidden=on")

local ops_before_release = #ops
local release_completed = false
animation.release(htoken, function()
	release_completed = true
end)
local unhide_index
for index, op in ipairs(ops) do
	if op.t == "bar" and op.props.hidden == "off" then
		unhide_index = index
		break
	end
end
assert(unhide_index, "release must unhide the bar")
for index = ops_before_release + 1, unhide_index - 1 do
	local op = ops[index]
	if op.t == "set" and op.props.icon then
		assert((op.props.icon.color >> 24) == 0, "items must be alpha 0 before hidden=off")
	end
end
assert((ops[unhide_index].props.color >> 24) == 0, "bar background must be alpha 0 at hidden=off")
assert((last_applied("demo").props.icon.color >> 24) ~= 0, "fade must restore item colors")
assert(not release_completed, "release completion must wait for the fade finalizer")
delayed[#delayed]() -- finalizer
assert(release_completed, "release completion must run after the fade finalizer")
local late_completion = false
animation.release(htoken, function() late_completion = true end)
assert(late_completion, "same-token completion registered after the fade must run immediately")

print("enter_animation_test: ok")
