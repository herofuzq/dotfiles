-- Yazi 主题同步：作为 theme 服务的 subscriber，
-- scheme 切换或 macOS 深浅外观变化时，重写 yazi theme.toml 并热重载。
-- theme.toml 双槽位锁定同一 flavor（与 theme-toggle 插件同一机制），
-- 不依赖 yazi 的终端明暗探测（实测不可靠，只有部分颜色变动）。

local M = {}

-- scheme -> yazi flavor 目录名（~/.config/yazi/flavors/<name>.yazi）
-- 与 hammerspoon/tests/yazi_theme_test.lua 对照，防漂移
M.flavor_names = {
	catppuccin = { dark = "catppuccin-mocha", light = "catppuccin-latte" },
	tokyonight = { dark = "tokyonight-storm", light = "tokyonight-day" },
	rosepine = { dark = "rose-pine", light = "rose-pine-dawn" },
	everforest = { dark = "everforest-dark", light = "everforest-light" },
	kanagawa = { dark = "kanagawa", light = "kanagawa-lotus" },
	gruvbox = { dark = "gruvbox-dark", light = "gruvbox-light" },
}

function M.render(flavor_name)
	return string.format('[flavor]\ndark = "%s"\nlight = "%s"\n', flavor_name, flavor_name)
end

function M.theme_toml_path()
	local home = os.getenv("HOME")
	return home and (home .. "/.config/yazi/theme.toml") or nil
end

-- 原子写入，失败返回 nil, err
local function write_file_atomic(path, content)
	local temporary = string.format("%s.tmp.%d.%d", path, os.time(), math.random(100000, 999999))
	local file, open_error = io.open(temporary, "w")
	if not file then
		return nil, tostring(open_error)
	end
	local wrote, write_error = file:write(content)
	if not wrote then
		file:close()
		os.remove(temporary)
		return nil, tostring(write_error)
	end
	if not file:close() then
		os.remove(temporary)
		return nil, "close failed"
	end
	local renamed, rename_error = os.rename(temporary, path)
	if not renamed then
		os.remove(temporary)
		return nil, tostring(rename_error)
	end
	return true
end

-- 通知运行中的 yazi 实例热重载主题（receiver 0 = 广播到所有实例，见 yazi DDS 文档；
-- best-effort，失败则下次启动生效）
local function hot_reload()
	if not (_G.hs and hs.task) then
		return
	end
	local task = hs.task.new("/usr/bin/env", function(exit_code, _, stderr)
		if exit_code ~= 0 then
			print("[YaziTheme] ya emit-to 0 app:theme 失败: " .. tostring(stderr or exit_code))
		end
	end, { "ya", "emit-to", "0", "app:theme" })
	if not task then
		print("[YaziTheme] 无法创建 ya emit 任务")
		return
	end
	task:start()
end

function M.write(scheme, flavor)
	local names = M.flavor_names[scheme]
	if not names then
		return nil, "unknown scheme: " .. tostring(scheme)
	end
	local flavor_name = names[flavor]
	if not flavor_name then
		return nil, "unknown flavor: " .. tostring(flavor)
	end
	local path = M.theme_toml_path()
	if not path then
		return nil, "HOME unavailable"
	end
	local ok, err = write_file_atomic(path, M.render(flavor_name))
	if not ok then
		return nil, err
	end
	hot_reload()
	return true
end

function M.install()
	local theme = require("theme")
	theme.subscribe("yazi", function()
		local ok, err = M.write(theme.current_scheme(), theme.current_flavor())
		if not ok then
			print("[YaziTheme] 同步失败: " .. tostring(err))
		end
	end)
end

return M
