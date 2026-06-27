-- ========== 当前输入法显示 ==========
-- ABC 系统输入法 / fcitx5 中英状态
local sbar = require("sketchybar")
local icons = require("icons")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")
local find_binary = require("helpers.find_binary").find

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
		font = {
			family = fonts.font_icon.text,
			style = fonts.font_icon.style_map["Bold"],
			size = fonts.font_icon.size,
		},
		padding_left = settings.item_padding.icon_label_item.icon.padding_left,
		padding_right = 2,
		color = colors.sapphire,
	},
	label = {
		font = {
			family = fonts.font.text,
			style = fonts.font.style_map["Bold"],
			size = fonts.font.size,
		},
		padding_left = 0,
		padding_right = settings.item_padding.icon_label_item.label.padding_right,
		color = colors.pill_fg,
	},
	background = {
		color = colors.pill_bg,
		corner_radius = 10,
		border_width = 2,
		border_color = colors.border,
	},
})

local function update_display(im_id, fcitx_mode)
	if im_id == "com.apple.keylayout.ABC" then
		input_method:set({
			icon = { string = icons.input_method.keyboard, color = colors.blue },
			label = { string = "A", color = colors.pill_fg },
		})
	elseif im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
		if fcitx_mode == "2" then -- fcitx5-remote: 0=关闭, 1=不活跃, 2=中文
			input_method:set({
				icon = { string = icons.input_method.keyboard, color = colors.mauve },
				label = { string = "CH", color = colors.pill_fg },
			})
		else
			-- fcitx 英文模式
			input_method:set({
				icon = { string = icons.input_method.keyboard, color = colors.mauve },
				label = { string = "EN", color = colors.pill_fg },
			})
		end
	else
		-- 未知输入法（macism 失败时 im_id 可能为 nil，加防护避免崩溃）
		input_method:set({
			icon = { string = icons.input_method.keyboard, color = colors.surface1 },
			label = { string = (im_id and im_id:match("[^.]+$")) or "?", color = colors.pill_fg },
		})
	end
end

local function check_status()
	sbar.exec("macism", function(im_id)
		im_id = im_id and im_id:match("^%s*(.-)%s*$")
		if im_id == "org.fcitx.inputmethod.Fcitx5.zhHans" then
			sbar.exec("'" .. FCITX_REMOTE .. "'", function(mode)
				local clean = mode and mode:match("^%s*(.-)%s*$"); update_display(im_id, (clean and clean:match("^[012]$")) and clean or nil)
			end)
		else
			update_display(im_id)
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
