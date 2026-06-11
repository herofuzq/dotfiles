-- 全局设置：高度、默认边距等
local function detect_bar_height()
	local fallback = 36
	-- 尝试用编译好的 Swift helper 实际测量（依赖 NSApplication GUI 上下文）
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/bar_height/bin/bar_height" 2>/dev/null')
		if f then
			for line in f:lines() do
				local is_main, h = line:match("^(1) (%d+)")
				if is_main then
					f:close()
					return tonumber(h)
				end
			end
			f:close()
		end
	end
	-- helper 不可用时用版本检测兜底
	return fallback
end

return {
	height = detect_bar_height(),
	detect_bar_height = detect_bar_height,
	default_padding = 8, -- 全局默认内边距（label/icon 等通用的左右 padding 数值）
	item_padding = { -- icon + label 组合条目的边距模板子表
		icon_label_item = {
			icon = {
				padding_left = 8,
				padding_right = 0,
			},
			label = {
				padding_left = 6,
				padding_right = 8,
			},
		},
	},
}
