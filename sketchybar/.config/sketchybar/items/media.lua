-- ========== 当前播放媒体 ==========
-- 有 NowPlaying 信息时显示 ♪，点击 popup 显示歌曲详情 + 控制按钮
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

-- ========== Bar 条目：播放图标 ==========
local media = sbar.add("item", "widgets.media", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	drawing = false,
	updates = true,
	update_freq = 5,
	icon = {
		string = "▶",
		font = {
			family = fonts.font_fira.text,
			style = fonts.font_fira.style_map["Bold"],
			size = 16.0,
		},
		padding_left = 10,
		padding_right = 10,
		color = colors.active.red,
	},
	label = { drawing = false },
	background = {
		image = {
			string = "media.artwork",
			scale = 1.0,
			drawing = false,
		},
		color = colors.active.bar_bg,
		corner_radius = 10,
		border_color = colors.active.red,
		border_width = 2,
	},
	popup = {
		align = "center",
		horizontal = true,
		background = {
			color = colors.with_alpha(colors.active.bar_bg, 0.85),
			corner_radius = 12,
			border_width = 0,
			shadow = { drawing = true },
		},
		blur_radius = 30,
	},
})

-- ========== 轮询脚本 ==========
sbar.exec('sketchybar --set widgets.media script="$CONFIG_DIR/helpers/media_query.sh"')

-- ========== Popup：歌曲信息 ==========

sbar.add("item", "media.title", {
	position = "popup." .. media.name,
	icon = { drawing = false },
	label = {
		string = "",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = 14.0,
		},
		color = colors.active.text,
		max_chars = 25,
		padding_left = 12,
		padding_right = 4,
	},
	background = { drawing = false },
})

sbar.add("item", "media.artist_album", {
	position = "popup." .. media.name,
	icon = { drawing = false },
	label = {
		string = "",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Regular"],
			size = 12.0,
		},
		color = colors.active.subtext0,
		max_chars = 35,
		padding_left = 0,
		padding_right = 4,
	},
	background = { drawing = false },
})

-- ========== Popup：控制按钮 ==========

sbar.add("item", "media.prev", {
	position = "popup." .. media.name,
	icon = {
		string = icons.media.back,
		font = {
			family = fonts.font_icon.text,
			style = "Regular",
			size = 18.0,
		},
		padding_left = 8,
		padding_right = 8,
		color = colors.active.subtext0,
		highlight_color = colors.active.text,
	},
	label = { drawing = false },
	background = { drawing = false },
	click_script = "nowplaying-cli previous",
})

sbar.add("item", "media.play_pause", {
	position = "popup." .. media.name,
	icon = {
		string = icons.media.play_pause,
		font = {
			family = fonts.font_icon.text,
			style = "Regular",
			size = 18.0,
		},
		padding_left = 8,
		padding_right = 8,
		color = colors.active.subtext0,
		highlight_color = colors.active.text,
	},
	label = { drawing = false },
	background = { drawing = false },
	click_script = "nowplaying-cli togglePlayPause",
})

sbar.add("item", "media.next", {
	position = "popup." .. media.name,
	icon = {
		string = icons.media.forward,
		font = {
			family = fonts.font_icon.text,
			style = "Regular",
			size = 18.0,
		},
		padding_left = 8,
		padding_right = 12,
		color = colors.active.subtext0,
		highlight_color = colors.active.text,
	},
	label = { drawing = false },
	background = { drawing = false },
	click_script = "nowplaying-cli next",
})

-- ========== 事件处理 ==========

media:subscribe("mouse.clicked", function()
	sbar.exec("nowplaying-cli get title", function(title)
		title = title and title:match("^%s*(.-)%s*$") or ""
		if title == "null" then title = "" end
		sbar.set("media.title", { label = { string = title } })
	end)
	sbar.exec("nowplaying-cli get artist", function(artist)
		artist = artist and artist:match("^%s*(.-)%s*$") or ""
		if artist == "null" then artist = "" end
		sbar.exec("nowplaying-cli get album", function(album)
			album = album and album:match("^%s*(.-)%s*$") or ""
			if album == "null" then album = "" end
			local str = ""
			if #artist > 0 and #album > 0 then
				str = artist .. " · " .. album
			elseif #artist > 0 then
				str = artist
			elseif #album > 0 then
				str = album
			end
			sbar.set("media.artist_album", { label = { string = str } })
		end)
	end)
	media:set({ popup = { drawing = "toggle" } })
end)

media:subscribe("mouse.exited.global", function()
	media:set({ popup = { drawing = false } })
end)

media:subscribe("system_woke", function()
	sbar.trigger("media_change")
end)
