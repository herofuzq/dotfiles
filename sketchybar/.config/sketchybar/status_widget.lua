-- ========== 通用状态角标 Widget 工厂 ==========
-- 用于创建微信、钉钉等需要显示未读消息数的图标+数字条目
-- 使用方法：require("status_widget") { name=..., app_id=..., icon=..., ... }
local colors = require("appearance").colors
local settings = require("settings")
local sbar = require("sketchybar")
local fonts = require("fonts")

return function(opts)
	local item = sbar.add("item", opts.name, {
		position = "right",
		update_freq = 30,           -- 每 30 秒轮询一次
		padding_left = 2,
		padding_right = 2,
		icon = {
			string = opts.icon,     -- 图标名，如 ":wechat:"、":dingtalk:"
			font = "sketchybar-app-font:Regular:14.0",
			padding_left = settings.padding.icon_label_item.icon.padding_left,
			padding_right = 2,
			color = opts.icon_inactive_color,  -- 无消息时的颜色
		},
		label = {
			string = "0",           -- 初始显示 0
			font = {
				family = fonts.font_fira.text,
				style = fonts.font_fira.style_map["Bold"],
				size = fonts.font_fira.size,
			},
			padding_left = 0,
			padding_right = settings.padding.icon_label_item.label.padding_right,
			color = opts.label_inactive_color,
		},
		background = {
			color = colors.active.bar_bg,
			corner_radius = 10,
			border_color = opts.border_color,
			border_width = 2,
		},
	})

	-- 解析 lsappinfo 返回的状态标签，更新图标和数字的颜色
	local function update_display(count)
		local label = count:match("^%s*(.-)%s*$") or ""  -- 去除首尾空白
		if label == "" or not tonumber(label) then
			label = "0"
		end
		local num = tonumber(label)
		item:set({
			icon = { color = num > 0 and opts.icon_color or opts.icon_inactive_color },
			label = { string = label, color = num > 0 and opts.label_color or opts.label_inactive_color },
		})
	end

	-- 通过 macOS lsappinfo 查询应用的角标数字
	local function check_status()
		sbar.exec("lsappinfo -all info -only StatusLabel " .. opts.app_id .. " | sed -n 's/.*\"label\"=\"\\([^\"]*\\)\".*/\\1/p'", update_display)
	end

	item:subscribe({ "routine", "system_woke" }, check_status)  -- 定时 & 唤醒时刷新
	check_status()                                               -- 启动时主动查一次

	return item
end
