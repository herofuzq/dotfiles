-- ========== 屏幕锁状态探测 ==========
-- 读取 IOConsoleLocked（IORegistry Root 节点的布尔属性）判断屏幕是否锁定。
-- 严格三态：locked / unlocked / unknown。
-- unknown 覆盖：ioreg 非零退出、输出缺失、属性缺失、重复/冲突/不完整取值。
-- 调用方必须把 unknown 当作「没有新证据」，绝不能据此授权显示。

local M = {}

-- 只 dump Root 节点一层，实测 ~20ms；不经过 grep 管道，
-- 原始输出与 ioreg 自身退出码一并交给 Lua 纯函数解析，避免掩盖上游失败。
function M.build_probe_command()
	return "/usr/sbin/ioreg -r -n Root -d1 -l -w0 2>/dev/null"
end

-- 解析 ioreg 原始输出 + 退出码。
-- 返回 "locked" / "unlocked" / nil（unknown）。
function M.parse(output, exit_code)
	if type(output) ~= "string" or tonumber(exit_code) ~= 0 then
		return nil
	end
	local matches = 0
	local state
	for line in (output .. "\n"):gmatch("(.-)\n") do
		local normalized_line = line:gsub("\r$", "")
		if normalized_line:find('"IOConsoleLocked"', 1, true) then
			matches = matches + 1
			local value = normalized_line:match('^%s*"IOConsoleLocked"%s*=%s*(%a+)%s*$')
			if value == "Yes" then
				state = "locked"
			elseif value == "No" then
				state = "unlocked"
			else
				return nil
			end
		end
	end
	return matches == 1 and state or nil
end

-- 异步探测：exec callback 与 2s timeout 共享 first-wins 终止守卫。
-- SbarLua 事件循环不再被 ioreg 阻塞，迟到 callback 也不会二次通知调用方。
function M.probe(callback)
	local sbar = require("sketchybar")
	local terminal = false
	local function finish(state, reason)
		if terminal then
			return
		end
		terminal = true
		callback(state, reason)
	end

	sbar.delay(2.0, function()
		finish(nil, "timeout")
	end)
	sbar.exec(M.build_probe_command(), function(output, exit_code)
		local state = M.parse(output, exit_code)
		if state then
			finish(state, nil)
		else
			finish(nil, "invalid")
		end
	end)
end

return M
