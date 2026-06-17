-- ========== 媒体控制（歌名 + 下一首 + 播放/暂停 按钮）==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local function find_media()
	for _, p in ipairs({ "/opt/homebrew/bin/media-control", "/usr/local/bin/media-control" }) do
		local f = io.open(p, "r")
		if f then f:close(); return p end
	end
	return "/opt/homebrew/bin/media-control"
end
local MEDIA = find_media()

-- Nerd Font 媒体控制图标
local ICON_PLAY = "\u{f04b}"
local ICON_PAUSE = "\u{f04c}"
local ICON_NEXT = "\u{f051}"
local ICON_MUSIC = "\u{f001}"

-- sbar.exec 回调：JSON 输出自动解析成 Lua table（无需手动 parse）
-- 无播放时 media-control get 输出 JSON null，回调拿到 nil
local skip_icon = 0

local function refresh()
	sbar.exec(MEDIA .. " get 2>/dev/null", function(info)
		local playing = info and info.playing or false
		if skip_icon > 0 then
			skip_icon = skip_icon - 1
		else
			sbar.set("widgets.media_play_pause", {
				icon = { string = playing and ICON_PAUSE or ICON_PLAY },
			})
		end
	end)
end

-- ========== 下一首 ==========
local next_item = sbar.add("item", "widgets.media_next", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	width = 12,
	icon = {
		string = ICON_NEXT,
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 14.0 },
		color = colors.pill_fg,
		padding_left = 2,
		padding_right = 2,
		width = 12,
		align = "center",
	},
	label = { drawing = false },
	background = { drawing = false },
})

-- ========== 播放 / 暂停 ==========
local play_pause = sbar.add("item", "widgets.media_play_pause", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	width = 12,
	icon = {
		string = ICON_PLAY,
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 14.0 },
		color = colors.pill_fg,
		padding_left = 2,
		padding_right = 2,
		width = 12,
		align = "center",
	},
	label = { drawing = false },
	background = { drawing = false },
})

-- 按钮按下立即切换图标，消除 shell click_script 的延迟
next_item:subscribe("mouse.clicked", function()
	sbar.exec(MEDIA .. " next-track", function()
		sbar.trigger("media_update")
	end)
end)

play_pause:subscribe("mouse.clicked", function()
	skip_icon = 1
	local cur = play_pause:query().icon.value
	play_pause:set({ icon = { string = (cur == ICON_PLAY) and ICON_PAUSE or ICON_PLAY } })
	sbar.exec(MEDIA .. " toggle-play-pause")
end)

-- ========== 歌曲信息 ==========
local label = sbar.add("item", "widgets.media_label", {
	position = "right",
	scroll_texts = "on",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = ICON_MUSIC,
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 11.0 },
		color = colors.peach,
		padding_left = 6,
		padding_right = 2,
	},
	label = {
		string = "未播放",
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Semibold"],
			size = fonts.font.size,
		},
		color = colors.yellow,
		padding_left = 2,
		padding_right = 6,
		max_chars = 10,
		align = "left",
	},
	background = { drawing = false },
})

label:subscribe("media_update", refresh)

-- 初始查询：reload 后首次显示（不恢复轮询）
sbar.exec(MEDIA .. " get 2>/dev/null", function(info)
	if info then
		local title = info.title or ""
		local artist = info.artist or ""
		local album = info.album or ""
		local display
		if title == "" and artist == "" and album == "" then
			display = "未播放"
		else
			local parts = {}
			if title ~= "" then parts[#parts + 1] = title end
			if artist ~= "" then parts[#parts + 1] = artist end
			if album ~= "" then parts[#parts + 1] = album end
			display = table.concat(parts, " - ")
		end
		sbar.set("widgets.media_label", { label = { string = display } })
	end
	local playing = info and info.playing or false
	if playing then
		sbar.set("widgets.media_play_pause", { icon = { string = ICON_PAUSE } })
	end
end)
