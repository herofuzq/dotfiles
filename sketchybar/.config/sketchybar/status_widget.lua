-- ========== 通用状态角标 Widget 工厂 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

return function(opts)

	local function resolve_color(key)
		if key == nil then return colors.active.bg3_opaque end
		if type(key) == "number" then return key end
		local c = colors.active[key]
		if c == nil then
			local n = tonumber(key)
			return n or colors.active.sep_opaque
		end
		return c
	end

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
			color = resolve_color(opts.icon_inactive_color),
		},
		label = {
			string = "0",
			font = {
				family = fonts.font.text,
				style = fonts.font.style_map["Bold"],
				size = fonts.font.size,
			},
			padding_left = 0,
			padding_right = settings.padding.icon_label_item.label.padding_right,
			color = resolve_color(opts.label_inactive_color),
		},
		background = {
			color = colors.active.bar_bg,
			corner_radius = 10,
			border_color = opts.border_color or colors.active.bg3_opaque,
			border_width = 2,
		},
	})

	local last_num = 0

	local function update_display(count)
		local label = (count or ""):match("^%s*(.-)%s*$") or ""
		if label == "" then
			label = "0"
		end
		local num = tonumber(label:match("^(%d+)")) or 0
		last_num = num
		item:set({
			icon = { color = num > 0 and resolve_color(opts.icon_color) or resolve_color(opts.icon_inactive_color) },
			label = { string = label, color = num > 0 and resolve_color(opts.label_color) or resolve_color(opts.label_inactive_color) },
		})
	end

	local function check_status()
		sbar.exec("lsappinfo -all info -only StatusLabel " .. opts.app_id .. " | sed -n 's/.*\"label\"=\"\\([^\"]*\\)\".*/\\1/p'", update_display)
	end

	-- 主题切换时仅刷新颜色，不重查应用状态
	local function refresh_colors()
		item:set({
			icon = { color = last_num > 0 and resolve_color(opts.icon_color) or resolve_color(opts.icon_inactive_color) },
			label = { color = last_num > 0 and resolve_color(opts.label_color) or resolve_color(opts.label_inactive_color) },
		})
	end

	item:subscribe({ "routine", "system_woke" }, check_status)
	item:subscribe("theme_changed", refresh_colors)
	check_status()

	-- 点击打开对应应用
	item:subscribe("mouse.clicked", function()
		sbar.exec("open -b " .. opts.app_id)
	end)

	return item
end
