-- 全局设置：高度、默认边距等
local function detect_bar_height()
	local fallback = 36
	local ver = 15
	local f = io.popen("sw_vers -productVersion 2>/dev/null")
	if f then
		ver = tonumber(f:read("*a"):match("^(%d+)")) or 15
		f:close()
	end
	local has_notch = false
	f = io.popen("aerospace list-monitors --json 2>/dev/null")
	if f then
		local output = f:read("*a")
		f:close()
		has_notch = output and output:match("Built%-in") ~= nil
	end
	-- macOS 26 Tahoe 把非刘海屏菜单栏从 24pt 增加到 ~31pt
	if has_notch then
		return 37
	elseif ver >= 26 then
		return 31
	end
	return 24
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
