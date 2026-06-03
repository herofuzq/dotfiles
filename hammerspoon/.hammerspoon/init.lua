-- ============================================================
-- Hammerspoon 入口
-- 各功能拆分到独立 .lua 文件，通过 require 加载
-- ============================================================

require("input") -- 输入法切换 + 终端中文提醒（必须在 wps 之前）
require("wps") -- WPS 右键自动切英文（依赖 input 的 _FcitxInput）
require("audio") -- 外接显示器自动切换音频输出
-- require("aero_float") -- 浮动窗口置顶（依赖 BetterTouchTool）
