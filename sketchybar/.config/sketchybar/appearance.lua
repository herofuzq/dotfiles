-- ========== 外观：色板 + 语义化颜色 ==========
-- 可用 scheme：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox（切换见 ⑤ M.scheme）
local M = {}

-- ========== (1) 色板（纯色值，无 alpha）==========
local palette = {
	mocha = {
		rosewater = 0xfff5e0dc,
		flamingo = 0xfff2cdcd,
		pink = 0xfff5c2e7,
		mauve = 0xffcba6f7,
		red = 0xfff38ba8,
		maroon = 0xffeba0ac,
		peach = 0xfffab387,
		yellow = 0xfff9e2af,
		green = 0xffa6e3a1,
		teal = 0xff94e2d5,
		sky = 0xff89dceb,
		sapphire = 0xff74c7ec,
		blue = 0xff89b4fa,
		lavender = 0xffb4befe,
		text = 0xffcdd6f4,
		subtext1 = 0xffbac2de,
		subtext0 = 0xffa6adc8,
		overlay2 = 0xff9399b2,
		overlay1 = 0xff7f849c,
		overlay0 = 0xff6c7086,
		surface2 = 0xff585b70,
		surface1 = 0xff45475a,
		surface0 = 0xff313244,
		base = 0xff1e1e2e,
		mantle = 0xff181825,
		crust = 0xff11111b,
	},
	latte = {
		rosewater = 0xffdc8a78,
		flamingo = 0xffdd7878,
		pink = 0xffea76cb,
		mauve = 0xff8839ef,
		red = 0xffd20f39,
		maroon = 0xffe64553,
		peach = 0xfffe640b,
		yellow = 0xffdf8e1d,
		green = 0xff40a02b,
		teal = 0xff179299,
		sky = 0xff04a5e5,
		sapphire = 0xff209fb5,
		blue = 0xff1e66f5,
		lavender = 0xff7287fd,
		text = 0xff4c4f69,
		subtext1 = 0xff5c5f77,
		subtext0 = 0xff6c6f85,
		overlay2 = 0xff7c7f93,
		overlay1 = 0xff8c8fa1,
		overlay0 = 0xff9ca0b0,
		surface2 = 0xffacb0be,
		surface1 = 0xffbcc0cc,
		surface0 = 0xffccd0da,
		base = 0xffeff1f5,
		mantle = 0xffe6e9ef,
		crust = 0xffdce0e8,
	},
	-- Tokyo Night Storm（dark）。官方色：https://github.com/tokyo-night/tokyonight.nvim
	tokyonight_storm = {
		rosewater = 0xfff4dbd6,
		flamingo = 0xffdbb4bc,
		pink = 0xfffbb1f2,
		mauve = 0xffbb9af7, -- magenta
		red = 0xfff7768e,
		maroon = 0xffdb4b4b, -- red1
		peach = 0xffff9e64, -- orange
		yellow = 0xffe0af68,
		green = 0xff9ece6a,
		teal = 0xff73daca,
		sky = 0xffb4f9f8,
		sapphire = 0xff7dcfff, -- cyan
		blue = 0xff7aa2f7,
		lavender = 0xffb4f9f8,
		text = 0xffc0caf5, -- fg
		subtext1 = 0xffa9b1d6, -- fg_dark
		subtext0 = 0xff9aa5ce,
		overlay2 = 0xff737aa2, -- dark5
		overlay1 = 0xff69709a,
		overlay0 = 0xff565f89, -- comment
		surface2 = 0xff414868,
		surface1 = 0xff3b4261, -- fg_gutter
		surface0 = 0xff292e42, -- bg_highlight
		base = 0xff24283b, -- bg
		mantle = 0xff1f2335, -- bg_dark
		crust = 0xff1a1b26, -- bg_dark1
	},
	-- Tokyo Night Day（light）
	tokyonight_day = {
		rosewater = 0xffb46958,
		flamingo = 0xffa4636f,
		pink = 0xffa14dbd,
		mauve = 0xff9854f1, -- magenta
		red = 0xfff52a65,
		maroon = 0xffb63d5c,
		peach = 0xffb15c00, -- orange
		yellow = 0xff8c6c3e,
		green = 0xff587539,
		teal = 0xff118c74,
		sky = 0xff188092,
		sapphire = 0xff007197, -- cyan
		blue = 0xff2e7de9,
		lavender = 0xff5068b5,
		text = 0xff3760bf, -- fg
		subtext1 = 0xff6172b0, -- fg_dark
		subtext0 = 0xff6d78a8,
		overlay2 = 0xff848cb5, -- comment
		overlay1 = 0xffa8aecb, -- fg_gutter
		overlay0 = 0xff9aa3c2,
		surface2 = 0xffaeb3c8,
		surface1 = 0xffb8bdd0,
		surface0 = 0xffc4c8da, -- bg_highlight
		base = 0xffe1e2e7, -- bg
		mantle = 0xffd0d5e3, -- bg_dark
		crust = 0xffb8bdd0,
	},
	-- Rosé Pine main（dark）。官方色：https://github.com/rose-pine/neovim palette.lua
	rosepine = {
		rosewater = 0xffebbcba, -- rose
		flamingo = 0xffebbcba, -- rose（官方无第二浅粉）
		pink = 0xffeb6f92, -- love
		mauve = 0xffc4a7e7, -- iris
		red = 0xffeb6f92, -- love
		maroon = 0xffebbcba, -- rose（官方无深红，取 rose）
		peach = 0xfff6c177, -- gold（官方无橙，gold 为暖金橙）
		yellow = 0xfff6c177, -- gold
		green = 0xff95b1ac, -- leaf
		teal = 0xff9ccfd8, -- foam
		sky = 0xff9ccfd8, -- foam
		sapphire = 0xff31748f, -- pine（青蓝）
		blue = 0xff31748f, -- pine（官方无纯蓝）
		lavender = 0xffc4a7e7, -- iris
		text = 0xffe0def4, -- text
		subtext1 = 0xff908caa, -- subtle
		subtext0 = 0xff6e6a86, -- muted
		overlay2 = 0xff908caa, -- subtle（与 subtext1 同源）
		overlay1 = 0xff6e6a86, -- muted
		overlay0 = 0xff524f67, -- highlight_high
		surface2 = 0xff524f67, -- highlight_high
		surface1 = 0xff403d52, -- highlight_med
		surface0 = 0xff26233a, -- overlay
		base = 0xff191724, -- base
		mantle = 0xff16141f, -- _nc
		crust = 0xff16141f, -- _nc（官方最深档，与 mantle 同源）
	},
	-- Rosé Pine Dawn（light）
	rosepine_dawn = {
		rosewater = 0xffd7827e, -- rose
		flamingo = 0xffd7827e, -- rose（官方无第二浅粉）
		pink = 0xffb4637a, -- love
		mauve = 0xff907aa9, -- iris
		red = 0xffb4637a, -- love
		maroon = 0xffd7827e, -- rose（官方无深红，取 rose）
		peach = 0xffea9d34, -- gold（官方无橙，gold 为暖金橙）
		yellow = 0xffea9d34, -- gold
		green = 0xff6d8f89, -- leaf
		teal = 0xff56949f, -- foam
		sky = 0xff56949f, -- foam
		sapphire = 0xff286983, -- pine（青蓝）
		blue = 0xff286983, -- pine（官方无纯蓝）
		lavender = 0xff907aa9, -- iris
		text = 0xff464261, -- text（深中性色）
		subtext1 = 0xff797593, -- subtle
		subtext0 = 0xff9893a5, -- muted
		overlay2 = 0xff9893a5, -- muted（与 subtext0 同源）
		overlay1 = 0xffcecacd, -- highlight_high
		overlay0 = 0xffdfdad9, -- highlight_med
		surface2 = 0xffcecacd, -- highlight_high
		surface1 = 0xffdfdad9, -- highlight_med
		surface0 = 0xfff2e9e1, -- overlay（比 base 略深）
		base = 0xfffaf4ed, -- base
		mantle = 0xfff8f0e7, -- _nc
		crust = 0xfff4ede8, -- highlight_low
	},
	-- Everforest dark medium。官方色：https://github.com/sainnhe/everforest autoload/everforest.vim
	everforest_dark = {
		rosewater = 0xffe69875, -- orange（近似浅粉玫瑰）
		flamingo = 0xffe67e80, -- red（近似浅粉）
		pink = 0xffd699b6, -- purple（官方无粉，purple 最近）
		mauve = 0xffd699b6, -- purple
		red = 0xffe67e80,
		maroon = 0xffe67e80, -- red（官方无深红档）
		peach = 0xffe69875, -- orange
		yellow = 0xffdbbc7f,
		green = 0xffa7c080,
		teal = 0xff83c092, -- aqua
		sky = 0xff7fbbb3, -- blue（偏青，近似浅青）
		sapphire = 0xff7fbbb3, -- blue（青蓝）
		blue = 0xff7fbbb3, -- blue
		lavender = 0xffd699b6, -- purple（近似浅蓝紫）
		text = 0xffd3c6aa, -- fg
		subtext1 = 0xff9da9a0, -- grey2
		subtext0 = 0xff859289, -- grey1
		overlay2 = 0xff7a8478, -- grey0
		overlay1 = 0xff56635f, -- bg5
		overlay0 = 0xff4f585e, -- bg4
		surface2 = 0xff475258, -- bg3
		surface1 = 0xff3d484d, -- bg2
		surface0 = 0xff343f44, -- bg1
		base = 0xff2d353b, -- bg0
		mantle = 0xff232a2e, -- bg_dim
		crust = 0xff232a2e, -- bg_dim（medium 仅一档更深，与 mantle 同源）
	},
	-- Everforest light medium
	everforest_light = {
		rosewater = 0xfff57d26, -- orange（近似浅粉玫瑰）
		flamingo = 0xfff85552, -- red（近似浅粉）
		pink = 0xffdf69ba, -- purple（官方无粉，purple 最近）
		mauve = 0xffdf69ba, -- purple
		red = 0xfff85552,
		maroon = 0xfff85552, -- red（官方无深红档）
		peach = 0xfff57d26, -- orange
		yellow = 0xffdfa000,
		green = 0xff8da101,
		teal = 0xff35a77c, -- aqua
		sky = 0xff3a94c5, -- blue（近似浅青）
		sapphire = 0xff3a94c5, -- blue（青蓝）
		blue = 0xff3a94c5, -- blue
		lavender = 0xffdf69ba, -- purple（近似浅蓝紫）
		text = 0xff5c6a72, -- fg（深中性灰绿）
		subtext1 = 0xff829181, -- grey2
		subtext0 = 0xff939f91, -- grey1
		overlay2 = 0xffa6b0a0, -- grey0
		overlay1 = 0xffbdc3af, -- bg5
		overlay0 = 0xffbdc3af, -- bg5（与 overlay1 同源，light 档灰色有限）
		surface2 = 0xffe0dcc7, -- bg4
		surface1 = 0xffe6e2cc, -- bg3
		surface0 = 0xffefebd4, -- bg2（比 base 略深；medium 档 bg_dim 与 bg2 同值）
		base = 0xfffdf6e3, -- bg0
		mantle = 0xfff4f0d9, -- bg1
		crust = 0xffefebd4, -- bg_dim
	},
	-- Kanagawa wave（dark）。官方色：https://github.com/rebelot/kanagawa.nvim colors.lua + themes.lua
	kanagawa_wave = {
		rosewater = 0xffd27e99, -- sakuraPink（近似浅粉玫瑰）
		flamingo = 0xffe46876, -- waveRed（近似浅粉）
		pink = 0xffd27e99, -- sakuraPink
		mauve = 0xff957fb8, -- oniViolet
		red = 0xffe46876, -- waveRed
		maroon = 0xffc34043, -- autumnRed
		peach = 0xffffa066, -- surimiOrange
		yellow = 0xffe6c384, -- carpYellow
		green = 0xff98bb6c, -- springGreen
		teal = 0xff7aa89f, -- waveAqua2
		sky = 0xffa3d4d5, -- lightBlue
		sapphire = 0xff7fb4ca, -- springBlue（青蓝）
		blue = 0xff7e9cd8, -- crystalBlue
		lavender = 0xffb8b4d0, -- oniViolet2
		text = 0xffdcd7ba, -- fujiWhite（fg）
		subtext1 = 0xffc8c093, -- oldWhite（fg_dim）
		subtext0 = 0xff727169, -- fujiGray（comment）
		overlay2 = 0xff938aa9, -- springViolet1（special）
		overlay1 = 0xff717c7c, -- katanaGray
		overlay0 = 0xff727169, -- fujiGray（边框用 comment 灰）
		surface2 = 0xff54546d, -- sumiInk6（nontext）
		surface1 = 0xff363646, -- sumiInk5（bg_p2）
		surface0 = 0xff2a2a37, -- sumiInk4（bg_p1）
		base = 0xff1f1f28, -- sumiInk3（bg）
		mantle = 0xff181820, -- sumiInk1（bg_dim）
		crust = 0xff16161d, -- sumiInk0（bg_m3）
	},
	-- Kanagawa lotus（light）
	kanagawa_lotus = {
		rosewater = 0xffd9a594, -- lotusRed4（近似浅粉玫瑰）
		flamingo = 0xffb35b79, -- lotusPink（近似浅粉）
		pink = 0xffb35b79, -- lotusPink
		mauve = 0xff624c83, -- lotusViolet4
		red = 0xffc84053, -- lotusRed
		maroon = 0xffd7474b, -- lotusRed2
		peach = 0xffcc6d00, -- lotusOrange
		yellow = 0xff77713f, -- lotusYellow
		green = 0xff6f894e, -- lotusGreen
		teal = 0xff597b75, -- lotusAqua
		sky = 0xff6693bf, -- lotusTeal2（近似浅青）
		sapphire = 0xff4e8ca2, -- lotusTeal1（青蓝）
		blue = 0xff4d699b, -- lotusBlue4
		lavender = 0xff766b90, -- lotusViolet2（近似浅蓝紫）
		text = 0xff545464, -- lotusInk1（fg，深中性蓝灰）
		subtext1 = 0xff716e61, -- lotusGray2
		subtext0 = 0xff8a8980, -- lotusGray3（comment）
		overlay2 = 0xffa09cac, -- lotusViolet1（nontext）
		overlay1 = 0xffc9cbd1, -- lotusViolet3
		overlay0 = 0xff8a8980, -- lotusGray3（边框用 comment 灰保证可见）
		surface2 = 0xffdcd7ba, -- lotusGray（fg_reverse）
		surface1 = 0xffe4d794, -- lotusWhite5（bg_p2）
		surface0 = 0xffe7dba0, -- lotusWhite4（bg_p1，比 base 略深）
		base = 0xfff2ecbc, -- lotusWhite3（bg）
		mantle = 0xffdcd5ac, -- lotusWhite1（bg_dim）
		crust = 0xffd5cea3, -- lotusWhite0（bg_m3）
	},
	-- Gruvbox dark medium。官方色：https://github.com/ellisonleao/gruvbox.nvim lua/gruvbox.lua palette
	gruvbox_dark = {
		rosewater = 0xffd3869b, -- bright_purple（近似浅粉玫瑰）
		flamingo = 0xfffb4934, -- bright_red（近似浅粉）
		pink = 0xffd3869b, -- bright_purple（官方无粉色）
		mauve = 0xffd3869b, -- bright_purple
		red = 0xfffb4934, -- bright_red
		maroon = 0xffcc241d, -- neutral_red
		peach = 0xfffe8019, -- bright_orange
		yellow = 0xfffabd2f, -- bright_yellow
		green = 0xffb8bb26, -- bright_green
		teal = 0xff8ec07c, -- bright_aqua
		sky = 0xff83a598, -- bright_blue（偏青，近似浅青）
		sapphire = 0xff458588, -- neutral_blue（官方无 sapphire，取青蓝系）
		blue = 0xff83a598, -- bright_blue
		lavender = 0xffd3869b, -- bright_purple（近似浅蓝紫）
		text = 0xffebdbb2, -- fg1（light1）
		subtext1 = 0xffd5c4a1, -- fg2（light2）
		subtext0 = 0xffbdae93, -- fg3（light3）
		overlay2 = 0xffa89984, -- fg4（light4）
		overlay1 = 0xff928374, -- gray
		overlay0 = 0xff7c6f64, -- dark4
		surface2 = 0xff665c54, -- dark3
		surface1 = 0xff504945, -- dark2
		surface0 = 0xff3c3836, -- dark1
		base = 0xff282828, -- dark0
		mantle = 0xff1d2021, -- dark0_hard
		crust = 0xff1d2021, -- dark0_hard（官方最深档，与 mantle 同源）
	},
	-- Gruvbox light medium
	gruvbox_light = {
		rosewater = 0xffb16286, -- neutral_purple（近似浅粉玫瑰）
		flamingo = 0xffcc241d, -- neutral_red（近似浅粉）
		pink = 0xffb16286, -- neutral_purple（官方无粉色）
		mauve = 0xff8f3f71, -- faded_purple
		red = 0xff9d0006, -- faded_red
		maroon = 0xffcc241d, -- neutral_red
		peach = 0xffaf3a03, -- faded_orange
		yellow = 0xffb57614, -- faded_yellow
		green = 0xff79740e, -- faded_green
		teal = 0xff427b58, -- faded_aqua
		sky = 0xff689d6a, -- neutral_aqua（近似浅青）
		sapphire = 0xff076678, -- faded_blue（官方无 sapphire，取青蓝系）
		blue = 0xff076678, -- faded_blue
		lavender = 0xffb16286, -- neutral_purple（近似浅蓝紫）
		text = 0xff3c3836, -- fg1（dark1，深中性色）
		subtext1 = 0xff504945, -- fg2（dark2）
		subtext0 = 0xff665c54, -- fg3（dark3）
		overlay2 = 0xff7c6f64, -- fg4（dark4）
		overlay1 = 0xff928374, -- gray
		overlay0 = 0xffa89984, -- light4
		surface2 = 0xffbdae93, -- light3
		surface1 = 0xffd5c4a1, -- light2
		surface0 = 0xffebdbb2, -- light1（比 base 略深）
		base = 0xfffbf1c7, -- light0
		mantle = 0xfff9f5d7, -- light0_hard（比 base 略深）
		crust = 0xfff2e5bc, -- light0_soft
	},
}

-- ========== (1.1) 色系（scheme）：每套含 dark/light 两个 flavor ==========
-- 切换色系：改 M.scheme（见下方 ⑤）+ sketchybar --reload。深浅仍跟随系统。
-- 可用：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox
local schemes = {
	catppuccin = { dark = "mocha", light = "latte", window_border = "mauve" },
	tokyonight = { dark = "tokyonight_storm", light = "tokyonight_day", window_border = "blue" },
	rosepine = { dark = "rosepine", light = "rosepine_dawn", window_border = "rosewater" },
	everforest = { dark = "everforest_dark", light = "everforest_light", window_border = "green" },
	kanagawa = { dark = "kanagawa_wave", light = "kanagawa_lotus", window_border = "blue" },
	gruvbox = { dark = "gruvbox_dark", light = "gruvbox_light", window_border = "peach" },
}
local scheme_names = {
	"catppuccin",
	"tokyonight",
	"rosepine",
	"everforest",
	"kanagawa",
	"gruvbox",
}

-- ========== (2) 工具函数（需在 build_colors 之前定义）==========
function M.with_alpha(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then
		return color
	end
	return (color & 0x00ffffff) | (math.floor(alpha * 255) * 0x1000000)
end

-- ========== (3) alpha 常量 ==========
local A = {
	bar_bg = 0.2, -- bar 本体透明度
	pill = 0.667, -- pill 背景 (0xaa/255)
	border = 0.2, -- 边框 / 高亮 (0x33/255)
}

-- ========== (4) 构建实际颜色表（含 alpha）==========
-- 三层语义：中性色（顶层）+ status（状态语义）+ identity（widget 固定强调色登记表）。
-- widget 只许引用 colors.status.* / colors.identity.* / 中性色，禁止裸引用色板色。
local function build_colors(P, window_border_role)
	local theme_accent = P[window_border_role or "mauve"]
	return {
		pill_bg = M.with_alpha(P.surface0, A.pill), -- surface0 @ 0.667
		pill_fg = P.text,
		bar_bg = M.with_alpha(P.crust, A.bar_bg),
		-- dim: 历史命名，当前与 pill_bg 同值，不是「弱前景色」。
		-- install_defaults 用它当默认 icon.color；widget 应显式设自己的颜色。
		dim = M.with_alpha(P.surface0, A.pill),
		border = M.with_alpha(P.overlay0, A.border),
		highlight = M.with_alpha(P.mauve, A.border),
		mauve = P.mauve,
		red = P.red,
		green = P.green,
		peach = P.peach,
		yellow = P.yellow,
		sapphire = P.sapphire,
		blue = P.blue,
		text = P.text,
		subtext1 = P.subtext1,
		surface1 = P.surface1,
		overlay0 = P.overlay0,
		overlay1 = P.overlay1,
		crust = P.crust,
		-- 按压反馈色（apple 图标、media 按钮共用）
		press = P.yellow,
		-- 各类计数统一色（docker/git/wechat/dingtalk，沿用 dingtalk 计数原有色）；
		-- 无消息/零值用 pill_fg，error 仍由 status.error 承担
		count = P.peach,
		-- 状态语义色：电量/CPU/网络/git/docker/clash 等状态驱动场景专用
		status = {
			ok = P.green, -- 正常 / 开 / 全部运行
			error = P.red, -- 异常 / 关 / 离线 / 低电
			warn = P.yellow, -- 注意：git dirty、docker 部分运行、暂停、操作进行中
			caution = P.peach, -- 中档警告：电量/CPU 中间档
		},
		-- 身份色登记表：两级制——内容型 widget 保留强调色，状态型常规态回归中性色
		-- （颜色 = 信号：只有状态变化才上色，由 colors.status.* 承担）
		identity = {
			apple = theme_accent, -- 与 FrontApp / jankyborders 共用主题代表色
			front_app = theme_accent,
			music_icon = P.peach, -- 内容主角固定强调色
			music_text = P.text, -- 原 yellow，收敛为中性
			sys_icon = P.text,
			sys_info = P.subtext1, -- sys popup 提示文字
			calendar_month = P.text,
			input_default = P.text,
			input_a = P.text,
			input_zh = P.green, -- 微信键盘（WeType）：品牌绿，一眼可辨
			input_ch = P.text,
			input_en = P.text,
			network = P.sapphire, -- 常态连接也有信号色（与 clash 活跃态一致）
			network_hotspot = P.mauve, -- 热点是"状态"，保留信号色
			clash_all = P.mauve, -- 全局模式（活跃状态，信号色）
			clash_sys = P.sapphire, -- 系统代理（活跃状态，信号色）
			spaces_mode = P.text, -- aerospace 指示器保持中性
			spaces_ws = P.text, -- workspace 编号保持中性
			spaces_service = P.text, -- service mode 指示器保持中性
			spaces_win_highlight = P.red, -- 窗口标题高亮（信号色）
			window_border = theme_accent, -- jankyborders 当前窗口外框
		},
	}
end

-- ========== (5) 切换 ==========
-- 色系配置：catppuccin / tokyonight / rosepine / everforest / kanagawa / gruvbox（定义见 1.1 schemes 表）。
-- flavor 统一用 "dark"/"light" 表示，具体色板由 scheme 映射决定。
M.default_scheme = "gruvbox"
M.scheme_names = scheme_names

function M.parse_scheme_state(content)
	if type(content) ~= "string" then
		return nil
	end
	for line in content:gmatch("[^\r\n]+") do
		local name = line:match("^%s*scheme%s*=%s*([%w_-]+)%s*$")
		if name then
			return schemes[name] and name or nil
		end
	end
	return nil
end

function M.scheme_state_path()
	local home = os.getenv("HOME")
	return home and (home .. "/.local/state/dotfiles/theme_scheme") or nil
end

function M.read_scheme_state(path)
	path = path or M.scheme_state_path()
	if not path then
		return nil, "HOME unavailable"
	end
	local file, open_error = io.open(path, "r")
	if not file then
		local message = tostring(open_error)
		if message:find("No such file or directory", 1, true) then
			return nil, "missing"
		end
		return nil, "unreadable: " .. message
	end
	local content = file:read("*a")
	file:close()
	local scheme = M.parse_scheme_state(content)
	if not scheme then
		return nil, "invalid"
	end
	return scheme
end

local stored_scheme, stored_scheme_error = M.read_scheme_state()
if stored_scheme_error == "invalid" then
	print("[theme] invalid scheme state, using " .. M.default_scheme)
elseif stored_scheme_error ~= nil and stored_scheme_error ~= "missing" then
	print("[theme] unable to read scheme state: " .. stored_scheme_error)
end
M.scheme = stored_scheme or M.default_scheme

local function flavor_palette(flavor)
	local scheme = schemes[M.scheme] or schemes[M.default_scheme]
	return palette[scheme[flavor]]
end

local function build_theme_colors(flavor)
	local scheme = schemes[M.scheme] or schemes[M.default_scheme]
	return build_colors(palette[scheme[flavor]], scheme.window_border)
end

-- defaults read -g AppleInterfaceStyle：stdout 首行 "Dark" = 深色；
-- 键不存在（浅色）时命令失败、stdout 为空。
function M.parse_apple_interface_style(output)
	return output == "Dark" and "dark" or "light"
end

-- 启动同步检测：必须在做任何颜色决策前完成（io.popen 一次，<100ms）。
-- 失败按浅色处理（与 macOS 键不存在语义一致）。
function M.detect_system_theme_sync()
	local ok, style = pcall(function()
		local f = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
		local line = f and f:read("*l") or nil
		if f then
			f:close()
		end
		return line
	end)
	return M.parse_apple_interface_style(ok and style or nil)
end

-- 配置加载即确定主题：appearance 在 begin_config 前被首次 require，
-- 浅色系统 reload 不会先显示深色 flavor 再切浅色。
M.active = M.detect_system_theme_sync()
M.colors = build_theme_colors(M.active)
-- 导出供测试与主题切换使用
M.palette = palette
M.schemes = schemes
M.build_colors = build_colors
M.flavor_palette = flavor_palette

-- ========== (5.1) 原地更新 + 注册表热换色 ==========
-- M.colors 表对象终身不变：9+ 个模块缓存了 local colors = appearance.colors，
-- 直接换表会让旧缓存指向旧色板，状态刷新时写回旧主题色（反弹）。
-- 约束：模块生命周期内禁止缓存标量色值（local red = colors.red 禁止）；
-- 只允许缓存表引用（表内容会被原地更新）。函数体内单次计算不受限。
local function update_table_in_place(target, source)
	for k in pairs(target) do
		if source[k] == nil then
			target[k] = nil
		end
	end
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			update_table_in_place(target[k], v) -- 子表保持引用，递归原地更新
		else
			target[k] = v
		end
	end
end
M.update_table_in_place = update_table_in_place -- 导出供测试

-- 各 owner 注册的"应用颜色"回调：fn(colors) 按模块当前状态重算并 set 颜色。
-- enter_animation 包装了 sbar.set/item:set，回调里的 set 会自动同步 reveal 目标色。
local appliers = {}
function M.register_colors(name, fn)
	appliers[name] = fn
end

-- 已注册 owner 名单（测试用，防旧架构式名单漂移）
function M.registered_names()
	local list = {}
	for name in pairs(appliers) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

local function apply_current_colors()
	update_table_in_place(M.colors, build_theme_colors(M.active))
	local sbar = require("sketchybar")
	local timing = require("helpers.timing")
	sbar.animate("linear", timing.THEME_SWITCH_FRAMES, function()
		for _, fn in pairs(appliers) do
			fn(M.colors)
		end
	end)
end

-- 热切换深浅 flavor：原地更新 M.colors 后遍历注册表重涂，不 reload。
function M.switch_theme(theme)
	if (theme ~= "dark" and theme ~= "light") or theme == M.active then
		return false
	end
	M.active = theme
	apply_current_colors()
	return true
end

-- 热切换色系；深浅 flavor 保持不变，仍由 macOS 外观状态决定。
function M.switch_scheme(scheme)
	if not schemes[scheme] or scheme == M.scheme then
		return false
	end
	M.scheme = scheme
	apply_current_colors()
	return true
end

-- bar 本体也是 owner：切换时重涂 bar_bg。
-- 注意：这里只注册、不在配置期调用——配置期 bar 由 bar.lua 保持全透明，
-- 启动 reveal 时 startup/enter_animation 会现读 appearance.colors.bar_bg 上色。
M.register_colors("appearance.core", function(C)
	require("sketchybar").bar({ color = C.bar_bg })
end)

-- ========== (6) 样式 helpers ==========
-- 所有 widget 复用的标准样式，避免每个文件重抄。
-- 改全局圆角/边框/font size 时只改这里。
local fonts = require("fonts")

-- 标准 pill 背景（widget 和 bracket 都用）。
-- 用法: sbar.add("item", "widgets.battery", { background = appearance.pill_bg(), ... })
function M.pill_bg()
	return {
		color = M.colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = M.colors.border,
	}
end

-- 标准 popup 背景。统一 alpha 0.85 / 圆角 12 / 边框 2，
-- 避免各 widget 散落不同的 alpha/圆角值。
-- 用法: popup = { background = appearance.popup_bg(), ... }
function M.popup_bg()
	return {
		color = M.with_alpha(M.colors.pill_bg, 0.85),
		corner_radius = 12,
		border_width = 2,
		border_color = M.colors.border,
		shadow = { drawing = false },
	}
end

-- 标准 icon 字体（Bold），size 可选，默认用 fonts.font_icon.size。
-- 用法: icon = { ..., font = appearance.font_icon_bold() }
function M.font_icon_bold(size)
	return {
		family = fonts.font_icon.text,
		style = fonts.font_icon.style_map["Bold"],
		size = size or fonts.font_icon.size,
	}
end

-- 标准 label 字体（Bold），size 可选，默认用 fonts.font.size。
-- 用法: label = { ..., font = appearance.font_label_bold() }
function M.font_label_bold(size)
	return {
		family = fonts.font.text,
		style = fonts.font.style_map["Bold"],
		size = size or fonts.font.size,
	}
end

-- ========== (7) 全局默认样式 ==========
function M.install_defaults()
	local C = M.colors
	local settings = require("settings")
	local fonts = require("fonts")
	local sbar = require("sketchybar")

	sbar.default({
		background = {
			border_color = C.subtext1,
			border_width = 2,
			color = C.pill_bg,
			corner_radius = 9,
			height = settings.height - 4,
			image = {
				corner_radius = 0,
				border_color = C.text,
				border_width = 1,
			},
		},
		icon = {
			font = {
				family = fonts.font_icon.text,
				style = fonts.font_icon.style_map["Bold"],
				size = fonts.font_icon.size,
			},
			color = C.dim,
			highlight_color = C.highlight,
			padding_left = 0,
			padding_right = 0,
		},
		label = {
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Semibold"],
				size = fonts.font.size,
			},
			color = C.dim,
			padding_left = settings.default_padding,
			padding_right = settings.default_padding,
		},
		popup = {
			align = "center",
			background = {
				border_width = 0,
				corner_radius = 6,
				color = C.pill_bg,
				shadow = { drawing = true },
			},
			blur_radius = 50,
			y_offset = 2,
		},
		padding_left = 0,
		blur_radius = 0,
		padding_right = 0,
		scroll_texts = true,
		shadow = "off",
		updates = "on",
	})
end

return M
