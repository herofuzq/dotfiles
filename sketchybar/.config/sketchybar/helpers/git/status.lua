#!/usr/bin/env lua

-- 输出 tab-separated git 状态，供 items/git.lua 解析。
-- 格式：
--   repo <path> <label> <branch> <status_keyword> <dirty_count> <ahead> <behind>

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

local config = require("helpers.git.config")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local git = find_binary({ "/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git" }, "git")

local function field(value)
	value = tostring(value or "")
	value = value:gsub("[\t\r\n]", " ")
	return value
end

local function emit(...)
	local parts = { ... }
	for i, value in ipairs(parts) do
		parts[i] = field(value)
	end
	io.write(table.concat(parts, "\t"), "\n")
end

for _, repo in ipairs(config.repos or {}) do
	local path = repo.path
	local label = repo.label or path

	local cmd = shell_quote(git) .. " -C " .. shell_quote(path) .. " status --porcelain=v1 -b 2>/dev/null"
	local h = io.popen(cmd)
	if not h then
		emit("repo", path, label, "-", "error", "-", "-", "-")
	else
		local output = h:read("*a") or ""
		local ok = h:close()
		if not ok then
			emit("repo", path, label, "-", "error", "-", "-", "-")
		else
			local branch
			local ahead = "0"
			local behind = "0"
			local dirty_count = 0
			local first = true

			for line in (output .. "\n"):gmatch("(.-)\n") do
				if first then
					first = false
					local rest = line:match("^## (.+)$")
					if rest then
						branch = rest:match("^No commits yet on (.+)$")
							or rest:match("^Initial commit on (.+)$")
							or rest:match("^(.-)%.%.%.")
							or rest:match("^([^%s%[]+)")
						-- 宽松匹配：同时有 ahead/behind 时也能解析
						ahead = rest:match("ahead (%d+)") or "0"
						behind = rest:match("behind (%d+)") or "0"
					end
				elseif line ~= "" then
					dirty_count = dirty_count + 1
				end
			end

			if branch then
				emit("repo", path, label, branch, dirty_count > 0 and "dirty" or "ok", dirty_count, ahead, behind)
			else
				emit("repo", path, label, "-", "error", "-", "-", "-")
			end
		end
	end
end
