--- @since 25.5.31
--- Toggle dark/light within the CURRENT scheme's flavor pair.
--- Reads the active flavor from ~/.config/yazi/theme.toml (written by Hammerspoon
--- yazi_theme 模块), swaps to its counterpart, and hot-reloads via app:theme.
--- Hammerspoon 的下一次 scheme/外观事件会覆盖手动切换，属预期。

local THEME_TOML = (os.getenv("HOME") or "") .. "/.config/yazi/theme.toml"

-- 六色系的 dark/light 配对，与 hammerspoon/.hammerspoon/yazi_theme.lua 的
-- flavor_names 保持一致
local PAIRS = {
	{ dark = "catppuccin-mocha", light = "catppuccin-latte" },
	{ dark = "tokyonight-storm", light = "tokyonight-day" },
	{ dark = "rose-pine", light = "rose-pine-dawn" },
	{ dark = "everforest-dark", light = "everforest-light" },
	{ dark = "kanagawa", light = "kanagawa-lotus" },
	{ dark = "gruvbox-dark", light = "gruvbox-light" },
}

local function current_dark()
	local f = io.open(THEME_TOML, "r")
	if not f then
		return nil
	end
	local body = f:read("*a") or ""
	f:close()
	return body:match('dark%s*=%s*"([^"]+)"')
end

-- 找到 flavor 所属的配对及其对端；未命中返回 nil
local function counterpart(flavor)
	for _, pair in ipairs(PAIRS) do
		if pair.dark == flavor then
			return pair.light
		elseif pair.light == flavor then
			return pair.dark
		end
	end
	return nil
end

local function entry()
	local now = current_dark()
	local next_flavor = now and counterpart(now)
	if not next_flavor then
		return ya.notify({
			title = "Theme",
			content = "Unknown flavor: " .. tostring(now) .. " (use Hyper+Shift+T to switch scheme)",
			timeout = 3,
			level = "warn",
		})
	end

	-- Pin both dark and light to the same flavor so terminal bg detection cannot override.
	local out = io.open(THEME_TOML, "w")
	if not out then
		return ya.notify({
			title = "Theme",
			content = "Failed to write theme.toml",
			timeout = 3,
			level = "error",
		})
	end
	out:write(string.format('[flavor]\ndark = "%s"\nlight = "%s"\n', next_flavor, next_flavor))
	out:close()

	ya.emit("app:theme", {})
	ya.notify({ title = "Theme", content = next_flavor, timeout = 2 })
end

return { entry = entry }
