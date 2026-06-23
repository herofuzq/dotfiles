-- ========== 通用状态角标 Widget 工厂 ==========
local sbar = require("sketchybar")
local fonts = require("fonts")
local colors = require("appearance").colors
local settings = require("settings")

return function(opts)
	local function resolve_color(key)
		if key == nil then
			return colors.surface1
		end
		if type(key) == "number" then
			return key
		end
		local c = colors[key]
		if c == nil then
			local n = tonumber(key)
			return n or colors.pill_fg
		end
		return c
	end

	local item = sbar.add("item", opts.name, {
		position = "right",
		update_freq = opts.update_freq or 30,
		padding_left = 2,
		padding_right = 2,
		icon = {
			string = opts.icon,
			font = "sketchybar-app-font:Regular:14.0",
			padding_left = settings.item_padding.icon_label_item.icon.padding_left,
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
			padding_right = settings.item_padding.icon_label_item.label.padding_right,
			color = resolve_color(opts.label_inactive_color),
		},
		background = {
			color = colors.pill_bg,
			corner_radius = 10,
			border_color = opts.border_color or colors.surface1,
			border_width = 2,
		},
	})

	local last_num = 0
	-- dedup: 与 battery/network/sys widget 对齐,num + label 字符串都没变就跳过 set
	local last_display_signature

	local function update_display(count)
		local raw = count and count:match("^%s*(.-)%s*$") or ""
		local label = (raw and raw ~= "") and raw or "0"
		local num = tonumber(label:match("^(%d+)")) or 0
		local signature = tostring(num) .. "|" .. label
		if signature == last_display_signature then
			return
		end
		last_display_signature = signature
		last_num = num
		item:set({
			icon = { color = num > 0 and resolve_color(opts.icon_color) or resolve_color(opts.icon_inactive_color) },
			label = {
				string = label,
				color = num > 0 and resolve_color(opts.label_color) or resolve_color(opts.label_inactive_color),
			},
		})
	end

	local raw_id = opts.app_id or ""
	local safe_id = raw_id:gsub("[^%w%.%-]", "")
	if safe_id == "" then
		io.stderr:write("sketchybar: status_widget: missing app_id\n")
		return
	end
	if not safe_id:match("%.") then
		io.stderr:write("sketchybar: status_widget: invalid bundle id format: " .. safe_id .. "\n")
		return
	end

	local function check_status()
		sbar.exec("lsappinfo -all info -only StatusLabel " .. safe_id, function(raw)
			update_display(raw and raw:match('"label"%s*=%s*"([^"]*)"'))
		end)
	end

	item:subscribe({ "routine", "system_woke" }, check_status)
	check_status()

	-- 点击打开对应应用
	item:subscribe("mouse.clicked", function()
		sbar.exec("open -b " .. safe_id)
	end)

	return item
end
