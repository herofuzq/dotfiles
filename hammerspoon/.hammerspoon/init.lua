-- ============================================================
-- Hammerspoon 入口
-- 各功能拆分到独立 .lua 文件，通过 require 加载
-- ============================================================

-- hs.reload() 会在全新 Lua 环境中重新执行本文件，旧 state 的全局变量不会继承，
-- 因此不存在可读的"上一轮"引用；旧 watcher/eventtap/timer 随旧 state 销毁自动清理。
-- reload/退出前需要同步收尾的逻辑（如补偿释放已按下的按键）请挂 hs.shutdownCallback。

require("caps_guard") -- 防止 Caps Lock 状态从 Raycast Hyper 映射中漏出
require("input") -- 输入法切换 + 终端中文提醒（必须在 wps 之前）
require("wps") -- WPS 右键自动切英文（通过 input 模块接口调用）
require("audio") -- 外接显示器自动切换音频输出
require("window_watcher") -- 浮窗安全区归位
require("floating_focus") -- Hyper+P 按需聚焦当前工作区的 floating 窗口
require("sketchybar_toggle") -- cmd+ctrl+opt+b 切换 sketchybar 显示/隐藏
