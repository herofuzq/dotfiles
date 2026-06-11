-- 全局设置：高度、默认边距等
local function detect_bar_height()
	local fallback = 32
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/bar_height/bin/bar_height" 2>/dev/null')
		if f then
			for line in f:lines() do
				local is_main, bar, safe = line:match("^(1) bar=(%d+) safe=(%d+)")
				if is_main then
					f:close()
					bar, safe = tonumber(bar), tonumber(safe)
					if safe and safe > 0 then
						return safe
					elseif bar and bar > 0 then
						return bar
					else
						return fallback
					end
				end
			end
			f:close()
		end
	end
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
