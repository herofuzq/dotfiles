#!/usr/bin/env lua

-- 输出 tab-separated 状态，供 items/services.lua 解析。
-- 格式：
--   summary <ok|error> <running_count> <total_count> <message>
--   group   <group_id> <label> <running_count> <total_count>
--   service <group_id> <service_id> <label> <state> <port> <status>

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

local config = require("helpers.services.config")
local shell_quote = require("helpers.utils").shell_quote
local find_binary = require("helpers.find_binary").find

local docker = find_binary({ "/opt/homebrew/bin/docker", "/usr/local/bin/docker" }, "docker")
local docker_error

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

local function docker_compose_states(group)
	if not os.execute("pgrep -q Docker 2>/dev/null") then
		docker_error = "docker not running"
		return nil
	end

	local info_cmd = shell_quote(docker) .. " info 2>/dev/null"
	local info_script = "( " .. info_cmd .. " & PID=$!; ( sleep 3; kill -9 $PID 2>/dev/null )& wait $PID 2>/dev/null )"
	local info_f = io.popen("sh -c " .. shell_quote(info_script))
	if not info_f then
		docker_error = "docker unavailable"
		return nil
	end
	if not info_f:close() then
		docker_error = "docker unavailable"
		return nil
	end

	local template = '{{.Label "com.docker.compose.service"}}\t{{.Label "com.docker.compose.project"}}\t{{.State}}\t{{.Status}}'
	local inner_cmd = shell_quote(docker) .. " ps -a --format " .. shell_quote(template) .. " 2>/dev/null"
	local timeout_script = "( " .. inner_cmd .. " & PID=$!; ( sleep 3; kill -9 $PID 2>/dev/null )& wait $PID 2>/dev/null )"
	local cmd = "sh -c " .. shell_quote(timeout_script)

	local f = io.popen(cmd)
	if not f then
		docker_error = "docker unavailable"
		return nil
	end

	local output = f:read("*a") or ""
	local ok = f:close()
	if not ok then
		docker_error = "docker unavailable"
		return nil
	end

	local states = {}
	for line in output:gmatch("[^\n]+") do
		local service_id, project, state, status = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
		if service_id and service_id ~= "" and project and project == group.project then
			if status:find("Paused", 1, true) then
				state = "paused"
			end
			states[service_id] = {
				state = state ~= "" and state or "unknown",
				status = status ~= "" and status or state,
			}
		end
	end
	return states
end

local total_count = 0
local running_count = 0
local group_results = {}

for _, group in ipairs(config.groups or {}) do
	local group_total = #(group.services or {})
	local group_running = 0
	total_count = total_count + group_total

	local states
	if group.kind == "docker_compose" then
		states = docker_compose_states(group)
	end

	local services = {}
	for _, service in ipairs(group.services or {}) do
		local state = "unknown"
		local status = "unknown"
		if states and states[service.id] then
			state = states[service.id].state
			status = states[service.id].status
		elseif states then
			state = "missing"
			status = "not created"
		end

		if state == "running" then
			group_running = group_running + 1
			running_count = running_count + 1
		end

		services[#services + 1] = {
			id = service.id,
			label = service.label or service.id,
			port = service.port or "",
			state = state,
			status = status,
		}
	end

	group_results[#group_results + 1] = {
		id = group.id,
		label = group.label or group.id,
		running = group_running,
		total = group_total,
		services = services,
	}
end

emit("summary", docker_error and "error" or "ok", running_count, total_count, docker_error or "")
for _, group in ipairs(group_results) do
	emit("group", group.id, group.label, group.running, group.total)
	for _, service in ipairs(group.services) do
		emit("service", group.id, service.id, service.label, service.state, service.port, service.status)
	end
end
