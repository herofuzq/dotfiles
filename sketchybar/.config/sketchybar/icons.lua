-- 图标字形定义
-- 主要使用 Apple SF Symbols，部分图标来自 Nerd Font / 标准 Unicode
-- 每个键代表一个图标用途，值是 Unicode 字形码点
local icons = {
	sf_symbols = {
		plus = "􀅼",
		loading = "􀖇",
		apple = "􀣺",     --  Apple logo
		gear = "􀍟",       -- ⚙ 设置
		cpu = "􀫥",        -- CPU 芯片
		clipboard = "􀉄",

		switch = {
			on = "􁏮",
			off = "􁏯",
		},
		volume = {
			_100 = "􀊩",
			_66 = "􀊧",
			_33 = "􀊥",
			_10 = "􀊡",
			_0 = "􀊣",
		},
		battery = {
			_100 = "􀛨",
			_75 = "􀺸",
			_50 = "􀺶",
			_25 = "􀛩",
			_0 = "􀛪",
			charging = "􀢋",  -- 充电中
		},
		wifi = {
			upload = "􀄨",
			download = "􀄩",
			connected = "􀙇",
			disconnected = "􀙈",
			router = "􁓤",
		},
		media = {
			back = "􀊑",        -- ⏮ 上一曲
			forward = "􀊓",     -- ⏭ 下一曲
			play_pause = "􀊇",  -- ▶❙❙ 播放/暂停
		},
		clash = {
			tun = "",         -- 网络代理状态图标
		},
		input_method = {
			keyboard = "⌨",    -- 键盘/输入法
		},
	},
}

return icons.sf_symbols
