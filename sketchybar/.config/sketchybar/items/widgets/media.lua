-- ========== 媒体控制（歌名 + 上一首 + 播放/暂停 + 下一首）==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local appearance = require("appearance")
local timing = require("helpers.timing")
local find_binary = require("helpers.find_binary").find
local shell_quote = require("helpers.utils").shell_quote
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("media.status")

-- 找不到则回退 PATH 上的 media-control（避免写死 /opt/homebrew 在 Intel 上指错）
local MEDIA = find_binary(
	{ "/opt/homebrew/bin/media-control", "/usr/local/bin/media-control" },
	"media-control"
)
local function media_exec(args_suffix, callback)
	sbar.exec(shell_quote(MEDIA) .. " " .. args_suffix, callback)
end

-- Only the state query needs a deadline. Control commands retain their normal
-- completion callbacks so a late `next`/`pause` cannot be discarded by a query.
local media_query_generation = 0
local function query_media(callback)
	media_query_generation = media_query_generation + 1
	local generation = media_query_generation
	local finished = false
	local function finish(output)
		if finished or generation ~= media_query_generation then
			return
		end
		finished = true
		callback(output)
	end
	sbar.delay(2, function()
		finish(nil)
	end)
	sbar.exec(shell_quote(MEDIA) .. " get 2>/dev/null", finish)
end

-- Nerd Font 媒体控制图标
local ICON_PLAY = "\u{f04b}"
local ICON_PAUSE = "\u{f04c}"
local ICON_PREVIOUS = "\u{f048}"
local ICON_NEXT = "\u{f051}"
local ICON_MUSIC = "\u{f001}"

local label
local last_display_title
local last_playing
local title_generation = 0
local title_initialized = false
local fallback_refresh_generation = 0

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
		label:set({ label = { string = title, color = colors.yellow } })
		return
	end

	title_generation = title_generation + 1
	local generation = title_generation
	-- 统一规范：纯 alpha 渐隐，linear 曲线，100ms 对称
	sbar.animate("linear", timing.STANDARD_DURATION_FRAMES, function()
		label:set({ label = { color = appearance.with_alpha(colors.yellow, 0) } })
	end)
	sbar.delay(timing.frames_to_seconds(timing.STANDARD_DURATION_FRAMES), function()
		if title_generation ~= generation then
			return
		end
		sbar.animate("linear", timing.STANDARD_DURATION_FRAMES, function()
			label:set({ label = { string = title, color = colors.yellow } })
		end)
	end)
end

local function info_from_env(env)
	if not env or (env.TITLE == nil and env.ARTIST == nil and env.ALBUM == nil and env.PLAYING == nil) then
		return nil
	end
	return {
		title = env.TITLE or "",
		artist = env.ARTIST or "",
		album = env.ALBUM or "",
		playing = env.PLAYING == "1" or env.PLAYING == "true",
	}
end

local function apply_state_now(info, animated)
	update_label(info, animated)
	local playing = info and info.playing or false
	if playing ~= last_playing then
		-- dedup: 播放状态没变就不 set
		last_playing = playing
		sbar.set("widgets.media_play_pause", {
			icon = { string = playing and ICON_PAUSE or ICON_PLAY },
		})
	end
end

local function apply_state(info, animated)
	startup.after_reveal("media.status", function()
		apply_state_now(info, animated)
	end)
end

local function schedule_fallback_refresh()
	fallback_refresh_generation = fallback_refresh_generation + 1
	local generation = fallback_refresh_generation
	for _, delay in ipairs({ 0.6, 1.4 }) do
		sbar.delay(delay, function()
			if fallback_refresh_generation == generation then
				sbar.trigger("media_update")
			end
		end)
	end
end

local function refresh(env)
	-- 总是 bump generation，让之前 schedule 的 fallback refresh 失效。
	-- 之前只在 info 非空时 bump，导致 nil-info 路径可能让旧的 fallback 触发重复 fetch。
	fallback_refresh_generation = fallback_refresh_generation + 1
	local info = info_from_env(env)
	if info then
		apply_state(info, true)
		return
	end
	query_media(function(info)
		apply_state(info, true)
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
		font = appearance.font_icon_bold(14.0),
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
		font = appearance.font_icon_bold(14.0),
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
	width = 14,
	icon = {
		string = ICON_PREVIOUS,
		font = appearance.font_icon_bold(14.0),
		color = colors.pill_fg,
		padding_left = 2,
		padding_right = 2,
		width = 14,
		align = "center",
	},
	label = { drawing = false },
	background = { drawing = false },
})

local function press_feedback(item)
	local frames = math.max(1, math.floor(timing.STANDARD_DURATION_FRAMES / 2))
	sbar.animate("linear", frames, function()
		item:set({ icon = { color = colors.yellow } })
	end)
	sbar.delay(timing.frames_to_seconds(frames), function()
		sbar.animate("linear", frames, function()
			item:set({ icon = { color = colors.pill_fg } })
		end)
	end)
end

-- 按钮按下立即切换图标，消除 shell click_script 的延迟
next_item:subscribe("mouse.clicked", function()
	sbar.delay(0, function() press_feedback(next_item) end)
	media_exec("next-track", function()
		schedule_fallback_refresh()
	end)
end)

previous_item:subscribe("mouse.clicked", function()
	sbar.delay(0, function() press_feedback(previous_item) end)
	media_exec("previous-track", function()
		schedule_fallback_refresh()
	end)
end)

play_pause:subscribe("mouse.clicked", function()
	sbar.delay(0, function()
		press_feedback(play_pause)
		local q = play_pause:query()
		local cur = q and q.icon and q.icon.value or ICON_PLAY
		local optimistic_playing = cur == ICON_PLAY
		-- last_playing 由 apply_state 统一管理，不在此处乐观更新。
		-- 否则 media_update 事件在 toggle 完成前触发时可能用旧状态覆盖乐观值，
		-- 导致 icon 闪回旧图标再切回新图标（肉眼可见 flicker）。
		play_pause:set({ icon = { string = optimistic_playing and ICON_PAUSE or ICON_PLAY } })
	end)
	media_exec("toggle-play-pause", function()
		schedule_fallback_refresh()
	end)
end)

-- ========== 歌曲信息 ==========
label = sbar.add("item", "widgets.media_label", {
	position = "right",
	scroll_texts = "on",
	padding_left = 2,
	padding_right = 2,
	icon = {
		string = ICON_MUSIC,
		font = appearance.font_icon_bold(11.0),
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
		max_chars = 7,
		align = "left",
	},
	background = { drawing = false },
})

label:subscribe("media_update", refresh)

-- 初始查询：reload 后首次显示（不恢复轮询）
query_media(function(info)
	apply_state(info, false)
	initial_ready()
end)
