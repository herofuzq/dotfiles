local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;" .. package.path

local theme = require("theme")
local yazi_theme = require("yazi_theme")

-- 映射表必须覆盖 theme 服务的全部 scheme，且 dark/light 互不相同
for _, name in ipairs(theme.scheme_names) do
	local names = yazi_theme.flavor_names[name]
	assert(names, name .. " 缺少 yazi flavor 映射")
	assert(type(names.dark) == "string" and names.dark ~= "", name .. ".dark 为空")
	assert(type(names.light) == "string" and names.light ~= "", name .. ".light 为空")
	assert(names.dark ~= names.light, name .. " 的 dark/light 不应相同")
end

-- render 双槽位锁定同一 flavor
local body = yazi_theme.render("gruvbox-dark")
assert(body:find('dark = "gruvbox-dark"', 1, true))
assert(body:find('light = "gruvbox-dark"', 1, true))
assert(body:find("^%[flavor%]"))

-- theme.toml 路径
local path = yazi_theme.theme_toml_path()
assert(path and path:find("/%.config/yazi/theme%.toml$"))

-- 非法输入
local ok, err = yazi_theme.write("dracula", "dark")
assert(ok == nil and err:find("unknown scheme", 1, true))
local ok2, err2 = yazi_theme.write("gruvbox", "sepia")
assert(ok2 == nil and err2:find("unknown flavor", 1, true))

print("yazi_theme_test.lua OK")
