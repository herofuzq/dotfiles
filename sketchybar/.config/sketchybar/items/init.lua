-- ========== 加载所有状态栏条目（从左到右排列） ==========
require("items.apple") --  Apple logo（最左）
require("items.services") -- notch 左侧服务状态灯（position=q）
require("items.git") -- Git 状态显示
require("items.spaces") -- aerospace 工作区（内含异步加载 front_app）
require("items.calendar") -- 日期时间
require("items.widgets")

-- 启动渐入：startup 在 end_config() 后揭示 bar，enter_animation 负责 item 渐入
