-- 全局设置：高度、默认边距等
return {
	height = 36, -- 菜单栏高度（像素）
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
