-- ========== 媒体控制（歌名 + 下一首 + 播放/暂停 按钮）==========
-- 布局完全照抄 network.lua：每个 item padding_left/right=2，
-- bracket background.padding_left/right=2/10，让 bracket pill 的右边自然对齐。
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors

local MEDIA = "/opt/homebrew/bin/media-control"

-- Nerd Font 媒体控制图标
local ICON_PLAY = "\u{f04b}"
local ICON_PAUSE = "\u{f04c}"
local ICON_NEXT = "\u{f051}"
local ICON_MUSIC = "\u{f001}"

-- sbar.exec 回调：JSON 输出自动解析成 Lua table（无需手动 parse）
-- 无播放时 media-control get 输出 JSON null，回调拿到 nil
local function refresh()
	sbar.exec(MEDIA .. " get 2>/dev/null", function(info)
		local title, artist, album, playing
		if info == nil then
			title, artist, album, playing = "", "", "", false
		else
			title = info.title or ""
			artist = info.artist or ""
			album = info.album or ""
			playing = info.playing or false
		end

		local display
		if title == "" and artist == "" and album == "" then
			display = "未播放"
		else
			local parts = {}
			if title ~= "" then
				parts[#parts + 1] = title
			end
			if artist ~= "" then
				parts[#parts + 1] = artist
			end
			if album ~= "" then
				parts[#parts + 1] = album
			end
			display = table.concat(parts, " - ")
		end

		sbar.set("widgets.media_label", { label = { string = display } })
		sbar.set("widgets.media_play_pause", {
			icon = { string = playing and ICON_PAUSE or ICON_PLAY },
		})
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
		color = colors.active.sep_opaque,
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
		color = colors.active.sep_opaque,
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
	sbar.exec(MEDIA .. " next-track && " .. MEDIA .. " get", function(info)
		if type(info) ~= "table" then return end
		local title = info.title or ""
		local artist = info.artist or ""
		local album = info.album or ""
		local playing = info.playing or false

		local parts = {}
		if title ~= "" then parts[#parts + 1] = title end
		if artist ~= "" then parts[#parts + 1] = artist end
		if album ~= "" then parts[#parts + 1] = album end
		local display = #parts > 0 and table.concat(parts, " - ") or "未播放"

		sbar.set("widgets.media_label", { label = { string = display } })
		sbar.set("widgets.media_play_pause", {
			icon = { string = playing and ICON_PAUSE or ICON_PLAY },
		})
	end)
end)

play_pause:subscribe("mouse.clicked", function()
	local cur = play_pause:query().icon.value
	play_pause:set({ icon = { string = (cur == ICON_PLAY) and ICON_PAUSE or ICON_PLAY } })
	sbar.exec(MEDIA .. " toggle-play-pause")
end)

-- ========== 歌曲信息 ==========
local label = sbar.add("item", "widgets.media_label", {
	position = "right",
	update_freq = 3,
	scroll_texts = "on",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = ICON_MUSIC,
		font = { family = fonts.font_icon.text, style = fonts.font_icon.style_map["Bold"], size = 11.0 },
		color = colors.active.peach,
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
		color = colors.active.yellow,
		padding_left = 2,
		padding_right = 6,
		max_chars = 8,
		align = "left",
	},
	background = { drawing = false },
})

label:subscribe("media_update", refresh)
label:subscribe("routine", refresh)
