local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local helper_build = require("helpers.helper_build")

-- ===== 纯命令面：sync 用 lockf -k（等待）、stale 用 -t 0 -k（busy 即退 75）=====
local function fake_spec(id)
	return { id = id, build_dir = "/tmp/fake_build/" .. id }
end

local sync_cmd = helper_build.build_command_for(fake_spec("alpha"), false)
assert(sync_cmd:sub(1, #"/usr/bin/lockf ") == "/usr/bin/lockf ", "sync command must start with lockf")
assert(sync_cmd:find("-k ", 1, true), "sync command must pass -k")
assert(not sync_cmd:find("-t ", 1, true), "sync (missing) must wait indefinitely, no -t")
assert(sync_cmd:find("sketchybar_build_lock.alpha", 1, true), "lock path must be per-spec")
assert(sync_cmd:find("sketchybar_make.alpha.log", 1, true), "log path must be per-spec")
assert(not sync_cmd:find("sketchybar_build_lock.beta", 1, true), "lock must not leak across specs")

local stale_cmd = helper_build.build_command_for(fake_spec("beta"), true)
assert(stale_cmd:find("-t ", 1, true), "stale command must set a timeout")
assert(stale_cmd:find("-t 0 ", 1, true), "stale command must use -t 0 (fail immediate if busy)")
assert(stale_cmd:find("-k ", 1, true), "stale command must also pass -k (keep lock file)")

-- ===== 行为：compile_sync 真正在锁内跑通一个 fake make =====
local tmp = os.tmpname() .. "_locktest"
os.execute("mkdir -p " .. tmp)
local makefile = tmp .. "/Makefile"
local target = tmp .. "/sentinel"
local f = assert(io.open(makefile, "w"))
f:write(([=[
all:
	@printf 'built' > %s
]=]):format(target))
f:close()

local spec = { id = "locktest", build_dir = tmp }
assert(helper_build.compile_sync(spec) == true, "compile_sync must succeed for a valid fake target")

local compiled = io.open(target, "r")
assert(compiled, "fake make must produce the sentinel target")
compiled:close()

-- 锁文件必须存在且保留（-k 语义），日志必须已生成。
local lock_path = helper_build.spec_lock_path(spec)
local log_path = helper_build.spec_log_path(spec)
local lockf_file = io.open(lock_path, "r")
assert(lockf_file, "lock file must persist after a successful build (-k)")
lockf_file:close()
local log_file = io.open(log_path, "r")
assert(log_file, "per-spec log must be written")
log_file:close()

-- 清理临时 fake target（不触碰任何真实 helper）。
os.execute("rm -rf " .. tmp .. " " .. lock_path .. " " .. log_path)

print("helper_build_lock_test: ok")
