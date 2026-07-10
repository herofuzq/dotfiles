#!/usr/bin/env lua

-- 控制 Docker Desktop、Compose group 和单个 Compose service。
-- 只读 helpers/services/config.lua，避免 UI 和脚本各自维护 compose 路径。

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

local config = require("helpers.services.config")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local scope = arg[1] or ""
local docker = find_binary({ "/opt/homebrew/bin/docker", "/usr/local/bin/docker" }, "docker")
local sketchybar = find_binary({ "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar" }, "sketchybar")

local function find_group(id)
	for _, group in ipairs(config.groups or {}) do
		if group.id == id then
			return group
		end
	end
	return nil
end

local function find_service(group, id)
	for _, service in ipairs(group.services or {}) do
		if service.id == id then
			return service
		end
	end
	return nil
end

local function trigger_refresh()
	os.execute(shell_quote(sketchybar) .. " --trigger services_change SOURCE=services_control >/dev/null 2>&1")
end

local function run(command)
	local ok = os.execute(command .. " >/dev/null 2>&1")
	trigger_refresh()
	return ok
end

if scope == "docker" then
	local action = arg[2] or ""
	if action == "start" then
		run("open -g -a Docker")
		os.exit(0)
	elseif action == "quit" then
		run("osascript -e " .. shell_quote('quit app "Docker"'))
		os.exit(0)
	end

	trigger_refresh()
	os.exit(1)
end

if scope == "group" or scope == "service" then
	local group_id = arg[2] or ""
	local service_id = scope == "service" and (arg[3] or "") or ""
	local action = scope == "service" and (arg[4] or "") or (arg[3] or "")
	local group = find_group(group_id)
	if not group then
		trigger_refresh()
		os.exit(1)
	end

	if scope == "service" and not find_service(group, service_id) then
		trigger_refresh()
		os.exit(1)
	end

	if group.kind ~= "docker_compose" or not group.compose_file then
		trigger_refresh()
		os.exit(1)
	end

	local compose = shell_quote(docker) .. " compose -f " .. shell_quote(group.compose_file)
	local target = scope == "service" and (" " .. shell_quote(service_id)) or ""
	if action == "start" then
		run(compose .. " up -d" .. target)
	elseif action == "stop" then
		run(compose .. " stop" .. target)
	elseif action == "pause" then
		run(compose .. " pause" .. target)
	elseif action == "resume" then
		run(compose .. " unpause" .. target)
	else
		trigger_refresh()
		os.exit(1)
	end
	os.exit(0)
end

trigger_refresh()
os.exit(1)
