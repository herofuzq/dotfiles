--- @since 26.8.15
-- Vendored from Gallardo994/clippy and patched for Yazi 26.8.15:
-- Yanked/Selected __pairs() now yields File, not Url. tostring(File) is
-- "File: 0x...", so copy the Url (or hovered.url) instead.

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	local function add(item)
		paths[#paths + 1] = tostring(item.url or item)
	end

	for _, f in pairs(tab.selected) do
		add(f)
	end
	if #paths == 0 then
		for _, f in pairs(cx.yanked) do
			add(f)
		end
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

return {
	entry = function()
		local urls = selected_or_hovered()

		if #urls == 0 then
			return ya.notify({ title = "System Clipboard", content = "No file selected", level = "warn", timeout = 5 })
		end

		local cmd = Command("clippy")
		for _, url in ipairs(urls) do
			cmd = cmd:arg(url)
		end

		local output, err = cmd
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:spawn()
			:wait_with_output()

		if err == nil then
			ya.notify({
				title = "Clipboard: Copied " .. tostring(#urls) .. " file(s)",
				content = table.concat(urls, "\n"),
				level = "info",
				timeout = 5,
			})
		end

		if err ~= nil then
			ya.notify({
				title = "Clipboard",
				content = string.format("Could not copy selected file(s): %s", output.stderr),
				level = "error",
				timeout = 5,
			})
		end
	end,
}
