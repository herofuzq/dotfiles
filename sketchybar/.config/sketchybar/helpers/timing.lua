-- ========== 时序常量 ==========
-- 全局时序基准：所有动画时长、delay 都基于 120Hz 帧率假设。
-- 集中在这里是为了：
--   1) 改"标准动画时长"一处生效（不再散落 magic 24/120）
--   2) 改"popup 隐藏延迟"一处生效
--   3) 让 frame↔second 转换统一，避免每个文件自己写 /120
local M = {}

-- ProMotion 设备的刷新率。所有 frame↔seconds 转换都基于此。
-- 60Hz 设备看起来稍慢但稳定（详见 enter_animation.lua 头部注释）。
M.FRAMES_PER_SECOND = 120

-- 把帧数转换为秒（用于 sbar.delay）。
-- 用法: sbar.delay(M.frames_to_seconds(24), ...) -- 24 帧 = 200ms
function M.frames_to_seconds(frames)
	return frames / M.FRAMES_PER_SECOND
end

-- Popup 隐藏延迟（用户移开鼠标后多久开始隐藏）。
-- popup_utils.schedule_hide 和 spaces.lua 的 scheduleHide 都用这个值。
M.POPUP_HIDE_DELAY_S = 0.2

-- 标准动画时长（200ms = 24 帧 @ 120Hz）。
-- 用于 popup 渐入/渐出、label 颜色渐变、drawing 切换等"通用 fade"。
-- 特殊的 bar 渐入（533ms）、stagger 间隔（33ms）等保留在各自模块里。
M.STANDARD_DURATION_FRAMES = 24

return M