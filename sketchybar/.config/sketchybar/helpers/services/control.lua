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
local lua_bin = find_binary({ "/opt/homebrew/bin/lua", "/usr/local/bin/lua" }, "lua")
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

local function exec_silent(command)
	return os.execute(command .. " >/dev/null 2>&1")
end

local function run(command)
	local ok = exec_silent(command)
	trigger_refresh()
	return ok
end

local function run_async(command)
	local ok = os.execute("(" .. command .. ") >/dev/null 2>&1 &")
	trigger_refresh()
	return ok
end

local function compose_command(group)
	return shell_quote(docker) .. " compose -f " .. shell_quote(group.compose_file)
end

local function stop_managed_groups()
	for _, group in ipairs(config.groups or {}) do
		if group.kind == "docker_compose" and group.compose_file then
			exec_silent(compose_command(group) .. " stop --timeout 10")
		end
	end
end

local function quit_docker_desktop()
	stop_managed_groups()
	local ok = exec_silent(shell_quote(docker) .. " desktop stop --detach --timeout 30")
	trigger_refresh()
	return ok
end

local function quit_docker_desktop_async()
	return run_async(table.concat({
		shell_quote(lua_bin or "lua"),
		shell_quote(config_dir .. "/helpers/services/control.lua"),
		"docker",
		"quit-now",
	}, " "))
end

if scope == "docker" then
	local action = arg[2] or ""
	if action == "start" then
		run(shell_quote(docker) .. " desktop start --detach --timeout 30")
		os.exit(0)
	elseif action == "quit" then
		quit_docker_desktop_async()
		os.exit(0)
	elseif action == "quit-now" then
		quit_docker_desktop()
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

	local compose = compose_command(group)
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
