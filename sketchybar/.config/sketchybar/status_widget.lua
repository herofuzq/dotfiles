-- ========== 通用状态角标 Widget 工厂 ==========
local sbar = require("sketchybar")
local appearance = require("appearance")
local colors = appearance.colors
local settings = require("settings")
local startup = require("helpers.startup")

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

	-- shared_bracket=true：自身不画 pill，由外层 bracket 统一背景（wechat/dingtalk 等）
	local background
	if opts.shared_bracket then
		background = { drawing = false }
	else
		background = {
			color = colors.pill_bg,
			corner_radius = 10,
			border_color = opts.border_color or colors.surface1,
			border_width = 2,
		}
	end

	local pad = settings.item_padding.icon_label_item
	local item = sbar.add("item", opts.name, {
		position = "right",
		update_freq = opts.update_freq or 30,
		padding_left = opts.padding_left ~= nil and opts.padding_left or 2,
		padding_right = opts.padding_right ~= nil and opts.padding_right or 2,
		icon = {
			string = opts.icon,
			font = opts.icon_font or "sketchybar-app-font:Regular:14.0",
			padding_left = opts.icon_padding_left ~= nil and opts.icon_padding_left or pad.icon.padding_left,
			padding_right = opts.icon_padding_right ~= nil and opts.icon_padding_right or 2,
			color = resolve_color(opts.icon_inactive_color),
		},
		label = {
			string = "0",
			font = appearance.font_label_bold(),
			padding_left = opts.label_padding_left ~= nil and opts.label_padding_left or 0,
			padding_right = opts.label_padding_right ~= nil and opts.label_padding_right or pad.label.padding_right,
			color = resolve_color(opts.label_inactive_color),
		},
		background = background,
	})

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
		startup.after_reveal(opts.name .. ".status", function()
			item:set({
				icon = { color = num > 0 and resolve_color(opts.icon_color) or resolve_color(opts.icon_inactive_color) },
				label = {
					string = label,
					color = num > 0 and resolve_color(opts.label_color) or resolve_color(opts.label_inactive_color),
				},
			})
		end)
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
	local initial_ready = startup.track(opts.name .. ".status")

	local function check_status()
		sbar.exec("lsappinfo -all info -only StatusLabel " .. safe_id, function(raw)
			update_display(raw and raw:match([["label"%s*=%s*"([^"]*)"]]))
			initial_ready()
		end)
	end

	item:subscribe({ "routine", "system_woke" }, check_status)
	check_status()

	item:subscribe("mouse.clicked", function()
		sbar.exec("open -b " .. safe_id)
	end)

	return item
end
