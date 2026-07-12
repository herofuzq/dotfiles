--- @since 25.5.31
--- Cycle theme: mocha (dark) → latte (light) → mocha …
--- Writes ~/.config/yazi/theme.toml and hot-reloads via app:theme.

local THEME_TOML = (os.getenv("HOME") or "") .. "/.config/yazi/theme.toml"
local MOCHA = "catppuccin-mocha"
local LATTE = "catppuccin-latte"

local function current_dark()
	local f = io.open(THEME_TOML, "r")
	if not f then
		return MOCHA
	end
	local body = f:read("*a") or ""
	f:close()
	local dark = body:match('dark%s*=%s*"([^"]+)"')
	return dark or MOCHA
end

local function entry()
	local now = current_dark()
	local next_flavor = (now == MOCHA) and LATTE or MOCHA
	local label = (next_flavor == MOCHA) and "dark (mocha)" or "light (latte)"

	-- Pin both dark and light to the same flavor so terminal bg detection cannot override.
	local body = string.format(
		'[flavor]\ndark = "%s"\nlight = "%s"\n',
		next_flavor,
		next_flavor
	)
	local out = io.open(THEME_TOML, "w")
	if not out then
		return ya.notify({
			title = "Theme",
			content = "Failed to write theme.toml",
			timeout = 3,
			level = "error",
		})
	end
	out:write(body)
	out:close()

	ya.emit("app:theme", {})
	ya.notify({ title = "Theme", content = label, timeout = 2 })
end

return { entry = entry }
