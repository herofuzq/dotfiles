-- ========== 当前输入法显示 ==========
-- ABC / 微信输入法 / fcitx5 中英状态
local sbar = require("sketchybar")
local icons = require("icons")
local appearance = require("appearance")
local startup = require("helpers.startup")
local colors = appearance.colors
local initial_ready = startup.track("input_method.status")
local settings = require("settings")
local find_binary = require("helpers.find_binary").find
local WETYPE_SRC = "com.tencent.inputmethod.wetype.pinyin"

-- 动态查找 fcitx5-remote 路径（支持 .app 安装和 brew 安装两种方式）。
-- fallback 用 macOS .app 路径，因为这是 fcitx5 cask 的默认安装位置，比 brew 路径更稳。
local FCITX_REMOTE = find_binary(
	{
		"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote",
		"/opt/homebrew/bin/fcitx5-remote",
		"/usr/local/bin/fcitx5-remote",
	},
	"/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"
)

local input_method = sbar.add("item", "widgets.input_method", {
	position = "right",
	padding_left = 4,
	padding_right = 4,
	icon = {
		font = appearance.font_icon_bold(),
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.identity.input_default,
	},
	label = {
		font = appearance.font_label_bold(),
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.pill_fg,
	},
	background = appearance.pill_bg(),
})
appearance.register_pill("widgets.input_method")

local last_im_id, last_fcitx_mode
local display_initialized = false

-- 各输入法分支的 (icon 颜色, label 文字)，主题切换时复用同一套分支
local function display_state(im_id, fcitx_mode)
	if im_id == "com.apple.keylayout.ABC" then
		return colors.identity.input_a, "A"
	elseif im_id == WETYPE_SRC then
		return colors.identity.input_zh, "微"
	elseif im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
		if fcitx_mode == "2" then -- fcitx5-remote: 0=关闭, 1=不活跃, 2=中文
			return colors.identity.input_ch, "CH"
		end
		-- fcitx 英文模式
		return colors.identity.input_en, "EN"
	end
	-- 未知输入法（macism 失败时 im_id 可能为 nil，加防护避免崩溃）
	return colors.surface1, (im_id and im_id:match("[^.]+$")) or "?"
end

local function apply_display(im_id, fcitx_mode)
	last_im_id, last_fcitx_mode = im_id, fcitx_mode
	display_initialized = true
	local icon_color, label_text = display_state(im_id, fcitx_mode)
	input_method:set({
		icon = { string = icons.input_method.keyboard, color = icon_color },
		label = { string = label_text, color = colors.pill_fg },
	})
end

local function update_display(im_id, fcitx_mode)
	startup.after_reveal("input_method.status", function()
		apply_display(im_id, fcitx_mode)
	end)
end

local function check_status()
	sbar.exec("macism", function(im_id)
		im_id = im_id and im_id:match("^%s*(.-)%s*$")
		if im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
			sbar.exec("'" .. FCITX_REMOTE .. "'", function(mode)
				local clean = mode and mode:match("^%s*(.-)%s*$")
				update_display(im_id, (clean and clean:match("^[012]$")) and clean or nil)
				initial_ready()
			end)
		else
			update_display(im_id)
			initial_ready()
		end
	end)
end

local function check_status_fast(env)
	local im_id = env.IM_ID
	if im_id and im_id ~= "" and im_id ~= "org.fcitx.inputmethod.Fcitx5.zhHans" then
		update_display(im_id)
		return
	end

	local fcitx5_active = env.FCITX5_ACTIVE
	if fcitx5_active == "1" then
		local fcitx_mode = env.FCITX5_MODE
		if fcitx_mode == "2" or fcitx_mode == "1" or fcitx_mode == "0" then
			update_display("org.fcitx.inputmethod.Fcitx5.zhHans", fcitx_mode)
			return
		end
	elseif fcitx5_active == "0" and im_id and im_id ~= "" then
		update_display("com.apple.keylayout.ABC")
		return
	end
	check_status()
end

input_method:subscribe("input_method_change", function(env)
	if env.FCITX5_ACTIVE ~= nil or env.IM_ID ~= nil then
		check_status_fast(env)
	else
		check_status()
	end
end)
input_method:subscribe("system_woke", check_status)
check_status()

-- ========== 主题热换色：按缓存的当前输入法分支重涂 ==========
local function apply_colors(C)
	if not display_initialized then
		return -- 尚未完成首次检测，保持创建期颜色
	end
	local icon_color = display_state(last_im_id, last_fcitx_mode)
	input_method:set({
		icon = { color = icon_color },
		label = { color = C.pill_fg },
		background = { color = C.pill_bg, border_color = C.border },
	})
end
apply_colors(colors)
appearance.register_colors("input_method", apply_colors)
