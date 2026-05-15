-- ========== 通用状态角标 Widget 工厂 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

return function(opts)
	local item = sbar.add("item", opts.name, {
		position = "right",
		update_freq = 30,
		padding_left = 2,
		padding_right = 2,
		icon = {
			string = opts.icon,
			font = "sketchybar-app-font:Regular:14.0",
			padding_left = settings.padding.icon_label_item.icon.padding_left,
			padding_right = 2,
			color = opts.icon_inactive_color,
		},
		label = {
			string = "0",
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

	local function update_display(count)
		local label = count:match("^%s*(.-)%s*$") or ""
		if label == "" or not tonumber(label) then
			label = "0"
		end
		local num = tonumber(label)
		item:set({
			icon = { color = num > 0 and opts.icon_color or opts.icon_inactive_color },
			label = { string = label, color = num > 0 and opts.label_color or opts.label_inactive_color },
		})
	end

	local function check_status()
		sbar.exec("lsappinfo -all info -only StatusLabel " .. opts.app_id .. " | sed -n 's/.*\"label\"=\"\\([^\"]*\\)\".*/\\1/p'", update_display)
	end

	item:subscribe({ "routine", "system_woke" }, check_status)
	check_status()

	return item
end
