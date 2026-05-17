-- 全局设置：高度、默认边距等
-- 注意：paddings 是全局默认边距数值，padding 是 icon+label 组合条目的边距模板子表，两者用途不同
return {
	height = 34,      -- 菜单栏高度（像素）
	paddings = 8,     -- 全局默认内边距
	padding = {
		-- icon + label 组合条目的边距模板
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
