-- ========== 时序常量 ==========
-- 全局时序基准：SketchyBar 的 animation duration 按 60Hz 步数定义。
-- 集中在这里是为了：
--   1) 改"标准动画时长"一处生效（不再散落 magic 24/120）
--   2) 改"popup 隐藏延迟"一处生效
--   3) 让 frame↔second 转换统一，避免每个文件自己写 /120
local M = {}

-- 即使显示器是 ProMotion，SketchyBar 官方仍以 60 steps/s 换算时长。
M.FRAMES_PER_SECOND = 60

-- 把帧数转换为秒（用于 sbar.delay）。
-- 用法: sbar.delay(M.frames_to_seconds(6), ...) -- 6 steps = 100ms
function M.frames_to_seconds(frames)
	return frames / M.FRAMES_PER_SECOND
end

-- 标准动画时长（100ms = 6 steps @ 60Hz）。
-- 用于 popup 渐入、label 颜色渐变等"通用 fade"；popup 隐藏目前是即时关闭。
M.STANDARD_DURATION_FRAMES = 6

-- 启动 bar 与 item 同步 alpha 渐入（约 500ms = 30 steps @ 60Hz）。
-- 两者使用同一时长，避免 bar 和内容分成两个视觉阶段。
M.ENTER_BAR_FADE_FRAMES = 30
M.ENTER_ITEM_FADE_FRAMES = 30

-- 唤醒/显示器变化后先给异步状态和首阶段屏幕映射一个短暂收敛窗口，
-- 再复用 500ms 整体渐入；重叠事件由 generation 合并。
M.RUNTIME_FADE_SETTLE_SECONDS = 0.30

-- 首屏异步数据最长等待时间。超时只放行显示，不取消仍在运行的查询。
M.STARTUP_READY_TIMEOUT_SECONDS = 1.0

return M
