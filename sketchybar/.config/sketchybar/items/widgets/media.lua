-- ========== 媒体控制（歌名 + 上一首 + 播放/暂停 + 下一首）==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local appearance = require("appearance")
local enter_animation = require("helpers.enter_animation")
local colors = appearance.colors

local function find_media()
	for _, p in ipairs({ "/opt/homebrew/bin/media-control", "/usr/local/bin/media-control" }) do
		local f = io.open(p, "r")
		if f then
			f:close()
			return p
		end
	end
	return "/opt/homebrew/bin/media-control"
end
local MEDIA = find_media()

-- Nerd Font 媒体控制图标
local ICON_PLAY = "\u{f04b}"
local ICON_PAUSE = "\u{f04c}"
local ICON_PREVIOUS = "\u{f048}"
local ICON_NEXT = "\u{f051}"
local ICON_MUSIC = "\u{f001}"

local skip_icon = 0
local label
local last_display_title
local last_playing
local title_generation = 0
local title_initialized = false

local function display_title(info)
	local title = (info and info.title) or ""
	local artist = (info and info.artist) or ""
	local album = (info and info.album) or ""
	if title == "" and artist == "" and album == "" then
		return "未播放"
	end

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
	return table.concat(parts, " - ")
end

local function update_label(info, animated)
	local title = display_title(info)
	if last_display_title == title then
		return
	end
	last_display_title = title
	if not label then
		return
	end
	if not title_initialized or not animated then
		title_initialized = true
		label:set({ label = { string = title, color = colors.yellow, y_offset = 0 } })
		return
	end

	title_generation = title_generation + 1
	local generation = title_generation
	-- @120Hz: out=133ms, in=200ms
	sbar.animate("tanh", 16, function()
		label:set({ label = { color = appearance.with_alpha(colors.yellow, 0), y_offset = -2 } })
	end)
	sbar.delay(16 / 120, function()
		if title_generation ~= generation then
			return
		end
		sbar.animate("tanh", 24, function()
			label:set({ label = { string = title, color = colors.yellow, y_offset = 0 } })
		end)
	end)
end

local function refresh()
	sbar.exec('"' .. MEDIA .. '" get 2>/dev/null', function(info)
		update_label(info, true)
		local playing = info and info.playing or false
		if skip_icon > 0 then
			skip_icon = skip_icon - 1
		elseif playing ~= last_playing then
			-- dedup: 播放状态没变就不 set
			last_playing = playing
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

-- ========== 上一首 ==========
local previous_item = sbar.add("item", "widgets.media_previous", {
	position = "right",
	padding_left = 2,
	padding_right = 2,
	width = 12,
	icon = {
		string = ICON_PREVIOUS,
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

local function press_feedback(item)
	-- 反馈类:保持短,@120Hz 下 6 帧 = 50ms,跟手
	sbar.animate("tanh", 6, function()
		item:set({ y_offset = -2 })
		item:set({ y_offset = 0 })
	end)
end

-- 按钮按下立即切换图标，消除 shell click_script 的延迟
next_item:subscribe("mouse.clicked", function()
	press_feedback(next_item)
	sbar.exec('"' .. MEDIA .. '" next-track', function()
		sbar.trigger("media_update")
	end)
end)

previous_item:subscribe("mouse.clicked", function()
	press_feedback(previous_item)
	sbar.exec('"' .. MEDIA .. '" previous-track', function()
		sbar.trigger("media_update")
	end)
end)

play_pause:subscribe("mouse.clicked", function()
	press_feedback(play_pause)
	skip_icon = 1
	local q = play_pause:query()
	local cur = q and q.icon and q.icon.value or ICON_PLAY
	play_pause:set({ icon = { string = (cur == ICON_PLAY) and ICON_PAUSE or ICON_PLAY } })
	sbar.exec('"' .. MEDIA .. '" toggle-play-pause')
end)

-- ========== 歌曲信息 ==========
label = sbar.add("item", "widgets.media_label", {
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
sbar.exec('"' .. MEDIA .. '" get 2>/dev/null', function(info)
	update_label(info, false)
	local playing = info and info.playing or false
	if playing then
		sbar.set("widgets.media_play_pause", { icon = { string = ICON_PAUSE } })
	end
end)

-- media_label 创建时就有默认内容("未播放"+ 图标),drawing 默认 on,
-- 实际是"立即可见"的 item,需要登记走渐入。
-- update_label 第一次调用时不要动 y_offset,留给 enter_animation。
enter_animation.register("widgets.media_label")
enter_animation.register("widgets.media_previous")
enter_animation.register("widgets.media_play_pause")
enter_animation.register("widgets.media_next")
