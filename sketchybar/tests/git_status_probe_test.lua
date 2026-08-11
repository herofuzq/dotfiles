local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
local config_root = repo_root .. "sketchybar/.config/sketchybar"
local status_script = config_root .. "/helpers/git/status.lua"

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function write_file(path, content)
	local file = assert(io.open(path, "w"))
	assert(file:write(content))
	assert(file:close())
end

local function command_output(command)
	local handle = assert(io.popen(command))
	local output = handle:read("*a") or ""
	local ok, why, code = handle:close()
	assert(ok, string.format("command failed (%s %s): %s", tostring(why), tostring(code), command))
	return output
end

local function command_ok(command)
	local ok, why, code = os.execute(command)
	assert(ok, string.format("command failed (%s %s): %s", tostring(why), tostring(code), command))
end

local function split_fields(line)
	local fields = {}
	for value in (line .. "\t"):gmatch("([^\t]*)\t") do
		fields[#fields + 1] = value
	end
	return fields
end

local function parse_rows(output)
	local rows = {}
	for line in output:gmatch("[^\n]+") do
		local fields = split_fields(line)
		assert(#fields == 8, "helper rows must contain exactly eight fields")
		rows[fields[2]] = fields
	end
	return rows
end

local function line_count(path)
	local file = assert(io.open(path, "r"))
	local count = 0
	for _ in file:lines() do count = count + 1 end
	file:close()
	return count
end

local git = command_output("command -v git"):match("([^\n]+)")
assert(git and git ~= "", "git is required for behavior fixtures")

local temp_root = os.tmpname()
os.remove(temp_root)
command_ok("mkdir -p " .. shell_quote(temp_root))

local function clean_up()
	command_ok("rm -rf " .. shell_quote(temp_root))
end

local function git_command(arguments)
	return table.concat({
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_CONFIG_GLOBAL=/dev/null",
		shell_quote(git),
		arguments,
	}, " ")
end

local function init_repo(path, branch, commit)
	command_ok(git_command("init -q -b " .. shell_quote(branch) .. " " .. shell_quote(path)))
	command_ok(git_command("-C " .. shell_quote(path) .. " config user.name 'SketchyBar Test'"))
	command_ok(git_command("-C " .. shell_quote(path) .. " config user.email 'sketchybar-test@example.invalid'"))
	if commit then
		write_file(path .. "/tracked.txt", "committed\n")
		command_ok(git_command("-C " .. shell_quote(path) .. " add tracked.txt"))
		command_ok(git_command("-C " .. shell_quote(path) .. " commit -q -m fixture"))
	end
end

local function write_config(config_dir, repos)
	command_ok("mkdir -p " .. shell_quote(config_dir .. "/helpers/git"))
	local lines = { "return { repos = {" }
	for _, repo in ipairs(repos) do
		lines[#lines + 1] = string.format("  { path = %q, label = %q },", repo.path, repo.label)
	end
	lines[#lines + 1] = "} }"
	write_file(config_dir .. "/helpers/git/config.lua", table.concat(lines, "\n") .. "\n")
	write_file(config_dir .. "/helpers/find_binary.lua", [[
return { find = function() return assert(os.getenv("TEST_GIT")) end }
]])
end

local function write_git_wrapper(path)
	write_file(path, [[#!/bin/sh
printf '%s\n' "$*" >> "$GIT_CALL_LOG"
if [ "$FAIL_GIT_STATUS" = "1" ]; then
  printf '## main...origin/main [ahead 7]\n M plausible.txt\n'
  exit 128
fi
exec "$REAL_GIT" "$@"
]])
	command_ok("chmod +x " .. shell_quote(path))
end

local function run_helper(config_dir, wrapper, call_log, fail_status)
	write_file(call_log, "")
	local command = table.concat({
		"HOME=" .. shell_quote(temp_root .. "/home"),
		"CONFIG_DIR=" .. shell_quote(config_dir),
		"LUA_PATH=" .. shell_quote(config_root .. "/?.lua;" .. config_root .. "/?/init.lua;;"),
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_CONFIG_GLOBAL=/dev/null",
		"TEST_GIT=" .. shell_quote(wrapper),
		"REAL_GIT=" .. shell_quote(git),
		"GIT_CALL_LOG=" .. shell_quote(call_log),
		"FAIL_GIT_STATUS=" .. (fail_status and "1" or "0"),
		"lua",
		shell_quote(status_script),
	}, " ")
	return command_output(command)
end

local ok, err = xpcall(function()
	local clean = temp_root .. "/clean repo"
	local dirty = temp_root .. "/dirty repo"
	local unborn = temp_root .. "/unborn repo"
	local linked = temp_root .. "/linked worktree"
	local missing = temp_root .. "/missing repo"
	init_repo(clean, "main", true)
	init_repo(dirty, "dirty-branch", true)
	write_file(dirty .. "/untracked.txt", "dirty\n")
	init_repo(unborn, "unborn-exact", false)
	command_ok(git_command("-C " .. shell_quote(clean) .. " worktree add -q -b linked-branch " .. shell_quote(linked)))

	local config_dir = temp_root .. "/config"
	local wrapper = temp_root .. "/git-wrapper"
	local call_log = temp_root .. "/git-calls.log"
	local repos = {
		{ path = clean, label = "clean" },
		{ path = dirty, label = "dirty" },
		{ path = missing, label = "missing" },
		{ path = unborn, label = "unborn" },
		{ path = linked, label = "linked" },
	}
	write_config(config_dir, repos)
	write_git_wrapper(wrapper)

	local rows = parse_rows(run_helper(config_dir, wrapper, call_log, false))
	assert(line_count(call_log) == #repos, "helper must launch exactly one git process per configured repository")
	local log_file = assert(io.open(call_log, "r"))
	for line in log_file:lines() do
		assert(line:match(" status %-%-porcelain=v1 %-b$"), "each repository process must be git status --porcelain=v1 -b")
	end
	log_file:close()

	assert(table.concat(rows[clean], "|") == table.concat({ "repo", clean, "clean", "main", "ok", "0", "0", "0" }, "|"))
	assert(table.concat(rows[dirty], "|") == table.concat({ "repo", dirty, "dirty", "dirty-branch", "dirty", "1", "0", "0" }, "|"))
	assert(table.concat(rows[missing], "|") == table.concat({ "repo", missing, "missing", "-", "error", "-", "-", "-" }, "|"))
	assert(table.concat(rows[unborn], "|") == table.concat({ "repo", unborn, "unborn", "unborn-exact", "ok", "0", "0", "0" }, "|"))
	assert(table.concat(rows[linked], "|") == table.concat({ "repo", linked, "linked", "linked-branch", "ok", "0", "0", "0" }, "|"))

	local failure_config = temp_root .. "/failure-config"
	write_config(failure_config, { { path = clean, label = "clean" } })
	local failed_rows = parse_rows(run_helper(failure_config, wrapper, call_log, true))
	assert(line_count(call_log) == 1, "nonzero fixture must still use one git process")
	assert(
		table.concat(failed_rows[clean], "|") == table.concat({ "repo", clean, "clean", "-", "error", "-", "-", "-" }, "|"),
		"nonzero git status must reject valid-looking stdout"
	)
end, debug.traceback)

clean_up()
assert(ok, err)

print("git_status_probe_test: ok")
