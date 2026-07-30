return {
	-- 经典 Gruvbox；dark/light 变体跟随 vim.o.background
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		opts = {},
	},
	-- 覆盖 LazyVim 默认 colorscheme（tokyonight）
	{
		"LazyVim/LazyVim",
		opts = { colorscheme = "gruvbox" },
	},
	-- 跟随 macOS 系统明暗外观，自动翻转 background 并重应用主题
	{
		"f-person/auto-dark-mode.nvim",
		opts = {
			update_interval = 3000,
			set_dark_mode = function()
				vim.o.background = "dark"
				vim.cmd("colorscheme gruvbox")
			end,
			set_light_mode = function()
				vim.o.background = "light"
				vim.cmd("colorscheme gruvbox")
			end,
		},
	},
}
