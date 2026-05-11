-- full-border
require("full-border"):setup({
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
})

-- git
th.git = th.git or {}
th.git.modified = ui.Style():fg("blue")
th.git.deleted = ui.Style():fg("red"):bold()
th.git.modified_sign = "M"
th.git.deleted_sign = "D"
require("git"):setup()

-- starship
require("starship"):setup()

-- no-status
require("no-status"):setup()

-- Search Jump
require("searchjump"):setup({
	unmatch_fg = "#b2a496",
	match_str_fg = "#000000",
	match_str_bg = "#73AC3A",
	first_match_str_fg = "#000000",
	first_match_str_bg = "#73AC3A",
	label_fg = "#EADFC8",
	label_bg = "#BA603D",
	only_current = false,
	show_search_in_statusbar = false,
	auto_exit_when_unmatch = false,
	enable_capital_label = true,
	mapdata = require("sjch").data,
	search_patterns = { "%d+.1080p", "第%d+集", "第%d+话", "%.E%d+", "S%d+E%d+" },
})

-- mactag plugin
require("mactag"):setup({
	-- Keys used to add or remove tags
	keys = {
		r = "红色",
		o = "橙色",
		y = "黄色",
		g = "绿色",
		b = "蓝色",
		p = "紫色",
	},
	-- Colors used to display tags
	colors = {
		["红色"] = "#ee7b70",
		["橙色"] = "#f5bd5c",
		["黄色"] = "#fbe764",
		["绿色"] = "#91fc87",
		["蓝色"] = "#5fa3f8",
		["紫色"] = "#cb88f8",
	},
	-- Order of the color circle showing in the line mode
	order = 500,
})
