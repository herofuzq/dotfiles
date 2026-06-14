-- 全局设置：高度、默认边距等
local function detect_bar_height()
	local fallback = 30
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/bar_height/bin/bar_height" 2>/dev/null')
		if f then
			local output = f:read("*a")
			f:close()
			local h = output:match("^(%d+)")
			if h then
				h = tonumber(h)
				if h > 0 then
					return h
				end
			end
		end
	end
	return fallback
end

local function detect_dock_width()
	local fallback = 55
	local cfg = os.getenv("CONFIG_DIR")
	if cfg then
		local f = io.popen('"' .. cfg .. '/helpers/dock_width/bin/dock_width" 2>/dev/null')
		if f then
			local output = f:read("*a")
			f:close()
			local w, hidden = output:match("^(%d+)%s+(%d+)")
			if w then
				return tonumber(w), tonumber(hidden) or 0
			end
		end
	end
	return fallback, 0
end

return {
	height = detect_bar_height(),
	detect_bar_height = detect_bar_height,
	detect_dock_width = detect_dock_width,
	default_padding = 8,
	item_padding = {
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
