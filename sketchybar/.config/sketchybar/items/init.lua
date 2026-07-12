-- ========== 加载所有状态栏条目（从左到右排列） ==========
require("helpers.borders") -- 全屏边框管理
require("items.apple") --  Apple logo（最左）
require("items.services") -- notch 左侧服务状态灯（position=q）
require("items.git") -- Git 状态显示
require("items.spaces") -- aerospace 工作区（内含异步加载 front_app）
require("items.calendar") -- 日期时间
require("items.widgets")

-- 启动渐隐：init.lua 在 end_config() 之后调用 enter_animation.prepare/run
