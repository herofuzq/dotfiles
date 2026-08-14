local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
if repo_root == "" then
	local pwd = assert(io.popen("pwd"))
	repo_root = assert(pwd:read("*l")) .. "/"
	pwd:close()
end
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local helper_build = require("helpers.helper_build")

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function write_file(path, content)
	local file = assert(io.open(path, "w"))
	file:write(content)
	file:close()
end

local function read_file(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local content = file:read("*a")
	file:close()
	return content
end

local function run(command)
	local pipe = assert(io.popen("{ " .. command .. "; } 2>&1; printf '\\n__RC__=%s' \"$?\""))
	local output = pipe:read("*a") or ""
	pipe:close()
	return tonumber(output:match("__RC__=(%d+)%s*$")), output:gsub("\\n__RC__=%d+%s*$", "")
end

local function assert_equal(actual, expected, message)
	assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- ===== 纯命令面：sync 与 detached worker 都用 lockf -k（等待）=====
local function fake_spec(id, restart_label)
	local spec = { id = id, build_dir = "/tmp/fake_build/" .. id, target = "/tmp/fake_build/" .. id .. "/bin/out" }
	if restart_label then spec.restart_label = restart_label end
	return spec
end
local script = "/tmp/fake_cfg/helpers/helper_apply.sh"

local function build_sync_command(spec)
	-- 通过 compile_sync 的返回无法直接抓到命令串，这里改用 spawn 前断言：
	-- 用内部 apply_command 的非公开性，改为直接断言路径 helper 与 spawn 行为。
	return nil
end

-- 路径 helper：lock/log/marker 都 per-spec
assert(helper_build.spec_lock_path({ id = "alpha" }):find("sketchybar_build_lock.alpha", 1, true), "lock path per-spec")
assert(helper_build.spec_log_path({ id = "alpha" }):find("sketchybar_make.alpha.log", 1, true), "log path per-spec")
assert(helper_build.applied_marker_path({ id = "alpha" }):find("sketchybar_applied.alpha", 1, true), "marker path per-spec")
assert(helper_build.helper_apply_path("/tmp/fake_cfg") == "/tmp/fake_cfg/helpers/helper_apply.sh", "apply script path derived from cfg")

-- ===== 行为：compile_sync 用真实 helper_apply.sh 在锁内跑通一个 fake make =====
local tmp = os.tmpname() .. "_applytest"
os.execute("mkdir -p " .. tmp .. "/bin")
local makefile = tmp .. "/Makefile"
local target = tmp .. "/bin/applytest"
local f = assert(io.open(makefile, "w"))
f:write(([=[
all:
	@printf 'built' > %s
	@chmod +x %s
]=]):format(target, target))
f:close()

-- 无 label 的 spec：只构建，不 apply。
local spec = { id = "applytest", build_dir = tmp, target = target }
local applied_script = repo_root .. "sketchybar/.config/sketchybar/helpers/helper_apply.sh"
assert(helper_build.compile_sync(spec, applied_script) == true, "compile_sync must succeed for a valid fake target")

local compiled = io.open(target, "r")
assert(compiled, "fake make must produce the sentinel target")
compiled:close()

local lockf_file = io.open(helper_build.spec_lock_path(spec), "r")
assert(lockf_file, "lock file must persist after a successful build (-k)")
lockf_file:close()
local log_file = io.open(helper_build.spec_log_path(spec), "r")
assert(log_file, "per-spec log must be written")
local log_content = log_file:read("*a")
log_file:close()
assert(log_content:find("BUILT", 1, true), "no-label apply must log BUILD")

os.execute("rm -rf " .. tmp .. " " .. helper_build.spec_lock_path(spec) .. " " .. helper_build.spec_log_path(spec))

-- ===== helper_compile：owner 自己消化编译期间的源码变化 =====
local compile_script = repo_root .. "sketchybar/.config/sketchybar/helpers/helper_compile.sh"
local fixture = os.tmpname() .. "_helper_compile"
os.remove(fixture)
assert(os.execute("mkdir -p " .. shell_quote(fixture .. "/mutation/bin") .. " " .. shell_quote(fixture .. "/state")))

-- ===== shell lock path 与 helpers.utils.tmp_path 的 TMPDIR 语义完全一致 =====
do
	local lock_dir = fixture .. "/lock_paths"
	assert(os.execute("mkdir -p " .. shell_quote(lock_dir .. "/bin")))
	local fake_lockf = lock_dir .. "/fake_lockf.sh"
	local script_copy = lock_dir .. "/helper_compile.sh"
	local lock_source = lock_dir .. "/source.txt"
	local lock_target = lock_dir .. "/bin/lockprobe"
	write_file(fake_lockf, [[#!/bin/bash
printf '%s' "$2" > "$LOCK_PATH_LOG"
exit 75
]])
	assert(os.execute("chmod +x " .. shell_quote(fake_lockf)))
	local compile_source = assert(read_file(compile_script))
	local replacement_count
	compile_source, replacement_count = compile_source:gsub("/usr/bin/lockf", function() return fake_lockf end)
	assert(replacement_count == 1, "lockf boundary replacement must remain singular")
	write_file(script_copy, compile_source)
	assert(os.execute("chmod +x " .. shell_quote(script_copy)))
	write_file(lock_source, "source")

	local lock_cases = {
		{ name = "unset", prefix = "/usr/bin/env -u TMPDIR", expected = "/tmp/sketchybar_build_lock.lockprobe" },
		{ name = "empty", prefix = "TMPDIR=''", expected = "/sketchybar_build_lock.lockprobe" },
		{ name = "trailing", prefix = "TMPDIR=" .. shell_quote(lock_dir .. "///"),
			expected = lock_dir .. "/sketchybar_build_lock.lockprobe" },
		{ name = "normal", prefix = "TMPDIR=" .. shell_quote(lock_dir),
			expected = lock_dir .. "/sketchybar_build_lock.lockprobe" },
	}
	for _, lock_case in ipairs(lock_cases) do
		local path_log = lock_dir .. "/" .. lock_case.name .. ".path"
		local command = table.concat({
			"LOCK_PATH_LOG=" .. shell_quote(path_log), lock_case.prefix, shell_quote(script_copy),
			"lockprobe", shell_quote(lock_target), "1", shell_quote(lock_source), "--", "/usr/bin/true", "@OUTPUT@",
		}, " ")
		local rc = run(command)
		assert_equal(rc, 75, lock_case.name .. " fake lockf must return its boundary status")
		assert_equal(read_file(path_log), lock_case.expected, lock_case.name .. " TMPDIR lock path mismatch")
	end
end

local mutation_source = fixture .. "/mutation/source.txt"
local mutation_target = fixture .. "/mutation/bin/mutation"
local mutation_compiler = fixture .. "/mutation/fake_compiler.sh"
local mutation_log = fixture .. "/mutation/compile.log"
local mutation_started = fixture .. "/state/mutation.started"
local mutation_release = fixture .. "/state/mutation.release"
local mutation_busy_rc = fixture .. "/state/busy.rc"
write_file(mutation_source, "v1")
write_file(mutation_target, "old")
assert(os.execute("chmod +x " .. shell_quote(mutation_target)))
write_file(mutation_compiler, [[#!/bin/bash
set -u
source_path="$1"
output_path="$2"
captured="$(cat "$source_path")"
printf 'start|%s|%s\n' "$captured" "$output_path" >> "$COMPILE_LOG"
if [ "$captured" = "v1" ]; then
  : > "$COMPILE_STARTED"
  while [ ! -f "$COMPILE_RELEASE" ]; do sleep 0.01; done
fi
printf '%s' "$captured" > "$output_path"
chmod +x "$output_path"
printf 'end|%s|%s\n' "$captured" "$output_path" >> "$COMPILE_LOG"
]])
assert(os.execute("chmod +x " .. shell_quote(mutation_compiler)))

write_file(fixture .. "/mutation/Makefile", ([=[%s: %s Makefile
	@%s mutation %s 1 %s -- %s %s @OUTPUT@
]=]):format(
	mutation_target, mutation_source, shell_quote(compile_script), shell_quote(mutation_target),
	shell_quote(mutation_source), shell_quote(mutation_compiler), shell_quote(mutation_source)
))

local mutation_driver = fixture .. "/mutation/run.sh"
write_file(mutation_driver, ([=[#!/bin/bash
set -u
TMPDIR=%s COMPILE_LOG=%s COMPILE_STARTED=%s COMPILE_RELEASE=%s \
  /usr/bin/make -s -B -C %s %s &
owner=$!
seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -f %s ]; then seen=1; break; fi
  if ! kill -0 "$owner" 2>/dev/null; then break; fi
  sleep 0.01
done
if [ "$seen" -ne 1 ]; then
  wait "$owner"
  exit 91
fi
/usr/bin/lockf -t 0 -k %s /usr/bin/true
printf '%%s' "$?" > %s
printf 'v2' > %s
: > %s
wait "$owner"
]=]):format(
	shell_quote(fixture .. "/state/"),
	shell_quote(mutation_log),
	shell_quote(mutation_started),
	shell_quote(mutation_release),
	shell_quote(fixture .. "/mutation"),
	shell_quote(mutation_target),
	shell_quote(mutation_started),
	shell_quote(fixture .. "/state/sketchybar_build_lock.mutation"),
	shell_quote(mutation_busy_rc),
	shell_quote(mutation_source),
	shell_quote(mutation_release)
))
assert(os.execute("chmod +x " .. shell_quote(mutation_driver)))

local mutation_rc, mutation_output = run(shell_quote(mutation_driver))
assert_equal(mutation_rc, 0, "source-mutation build must succeed after a stable retry; output=" .. mutation_output)
assert_equal(read_file(mutation_busy_rc), "75", "nonblocking contender must report lock busy")
assert_equal(read_file(mutation_target), "v2", "only the stable source version may be published")

local mutation_stages = {}
for line in assert(read_file(mutation_log)):gmatch("[^\n]+") do
	local phase, version, stage = line:match("^(%a+)|([^|]+)|(.+)$")
	assert(phase and version and stage, "unexpected compile trace: " .. line)
	if phase == "start" then mutation_stages[#mutation_stages + 1] = stage end
end
assert_equal(#mutation_stages, 2, "source change must cause exactly one bounded retry")
assert(mutation_stages[1] ~= mutation_stages[2], "each compile attempt must use a unique staging path")
for _, stage in ipairs(mutation_stages) do
	assert(stage:match("^" .. mutation_target:match("^(.*)/[^/]+$"):gsub("([^%w])", "%%%1") .. "/"),
		"staging file must be target-adjacent: " .. stage)
	assert(stage ~= mutation_target .. ".new", "fixed target.new staging is forbidden")
	assert(read_file(stage) == nil, "staging file must be cleaned after publication: " .. stage)
end

-- ===== 控制依赖变化必须重进 make，不能复用旧 recipe/flags =====
local control_dir = fixture .. "/control"
assert(os.execute("mkdir -p " .. shell_quote(control_dir .. "/bin") .. " " .. shell_quote(control_dir .. "/state")))
local control_source = control_dir .. "/source.txt"
local control_target = control_dir .. "/bin/control"
local control_compiler = control_dir .. "/fake_compiler.sh"
local control_trace = control_dir .. "/trace.log"
local control_started = control_dir .. "/state/started"
local control_release = control_dir .. "/state/release"
local control_blocked = control_dir .. "/state/blocked-once"
write_file(control_source, "content")
write_file(control_target, "old")
assert(os.execute("chmod +x " .. shell_quote(control_target)))
write_file(control_compiler, [[#!/bin/bash
set -u
flag="$1"
output_path="$3"
printf '%s\n' "$flag" >> "$CONTROL_TRACE"
if [ "$flag" = "v1" ] && [ ! -f "$CONTROL_BLOCKED" ]; then
  : > "$CONTROL_BLOCKED"
  : > "$CONTROL_STARTED"
  while [ ! -f "$CONTROL_RELEASE" ]; do sleep 0.01; done
fi
printf '%s' "$flag" > "$output_path"
chmod +x "$output_path"
]])
assert(os.execute("chmod +x " .. shell_quote(control_compiler)))

local function control_makefile(flag)
	return ([=[%s: %s Makefile
	@%s control %s 2 %s Makefile -- %s %s %s @OUTPUT@
]=]):format(
		control_target, control_source, shell_quote(compile_script), shell_quote(control_target),
		shell_quote(control_source), shell_quote(control_compiler), flag, shell_quote(control_source)
	)
end
write_file(control_dir .. "/Makefile", control_makefile("v1"))
write_file(control_dir .. "/Makefile.v2", control_makefile("v2"))

local control_driver = control_dir .. "/run.sh"
write_file(control_driver, ([=[#!/bin/bash
set -u
TMPDIR=%s CONTROL_TRACE=%s CONTROL_BLOCKED=%s CONTROL_STARTED=%s CONTROL_RELEASE=%s \
  /usr/bin/make -s -B -C %s %s &
owner=$!
seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -f %s ]; then seen=1; break; fi
  if ! kill -0 "$owner" 2>/dev/null; then break; fi
  sleep 0.01
done
if [ "$seen" -ne 1 ]; then
  wait "$owner"
  exit 93
fi
cp %s %s
: > %s
wait "$owner"
]=]):format(
	shell_quote(fixture .. "/state/"), shell_quote(control_trace), shell_quote(control_blocked),
	shell_quote(control_started), shell_quote(control_release), shell_quote(control_dir), shell_quote(control_target),
	shell_quote(control_started), shell_quote(control_dir .. "/Makefile.v2"), shell_quote(control_dir .. "/Makefile"),
	shell_quote(control_release)
))
assert(os.execute("chmod +x " .. shell_quote(control_driver)))

local control_rc, control_output = run(shell_quote(control_driver))
assert_equal(control_rc, 0, "control-dependency rebuild must complete; output=" .. control_output)
assert_equal(read_file(control_target), "v2", "makefile change must rebuild with freshly expanded v2 flags")
assert_equal(read_file(control_trace), "v1\nv2\n", "retry must re-enter make instead of reusing v1 compiler argv")

-- ===== 连续变化最多尝试三次，之后保留旧 target 并返回失败 =====
local bounded_dir = fixture .. "/bounded"
assert(os.execute("mkdir -p " .. shell_quote(bounded_dir .. "/bin")))
local bounded_source = bounded_dir .. "/source.txt"
local bounded_target = bounded_dir .. "/bin/bounded"
local bounded_compiler = bounded_dir .. "/fake_compiler.sh"
local bounded_trace = bounded_dir .. "/trace.log"
write_file(bounded_source, "0")
write_file(bounded_target, "old")
assert(os.execute("chmod +x " .. shell_quote(bounded_target)))
write_file(bounded_compiler, [[#!/bin/bash
set -u
value="$(cat "$1")"
printf '%s|%s\n' "$value" "$2" >> "$BOUNDED_TRACE"
if [ "$value" -lt 3 ]; then printf '%s' "$((value + 1))" > "$1"; fi
printf '%s' "$value" > "$2"
chmod +x "$2"
]])
assert(os.execute("chmod +x " .. shell_quote(bounded_compiler)))
write_file(bounded_dir .. "/Makefile", ([=[%s: %s Makefile
	@%s bounded %s 1 %s -- %s %s @OUTPUT@
]=]):format(
	bounded_target, bounded_source, shell_quote(compile_script), shell_quote(bounded_target),
	shell_quote(bounded_source), shell_quote(bounded_compiler), shell_quote(bounded_source)
))
local bounded_rc = run(table.concat({
	"TMPDIR=" .. shell_quote(fixture .. "/state/"),
	"BOUNDED_TRACE=" .. shell_quote(bounded_trace),
	"/usr/bin/make", "-s", "-B", "-C", shell_quote(bounded_dir), shell_quote(bounded_target),
}, " "))
assert(bounded_rc ~= 0, "continuous source changes must stop after the bounded retry count")
assert_equal(read_file(bounded_target), "old", "bounded retry exhaustion must preserve previous target")
local bounded_attempts = 0
for line in assert(read_file(bounded_trace)):gmatch("[^\n]+") do
	bounded_attempts = bounded_attempts + 1
	local stage = assert(line:match("^[^|]+|(.+)$"))
	assert(read_file(stage) == nil, "bounded retry must clean discarded stage " .. stage)
end
assert_equal(bounded_attempts, 3, "continuous changes must compile exactly three attempts")

-- ===== post-hash 到 publish 间的保存必须恢复旧 target 后重进 make =====
local post_dir = fixture .. "/post_publish"
assert(os.execute("mkdir -p " .. shell_quote(post_dir .. "/bin") .. " " .. shell_quote(post_dir .. "/fakebin")))
local post_source = post_dir .. "/source.txt"
local post_target = post_dir .. "/bin/post_publish"
local post_compiler = post_dir .. "/fake_compiler.sh"
local post_trace = post_dir .. "/trace.log"
local post_mutated = post_dir .. "/mutated-once"
write_file(post_source, "v1")
write_file(post_target, "old")
assert(os.execute("chmod +x " .. shell_quote(post_target)))
write_file(post_compiler, [[#!/bin/bash
set -u
captured="$(cat "$1")"
current="$(cat "$POST_TARGET")"
printf '%s|%s\n' "$captured" "$current" >> "$POST_TRACE"
printf '%s' "$captured" > "$2"
chmod +x "$2"
]])
assert(os.execute("chmod +x " .. shell_quote(post_compiler)))
write_file(post_dir .. "/fakebin/mv", [[#!/bin/bash
set -u
if [ ! -f "$POST_MUTATED" ]; then
  printf 'v2' > "$POST_SOURCE"
  : > "$POST_MUTATED"
fi
exec /bin/mv "$@"
]])
assert(os.execute("chmod +x " .. shell_quote(post_dir .. "/fakebin/mv")))
write_file(post_dir .. "/Makefile", ([=[%s: %s Makefile
	@%s post_publish %s 2 %s Makefile -- %s %s @OUTPUT@
]=]):format(
	post_target, post_source, shell_quote(compile_script), shell_quote(post_target), shell_quote(post_source),
	shell_quote(post_compiler), shell_quote(post_source)
))

local post_rc, post_output = run(table.concat({
	"PATH=" .. shell_quote(post_dir .. "/fakebin") .. ":$PATH",
	"TMPDIR=" .. shell_quote(fixture .. "/state/"),
	"POST_SOURCE=" .. shell_quote(post_source),
	"POST_TARGET=" .. shell_quote(post_target),
	"POST_TRACE=" .. shell_quote(post_trace),
	"POST_MUTATED=" .. shell_quote(post_mutated),
	"/usr/bin/make", "-s", "-B", "-C", shell_quote(post_dir), shell_quote(post_target),
}, " "))
assert_equal(post_rc, 0, "post-publish source change must be recovered; output=" .. post_output)
assert_equal(read_file(post_target), "v2", "post-publish validation must replace the raced v1 output with v2")
assert_equal(read_file(post_trace), "v1|old\nv2|old\n",
	"raced publish must restore the old target before the v2 recompile")

-- ===== spec id 必须绑定同名 target，错误 recipe 不能借错锁发布 =====
local binding_dir = fixture .. "/binding"
assert(os.execute("mkdir -p " .. shell_quote(binding_dir .. "/bin")))
local binding_source = binding_dir .. "/source.txt"
local binding_target = binding_dir .. "/bin/actual"
local binding_compiler = binding_dir .. "/fake_compiler.sh"
local binding_called = binding_dir .. "/compiler-called"
write_file(binding_source, "source")
write_file(binding_target, "old")
assert(os.execute("chmod +x " .. shell_quote(binding_target)))
write_file(binding_compiler, [[#!/bin/bash
: > "$BINDING_CALLED"
printf 'wrong' > "$2"
chmod +x "$2"
]])
assert(os.execute("chmod +x " .. shell_quote(binding_compiler)))
write_file(binding_dir .. "/Makefile", ([=[.PHONY: all
all:
	@%s wrong_id %s 1 %s -- %s %s @OUTPUT@
]=]):format(
	shell_quote(compile_script), shell_quote(binding_target), shell_quote(binding_source),
	shell_quote(binding_compiler), shell_quote(binding_source)
))
local binding_rc = run(table.concat({
	"TMPDIR=" .. shell_quote(fixture .. "/state/"),
	"BINDING_CALLED=" .. shell_quote(binding_called),
	"/usr/bin/make", "-s", "-C", shell_quote(binding_dir),
}, " "))
assert(binding_rc ~= 0, "wrong spec-id/target binding must be rejected")
assert(read_file(binding_called) == nil, "wrong binding must be rejected before compiler execution")
assert_equal(read_file(binding_target), "old", "wrong binding must preserve target")

-- ===== manual make 与 automatic helper_apply 共用同一把 spec lock =====
local serial_dir = fixture .. "/serial"
assert(os.execute("mkdir -p " .. shell_quote(serial_dir .. "/bin") .. " " .. shell_quote(serial_dir .. "/state")))
local serial_source = serial_dir .. "/source.txt"
local serial_target = serial_dir .. "/bin/serialize"
local serial_compiler = serial_dir .. "/fake_compiler.sh"
local serial_trace = serial_dir .. "/trace.log"
local serial_overlap = serial_dir .. "/overlap"
local serial_started = serial_dir .. "/state/manual.started"
local serial_marker = serial_dir .. "/marker"
local serial_apply_log = serial_dir .. "/apply.log"
write_file(serial_source, "stable")
write_file(serial_compiler, [[#!/bin/bash
set -u
source_path="$1"
output_path="$2"
if ! mkdir "$ACTIVE_DIR" 2>/dev/null; then : > "$OVERLAP_FILE"; fi
printf 'start|%s|%s\n' "$BUILD_ROLE" "$output_path" >> "$COMPILE_LOG"
: > "$START_DIR/$BUILD_ROLE.started"
sleep 0.20
cat "$source_path" > "$output_path"
chmod +x "$output_path"
printf 'end|%s|%s\n' "$BUILD_ROLE" "$output_path" >> "$COMPILE_LOG"
rmdir "$ACTIVE_DIR" 2>/dev/null || true
]])
assert(os.execute("chmod +x " .. shell_quote(serial_compiler)))

write_file(serial_dir .. "/Makefile", ([=[BUILD_ROLE ?= automatic
.PHONY: all
all:
	@BUILD_ROLE=$(BUILD_ROLE) COMPILE_LOG=%s ACTIVE_DIR=%s OVERLAP_FILE=%s START_DIR=%s \
	  %s serialize %s 1 %s -- %s %s @OUTPUT@
]=]):format(
	shell_quote(serial_trace), shell_quote(serial_dir .. "/active"), shell_quote(serial_overlap),
	shell_quote(serial_dir .. "/state"), shell_quote(compile_script), shell_quote(serial_target),
	shell_quote(serial_source), shell_quote(serial_compiler), shell_quote(serial_source)
))

local serial_driver = serial_dir .. "/run.sh"
write_file(serial_driver, ([=[#!/bin/bash
set -u
TMPDIR=%s BUILD_ROLE=manual COMPILE_LOG=%s ACTIVE_DIR=%s OVERLAP_FILE=%s START_DIR=%s \
  /usr/bin/make -s -C %s &
manual=$!
seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -f %s ]; then seen=1; break; fi
  if ! kill -0 "$manual" 2>/dev/null; then break; fi
  sleep 0.01
done
if [ "$seen" -ne 1 ]; then
  wait "$manual"
  exit 92
fi
TMPDIR=%s /usr/bin/lockf -k %s %s serialize %s %s '' %s %s &
automatic=$!
wait "$manual"
manual_rc=$?
wait "$automatic"
automatic_rc=$?
[ "$manual_rc" -eq 0 ] && [ "$automatic_rc" -eq 0 ]
]=]):format(
	shell_quote(fixture .. "/state/"), shell_quote(serial_trace), shell_quote(serial_dir .. "/active"),
	shell_quote(serial_overlap), shell_quote(serial_dir .. "/state"), shell_quote(serial_dir),
	shell_quote(serial_started), shell_quote(fixture .. "/state/"),
	shell_quote(fixture .. "/state/sketchybar_build_lock.serialize"), shell_quote(applied_script),
	shell_quote(serial_dir), shell_quote(serial_target), shell_quote(serial_marker), shell_quote(serial_apply_log)
))
assert(os.execute("chmod +x " .. shell_quote(serial_driver)))

local serial_rc, serial_output = run(shell_quote(serial_driver))
assert_equal(serial_rc, 0, "manual and automatic builds must both complete; output=" .. serial_output)
assert(read_file(serial_overlap) == nil, "manual and automatic compile sections must never overlap")
local serial_lines = {}
local serial_stages = {}
for line in assert(read_file(serial_trace)):gmatch("[^\n]+") do
	serial_lines[#serial_lines + 1] = line
	local phase, _, stage = line:match("^(%a+)|([^|]+)|(.+)$")
	if phase == "start" then serial_stages[#serial_stages + 1] = stage end
end
assert_equal(table.concat(serial_lines, "\n"):match("^(.-)\nend|manual") and serial_lines[1]:match("start|manual"),
	"start|manual", "manual owner must finish before automatic compiler starts")
assert_equal(#serial_stages, 2, "both serialized builds must compile")
assert(serial_stages[1] ~= serial_stages[2], "serialized builds must still use unique staging files")

-- ===== detached automatic worker 必须等待 manual owner，再完成 apply =====
do
	local wait_dir = fixture .. "/worker_wait"
	local wait_state = fixture .. "/state"
	local wait_fakebin = wait_dir .. "/fakebin"
	assert(os.execute("mkdir -p " .. shell_quote(wait_dir .. "/bin") .. " " .. shell_quote(wait_fakebin)))
	local wait_id = "worker_wait"
	local wait_label = "com.test.worker_wait"
	local wait_source = wait_dir .. "/source.txt"
	local wait_target = wait_dir .. "/bin/" .. wait_id
	local wait_compiler = wait_dir .. "/fake_compiler.sh"
	local wait_trace = wait_dir .. "/compile.log"
	local wait_active = wait_dir .. "/active"
	local wait_overlap = wait_dir .. "/overlap"
	local wait_started = wait_dir .. "/manual.started"
	local wait_release = wait_dir .. "/manual.release"
	local wait_launch_log = wait_dir .. "/launchctl.log"
	local wait_pre_release = wait_dir .. "/pre_release_apply"
	local wait_marker_seen = wait_dir .. "/marker_seen"
	local wait_spawn_lua = wait_dir .. "/spawn_worker.lua"
	local wait_driver = wait_dir .. "/run.sh"
	local wait_lock = wait_state .. "/sketchybar_build_lock." .. wait_id
	local wait_marker = wait_state .. "/sketchybar_applied." .. wait_id
	local wait_worker_log = wait_state .. "/sketchybar_make." .. wait_id .. ".log"

	write_file(wait_source, "stable")
	write_file(wait_target, "old-target")
	assert(os.execute("chmod +x " .. shell_quote(wait_target)))
	write_file(wait_compiler, [[#!/bin/bash
set -u
if ! mkdir "$WAIT_ACTIVE" 2>/dev/null; then : > "$WAIT_OVERLAP"; fi
printf '%s|%s\n' "$BUILD_ROLE" "$2" >> "$WAIT_TRACE"
: > "$WAIT_STARTED"
while [ ! -f "$WAIT_RELEASE" ]; do sleep 0.01; done
printf 'new-target' > "$2"
chmod +x "$2"
rmdir "$WAIT_ACTIVE" 2>/dev/null || true
]])
	assert(os.execute("chmod +x " .. shell_quote(wait_compiler)))
	write_file(wait_fakebin .. "/launchctl", [[#!/bin/bash
set -u
printf '%s\n' "$*" >> "$WAIT_LAUNCH_LOG"
exit 0
]])
	assert(os.execute("chmod +x " .. shell_quote(wait_fakebin .. "/launchctl")))
	write_file(wait_dir .. "/Makefile", ([=[BUILD_ROLE ?= automatic
%s: %s Makefile %s
	@WAIT_ACTIVE=%s WAIT_OVERLAP=%s WAIT_TRACE=%s WAIT_STARTED=%s WAIT_RELEASE=%s BUILD_ROLE=$(BUILD_ROLE) \
	  %s %s %s 3 %s Makefile %s -- %s %s @OUTPUT@
]=]):format(
		wait_target, wait_source, compile_script,
		shell_quote(wait_active), shell_quote(wait_overlap), shell_quote(wait_trace), shell_quote(wait_started),
		shell_quote(wait_release), shell_quote(compile_script), wait_id, shell_quote(wait_target),
		shell_quote(wait_source), shell_quote(compile_script), shell_quote(wait_compiler), shell_quote(wait_source)
	))
	write_file(wait_spawn_lua, ([=[package.path = %q .. package.path
local helper_build = require("helpers.helper_build")
helper_build.spawn_worker({
	id = %q,
	build_dir = %q,
	target = %q,
	restart_label = %q,
}, %q)
]=]):format(
		repo_root .. "sketchybar/.config/sketchybar/?.lua;", wait_id, wait_dir, wait_target,
		wait_label, applied_script
	))
	write_file(wait_driver, ([=[#!/bin/bash
set -u
release=%s
manual=''
cleanup() {
  : > "$release"
  if [ -n "$manual" ]; then wait "$manual" 2>/dev/null || true; fi
}
trap cleanup EXIT
TMPDIR=%s /usr/bin/make -s -B -C %s BUILD_ROLE=manual %s &
manual=$!
seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -f %s ]; then seen=1; break; fi
  if ! kill -0 "$manual" 2>/dev/null; then break; fi
  sleep 0.01
done
if [ "$seen" -ne 1 ]; then exit 95; fi
TMPDIR=%s PATH=%s:$PATH WAIT_LAUNCH_LOG=%s /opt/homebrew/bin/lua %s || exit 96
worker_launched=0
for ((probe=0; probe<100; probe++)); do
  if [ -e %s ]; then worker_launched=1; break; fi
  sleep 0.01
done
if [ "$worker_launched" -ne 1 ]; then exit 97; fi
if [ -e %s ] || [ -s %s ]; then printf '1' > %s; else printf '0' > %s; fi
: > "$release"
wait "$manual"
manual=''
marker_seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -f %s ]; then marker_seen=1; break; fi
  sleep 0.01
done
printf '%%s' "$marker_seen" > %s
if [ "$marker_seen" -eq 1 ]; then
  for ((probe=0; probe<300; probe++)); do
    if /usr/bin/lockf -t 0 -k %s /usr/bin/true; then break; fi
    sleep 0.01
  done
fi
]=]):format(
		shell_quote(wait_release), shell_quote(wait_state), shell_quote(wait_dir), shell_quote(wait_target),
		shell_quote(wait_started), shell_quote(wait_state), shell_quote(wait_fakebin), shell_quote(wait_launch_log),
		shell_quote(wait_spawn_lua), shell_quote(wait_worker_log), shell_quote(wait_marker),
		shell_quote(wait_launch_log), shell_quote(wait_pre_release), shell_quote(wait_pre_release),
		shell_quote(wait_marker), shell_quote(wait_marker_seen), shell_quote(wait_lock)
	))
	assert(os.execute("chmod +x " .. shell_quote(wait_driver)))

	local wait_rc, wait_output = run(shell_quote(wait_driver))
	assert_equal(wait_rc, 0, "manual-owner worker driver must complete; output=" .. wait_output)
	assert_equal(read_file(wait_pre_release), "0", "automatic worker must not apply while manual owner holds the lock")
	assert(read_file(wait_overlap) == nil, "automatic worker must not enter the compile section concurrently")
	assert_equal(read_file(wait_marker_seen), "1", "detached worker must remain queued until manual owner releases the lock")
	assert_equal(read_file(wait_target), "new-target", "manual owner must publish the new executable")
	local wait_trace_content = assert(read_file(wait_trace))
	assert(wait_trace_content:match("^manual|[^\n]+\n?$"), "manual build must be the only compile")
	local wait_trace_lines = 0
	for _ in wait_trace_content:gmatch("[^\n]+") do wait_trace_lines = wait_trace_lines + 1 end
	assert_equal(wait_trace_lines, 1, "automatic apply must observe the manual target as fresh and skip recompilation")
	local launches = assert(read_file(wait_launch_log))
	local launch_count = 0
	for _ in launches:gmatch("[^\n]+") do launch_count = launch_count + 1 end
	assert_equal(launch_count, 1, "queued automatic apply must kickstart exactly once")
	assert(launches:find(wait_label, 1, true), "kickstart must use the queued spec label")
	local digest_rc, digest_output = run("/usr/bin/shasum -a 256 " .. shell_quote(wait_target))
	assert_equal(digest_rc, 0, "published target digest must be readable")
	local wait_digest = assert(digest_output:match("^(%x+)"))
	assert_equal(read_file(wait_marker), wait_label .. "\n" .. wait_digest .. "\n",
		"queued automatic apply must atomically record the published target digest")
end

-- ===== compile/hash/temp/rename failure 都保留旧 target =====
local failure_root = fixture .. "/failures"
assert(os.execute("mkdir -p " .. shell_quote(failure_root)))
local function run_failure_case(name, compiler_body, before_command, after_command)
	local dir = failure_root .. "/" .. name
	assert(os.execute("mkdir -p " .. shell_quote(dir .. "/bin")))
	local source_path = dir .. "/source.txt"
	local target_path = dir .. "/bin/" .. name
	local compiler_path = dir .. "/compiler.sh"
	local staging_log = dir .. "/staging.path"
	write_file(source_path, "source")
	write_file(target_path, "old-target")
	assert(os.execute("chmod +x " .. shell_quote(target_path)))
	write_file(compiler_path, compiler_body)
	assert(os.execute("chmod +x " .. shell_quote(compiler_path)))
	write_file(dir .. "/Makefile", ([=[.PHONY: all
all:
	@%s %s %s 1 %s -- %s %s @OUTPUT@
]=]):format(
		shell_quote(compile_script), name, shell_quote(target_path), shell_quote(source_path),
		shell_quote(compiler_path), shell_quote(source_path)
	))
	if before_command then assert(os.execute(before_command(dir, source_path, target_path))) end
	local command_parts = {
		"TMPDIR=" .. shell_quote(fixture .. "/state/"),
		"FAILURE_STAGE_LOG=" .. shell_quote(staging_log),
		"/usr/bin/make", "-s", "-C", shell_quote(dir),
	}
	if name == "rename_failure" then
		assert(os.execute("mkdir -p " .. shell_quote(dir .. "/fakebin")))
		write_file(dir .. "/fakebin/mv", "#!/bin/bash\nexit 71\n")
		assert(os.execute("chmod +x " .. shell_quote(dir .. "/fakebin/mv")))
		table.insert(command_parts, 1, "PATH=" .. shell_quote(dir .. "/fakebin") .. ":$PATH")
	end
	local rc = run(table.concat(command_parts, " "))
	if after_command then assert(os.execute(after_command(dir, source_path, target_path))) end
	assert(rc ~= 0, name .. " failure must propagate nonzero")
	assert_equal(read_file(target_path), "old-target", name .. " failure must preserve existing target")
	local failed_staging = read_file(staging_log)
	if failed_staging then
		assert(read_file(failed_staging) == nil, name .. " failure must clean its unique staging file")
	end
end

run_failure_case("compiler_failure", [[#!/bin/bash
printf '%s' "$2" > "$FAILURE_STAGE_LOG"
printf 'partial' > "$2"
exit 9
]])

run_failure_case("hash_failure", [[#!/bin/bash
printf 'partial' > "$2"
chmod +x "$2"
rm -f "$1"
exit 0
]])

run_failure_case("temp_failure", [[#!/bin/bash
printf 'unexpected' > "$2"
]], function(dir)
	return "chmod 555 " .. shell_quote(dir .. "/bin")
end, function(dir)
	return "chmod 755 " .. shell_quote(dir .. "/bin")
end)

run_failure_case("rename_failure", [[#!/bin/bash
printf 'new-target' > "$2"
chmod +x "$2"
exit 0
]])

-- ===== TERM 到达 publish-validation 窗口时恢复旧 target 并清理 staging =====
do
	local signal_dir = fixture .. "/signal_cleanup"
	assert(os.execute("mkdir -p " .. shell_quote(signal_dir .. "/bin") .. " "
		.. shell_quote(signal_dir .. "/state") .. " " .. shell_quote(signal_dir .. "/fakebin")))
	local signal_source = signal_dir .. "/source.txt"
	local signal_target = signal_dir .. "/bin/signal_cleanup"
	local signal_compiler = signal_dir .. "/fake_compiler.sh"
	local signal_started = signal_dir .. "/state/started"
	local signal_release = signal_dir .. "/state/release"
	local signal_pid = signal_dir .. "/state/wrapper.pid"
	local signal_stage = signal_dir .. "/state/staging.path"
	local signal_rc_file = signal_dir .. "/state/make.rc"
	write_file(signal_source, "source")
	write_file(signal_target, "old-target")
	assert(os.execute("chmod +x " .. shell_quote(signal_target)))
	write_file(signal_compiler, [[#!/bin/bash
set -u
printf '%s' "$2" > "$SIGNAL_STAGE_FILE"
printf 'new-target' > "$2"
chmod +x "$2"
]])
	assert(os.execute("chmod +x " .. shell_quote(signal_compiler)))
	write_file(signal_dir .. "/fakebin/mv", [[#!/bin/bash
set -u
/bin/mv "$@"
printf '%s' "$PPID" > "$WRAPPER_PID_FILE"
: > "$SIGNAL_STARTED"
while [ ! -f "$SIGNAL_RELEASE" ]; do sleep 0.01; done
exit 0
]])
	assert(os.execute("chmod +x " .. shell_quote(signal_dir .. "/fakebin/mv")))
	write_file(signal_dir .. "/Makefile", ([=[.PHONY: all
all:
	@%s signal_cleanup %s 1 %s -- %s %s @OUTPUT@
]=]):format(
		shell_quote(compile_script), shell_quote(signal_target), shell_quote(signal_source),
		shell_quote(signal_compiler), shell_quote(signal_source)
	))
	local signal_driver = signal_dir .. "/run.sh"
	write_file(signal_driver, ([=[#!/bin/bash
set -u
PATH=%s:$PATH TMPDIR=%s WRAPPER_PID_FILE=%s SIGNAL_STAGE_FILE=%s SIGNAL_STARTED=%s SIGNAL_RELEASE=%s \
  /usr/bin/make -s -C %s &
owner=$!
seen=0
for ((probe=0; probe<300; probe++)); do
  if [ -s %s ] && [ -f %s ]; then seen=1; break; fi
  if ! kill -0 "$owner" 2>/dev/null; then break; fi
  sleep 0.01
done
if [ "$seen" -ne 1 ]; then
  wait "$owner"
  exit 94
fi
kill -TERM "$(cat %s)"
: > %s
wait "$owner"
printf '%%s' "$?" > %s
exit 0
]=]):format(
		shell_quote(signal_dir .. "/fakebin"), shell_quote(fixture .. "/state/"), shell_quote(signal_pid), shell_quote(signal_stage),
		shell_quote(signal_started), shell_quote(signal_release), shell_quote(signal_dir),
		shell_quote(signal_pid), shell_quote(signal_started), shell_quote(signal_pid),
		shell_quote(signal_release), shell_quote(signal_rc_file)
	))
	assert(os.execute("chmod +x " .. shell_quote(signal_driver)))
	local driver_rc, driver_output = run(shell_quote(signal_driver))
	assert_equal(driver_rc, 0, "signal cleanup driver must complete; output=" .. driver_output)
	assert(tonumber(read_file(signal_rc_file)) ~= 0, "TERM must make the owning make fail")
	assert_equal(read_file(signal_target), "old-target", "TERM during publish validation must restore previous target")
	local interrupted_stage = assert(read_file(signal_stage))
	assert(read_file(interrupted_stage) == nil, "TERM must clean the interrupted staging file")
	local leftovers = assert(io.popen("find " .. shell_quote(signal_dir .. "/bin")
		.. " -maxdepth 1 -name '.signal_cleanup.previous.*' -print")):read("*a")
	assert(leftovers == "", "TERM must clean the target backup after restoration")
end

-- ===== detached worker 的启动错误进入 per-spec 日志 =====
do
	local id = "missing_worker_" .. tostring(os.time())
	local worker_spec = {
		id = id,
		build_dir = fixture .. "/missing-build-dir",
		target = fixture .. "/missing-target",
	}
	local worker_log = helper_build.spec_log_path(worker_spec)
	os.remove(worker_log)
	helper_build.spawn_worker(worker_spec, fixture .. "/missing-helper-apply.sh")
	for _ = 1, 100 do
		local pending_diagnostic = read_file(worker_log)
		if pending_diagnostic and pending_diagnostic ~= "" then break end
		os.execute("sleep 0.01")
	end
	local diagnostic = read_file(worker_log)
	assert(diagnostic and diagnostic ~= "", "detached launcher failure must be appended to the per-spec log")
	os.remove(worker_log)
	os.remove(helper_build.spec_lock_path(worker_spec))
end

os.execute("rm -rf " .. shell_quote(fixture))

print("helper_build_lock_test: ok")
