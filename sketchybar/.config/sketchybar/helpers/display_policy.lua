-- 显示器/唤醒事件的门控决策。
-- 返回值：
--   ignore            正在 reveal，忽略迟到事件
--   absorb            刚 reveal 完的余震窗口，直接吸收
--   absorb_wake       睡眠中收到 wake/display，只记录等待解锁
--   verify_post_sleep 睡眠恢复后的验证窗口，probe-only
--   verify            清醒状态先 probe，确认变化后才进入遮罩
--   renew             settling 中的事件风暴，续期当前会话
local M = {}

function M.classify(gate_state, now, revealed_at, post_sleep_verify_until, reveal_grace_seconds)
	if gate_state == "revealing" then
		return "ignore"
	end
	if gate_state == "sleep_hidden" then
		return "absorb_wake"
	end
	if gate_state == "idle" then
		if revealed_at and revealed_at > 0 and now - revealed_at <= reveal_grace_seconds then
			return "absorb"
		end
		if post_sleep_verify_until and post_sleep_verify_until > 0 and now <= post_sleep_verify_until then
			return "verify_post_sleep"
		end
		return "verify"
	end
	if gate_state == "settling" then
		return "renew"
	end
	return "verify"
end

return M
