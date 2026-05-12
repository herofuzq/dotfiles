-- 全局设置：高度、默认边距等
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
