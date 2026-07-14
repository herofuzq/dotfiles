-- ============================================================
-- Hammerspoon 入口
-- 各功能拆分到独立 .lua 文件，通过 require 加载
-- ============================================================

require("hs.ipc") -- 启用 hs CLI，便于安全重载与自动验证配置
require("caps_guard") -- 防止 Caps Lock 状态从 Raycast Hyper 映射中漏出
require("input") -- 输入法切换 + 终端中文提醒（必须在 wps 之前）
require("wps") -- WPS 右键自动切英文（通过 input 模块接口调用）
require("audio") -- 外接显示器自动切换音频输出
require("window_watcher") -- 浮窗安全区归位
require("floating_level") -- AeroSpace 判断 floating，BTT 按窗口 ID 置顶
require("floating_pin_toggle") -- Hyper+P 切换自动置顶功能
require("sketchybar_toggle") -- cmd+ctrl+opt+b 切换 sketchybar 显示/隐藏
