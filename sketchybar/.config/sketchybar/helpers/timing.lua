-- ========== 时序常量 ==========
-- 全局时序基准：所有动画时长、delay 都基于 120Hz 帧率假设。
-- 集中在这里是为了：
--   1) 改"标准动画时长"一处生效（不再散落 magic 24/120）
--   2) 改"popup 隐藏延迟"一处生效
--   3) 让 frame↔second 转换统一，避免每个文件自己写 /120
local M = {}

-- ProMotion 设备的刷新率。所有 frame↔seconds 转换都基于此。
-- 60Hz 设备看起来稍慢但稳定。
M.FRAMES_PER_SECOND = 120

-- 把帧数转换为秒（用于 sbar.delay）。
-- 用法: sbar.delay(M.frames_to_seconds(12), ...) -- 12 帧 = 100ms
function M.frames_to_seconds(frames)
	return frames / M.FRAMES_PER_SECOND
end

-- 标准动画时长（100ms = 12 帧 @ 120Hz）。
-- 用于 popup 渐入、label 颜色渐变等"通用 fade"；popup 隐藏目前是即时关闭。
M.STANDARD_DURATION_FRAMES = 12

-- 启动 bar 与 item 同步 alpha 渐入（约 500ms = 60 帧 @ 120Hz）。
-- 两者使用同一时长，避免 bar 和内容分成两个视觉阶段。
M.ENTER_BAR_FADE_FRAMES = 60
M.ENTER_ITEM_FADE_FRAMES = 60

return M
