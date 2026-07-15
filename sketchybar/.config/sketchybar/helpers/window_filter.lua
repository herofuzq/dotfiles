-- 隐藏应用保留但不适合作为用户窗口展示的内部窗口。
local M = {}

function M.should_show(app, title)
	return not (app == "Typeless" and title == "Status")
end

return M
