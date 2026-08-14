-- ========== 屏幕锁状态探测 ==========
-- 读取 IOConsoleLocked（IORegistry Root 节点的布尔属性）判断屏幕是否锁定。
-- 严格三态：locked / unlocked / unknown。
-- unknown 覆盖：ioreg 非零退出、输出缺失、属性缺失、取值冲突（同时出现 Yes 与 No）。
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
	local yes = output:find('"IOConsoleLocked"%s*=%s*Yes', 1, false)
	local no = output:find('"IOConsoleLocked"%s*=%s*No', 1, false)
	if yes and not no then
		return "locked"
	end
	if no and not yes then
		return "unlocked"
	end
	return nil
end

-- 同步探测（io.popen，~20ms）。阻塞式无超时上限；ioreg 稳定且极快，
-- 若未来需要严格超时再改异步 sbar.exec + delay 守卫。
function M.detect_sync(command)
	local ok, output, exit_code = pcall(function()
		local f = io.popen(command or M.build_probe_command())
		if not f then
			return nil, nil
		end
		local out = f:read("*a")
		local closed, reason, code = f:close()
		if closed then
			return out, 0
		end
		return out, reason == "exit" and code or nil
	end)
	if not ok then
		return nil
	end
	return M.parse(output, exit_code)
end

return M
