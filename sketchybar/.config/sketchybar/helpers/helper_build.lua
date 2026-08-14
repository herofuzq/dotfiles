-- ========== Helper binary build coordinator ==========
-- One batched stat classifies targets before startup:
-- missing binaries build synchronously; stale binaries rebuild in background.
-- Builds always run in CONFIG_DIR (the live ~/.config tree), never in dotfiles.

local shell_quote = require("helpers.utils").shell_quote
local tmp_path = require("helpers.utils").tmp_path

local M = {}

function M.specs(cfg)
	local h = cfg .. "/helpers"
	local swift_mk = h .. "/swift.mk"
	return {
		{
			id = "cpu_load",
			target = h .. "/event_providers/cpu_load/bin/cpu_load",
			build_dir = h .. "/event_providers/cpu_load",
			sources = {
				h .. "/event_providers/cpu_load/cpu_load.c",
				h .. "/event_providers/cpu_load/cpu.h",
				h .. "/event_providers/sketchybar.h",
				h .. "/event_providers/cpu_load/makefile",
			},
		},
		{
			id = "aerospace_watch",
			target = h .. "/event_providers/aerospace_watch/bin/aerospace_watch",
			build_dir = h .. "/event_providers/aerospace_watch",
			restart_label = "com.fuzhuoqun.aerospace_watch",
			sources = {
				h .. "/event_providers/aerospace_watch/aerospace_watch.swift",
				h .. "/event_providers/aerospace_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "docker_watch",
			target = h .. "/event_providers/docker_watch/bin/docker_watch",
			build_dir = h .. "/event_providers/docker_watch",
			restart_label = "com.fuzhuoqun.docker_watch",
			sources = {
				h .. "/event_providers/docker_watch/docker_watch.swift",
				h .. "/event_providers/docker_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "input_method_watch",
			target = h .. "/event_providers/input_method/bin/input_method_watch",
			build_dir = h .. "/event_providers/input_method",
			restart_label = "com.fuzhuoqun.input_method_watch",
			sources = {
				h .. "/event_providers/input_method/input_method_watch.swift",
				h .. "/event_providers/input_method/makefile",
				swift_mk,
			},
		},
		{
			id = "media_watch",
			target = h .. "/event_providers/media_watch/bin/media_watch",
			build_dir = h .. "/event_providers/media_watch",
			restart_label = "com.fuzhuoqun.media_watch",
			sources = {
				h .. "/event_providers/media_watch/media_watch.swift",
				h .. "/event_providers/media_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "sys_watch",
			target = h .. "/event_providers/sys_watch/bin/sys_watch",
			build_dir = h .. "/event_providers/sys_watch",
			sources = {
				h .. "/event_providers/sys_watch/sys_watch.swift",
				h .. "/event_providers/sys_watch/makefile",
				swift_mk,
			},
		},
		{
			id = "menus",
			target = h .. "/menus/bin/menus",
			build_dir = h .. "/menus",
			sources = { h .. "/menus/menus.c", h .. "/menus/makefile" },
		},
		{
			id = "bar_height",
			target = h .. "/bar_height/bin/bar_height",
			build_dir = h .. "/bar_height",
			sources = { h .. "/bar_height/main.swift", h .. "/bar_height/makefile", swift_mk },
		},
		{
			id = "dock_width",
			target = h .. "/dock_width/bin/dock_width",
			build_dir = h .. "/dock_width",
			sources = { h .. "/dock_width/main.swift", h .. "/dock_width/makefile", swift_mk },
		},
	}
end

local function all_paths(specs)
	local paths, seen = {}, {}
	for _, spec in ipairs(specs) do
		local candidates = { spec.target }
		for _, source in ipairs(spec.sources) do
			candidates[#candidates + 1] = source
		end
		for _, path in ipairs(candidates) do
			if not seen[path] then
				seen[path] = true
				paths[#paths + 1] = path
			end
		end
	end
	return paths
end

function M.read_mtimes(specs)
	local quoted = {}
	for _, path in ipairs(all_paths(specs)) do
		quoted[#quoted + 1] = shell_quote(path)
	end
	if #quoted == 0 then return {} end

	local pipe = io.popen("stat -L -f '%m\t%N' " .. table.concat(quoted, " ") .. " 2>/dev/null")
	if not pipe then return {} end
	local mtimes = {}
	for line in pipe:lines() do
		local mtime, path = line:match("^(%d+)\t(.*)$")
		if mtime and path then mtimes[path] = tonumber(mtime) end
	end
	pipe:close()
	return mtimes
end

function M.plan(specs, mtimes)
	local plan = { sync = {}, background = {}, fresh = {} }
	for _, spec in ipairs(specs) do
		local target_mtime = mtimes[spec.target]
		if not target_mtime then
			plan.sync[#plan.sync + 1] = spec
		else
			local stale = false
			for _, source in ipairs(spec.sources) do
				local source_mtime = mtimes[source]
				if not source_mtime or source_mtime > target_mtime then
					stale = true
					break
				end
			end
			local bucket = stale and plan.background or plan.fresh
			bucket[#bucket + 1] = spec
		end
	end
	return plan
end

-- ========== 所有权锁 + digest/applied marker + 统一 worker ==========
-- 每个 spec 一把 lockf 所有权锁（BSD flock 语义：进程退出内核自动释放，
-- 锁文件长期存在是正常的，绝不能删除「陈旧锁文件」）。锁覆盖 make + 发布 +
-- kickstart + marker 写入，权威逻辑在 helpers/helper_apply.sh 里。
-- 计划（plan）只是优化：获得锁后仍由 helper_apply.sh 里的 make 重新判断
-- freshness（make 幂等）。手工直接运行 make 不受此锁保护。
local LOCKF_BIN = "/usr/bin/lockf"

function M.spec_lock_path(spec)
	return tmp_path("sketchybar_build_lock." .. spec.id)
end

function M.spec_log_path(spec)
	return tmp_path("sketchybar_make." .. spec.id .. ".log")
end

function M.applied_marker_path(spec)
	return tmp_path("sketchybar_applied." .. spec.id)
end

-- helper_apply.sh 的绝对路径。spec.build_dir = <cfg>/helpers/...，脚本在同一
-- helpers 目录下；测试用 fake cfg 时可覆写。
function M.helper_apply_path(cfg)
	return cfg .. "/helpers/helper_apply.sh"
end

-- lockf 包裹 helper_apply.sh 的调用（不带头进程管理，纯命令串，供测试断言）。
local function apply_command(spec, script, timeout_zero)
	local label = spec.restart_label or ""
	local args = { LOCKF_BIN }
	if timeout_zero then
		args[#args + 1] = "-t"
		args[#args + 1] = "0"
	end
	args[#args + 1] = "-k"
	args[#args + 1] = shell_quote(M.spec_lock_path(spec))
	args[#args + 1] = shell_quote(script)
	args[#args + 1] = shell_quote(spec.build_dir)
	args[#args + 1] = shell_quote(spec.target)
	args[#args + 1] = shell_quote(label)
	args[#args + 1] = shell_quote(M.applied_marker_path(spec))
	args[#args + 1] = shell_quote(M.spec_log_path(spec))
	return table.concat(args, " ")
end

-- 同步构建（missing）：lockf -k 默认无限等待。返回值证明 make+apply 成功。
local function run_sync(spec, script)
	local command = apply_command(spec, script, false) .. "; printf '\\n%s' \"$?\""
	local pipe = io.popen(command)
	if not pipe then return false end
	local output = pipe:read("*a") or ""
	pipe:close()
	return tonumber(output:match("(%d+)%s*$") or "1") == 0
end

function M.compile_sync(spec, script)
	return run_sync(spec, script)
end

-- detached worker：nohup sh -c 'lockf -t 0 -k ...' </dev/null ... &
-- 独立于 Lua callback 生存（不受 SbarLua 60s alarm 影响），busy 时 lockf 以
-- EX_TEMPFAIL(75) 退出即「交由当前 owner 收口」。os.execute 只证明 worker
-- 已启动，不能据此推进 marker。
function M.spawn_worker(spec, script)
	local worker = apply_command(spec, script, true)
	local command = "/usr/bin/nohup /bin/sh -c " .. shell_quote(worker)
		.. " </dev/null >/dev/null 2>&1 &"
	os.execute(command)
end

-- fresh 但带 restart_label 的 spec 仍须 reconcile：digest 与 marker 不一致
-- 说明 kickstart 曾经丢失（或首次升级无 marker），需要重新 apply。
local function digest_matches(spec)
	local pipe = io.popen("/usr/bin/shasum -a 256 " .. shell_quote(spec.target) .. " 2>/dev/null")
	if not pipe then return false end
	local out = pipe:read("*a") or ""
	pipe:close()
	local digest = out:match("^(%x+)")
	if not digest then return false end
	local f = io.open(M.applied_marker_path(spec), "r")
	if not f then return false end
	local content = f:read("*a")
	f:close()
	local applied_label, applied_digest = content:match("^(.-)\n(%x+)\n?$")
	return applied_label == spec.restart_label and applied_digest == digest
end

local function build_missing(specs, script)
	for _, spec in ipairs(specs) do
		if not run_sync(spec, script) then
			io.stderr:write(
				"sketchybar: helper compile failed: " .. spec.id
				.. ", see " .. M.spec_log_path(spec) .. "\n"
			)
		end
	end
end

function M.ensure(cfg)
	local specs = M.specs(cfg)
	local plan = M.plan(specs, M.read_mtimes(specs))
	local script = M.helper_apply_path(cfg)

	-- missing → 同步构建（后续配置可能立即使用二进制）。
	if #plan.sync > 0 then
		build_missing(plan.sync, script)
	end

	-- stale（所有 spec）→ detached worker。
	for _, spec in ipairs(plan.background) do
		M.spawn_worker(spec, script)
	end

	-- fresh 但带 restart_label → 仍须 reconcile marker（即使 target 判 fresh
	-- 也不能跳过：kickstart 可能在上次 reload 时丢失）。
	for _, spec in ipairs(plan.fresh) do
		if spec.restart_label and not digest_matches(spec) then
			M.spawn_worker(spec, script)
		end
	end
end

return M
