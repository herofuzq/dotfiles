local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local helper_build = require("helpers.helper_build")

-- ===== 纯命令面：sync lockf -k（等待）；worker lockf -t 0 -k（busy 即退 75）=====
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
local target = tmp .. "/bin/sentinel"
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

print("helper_build_lock_test: ok")
