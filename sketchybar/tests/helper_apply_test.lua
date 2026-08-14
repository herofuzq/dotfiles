local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local script = repo_root .. "sketchybar/.config/sketchybar/helpers/helper_apply.sh"

-- ===== 测试脚手架：fake make + fake launchctl =====
local tmp = os.tmpname() .. "_apply"
os.execute("mkdir -p " .. tmp .. "/bin " .. tmp .. "/bin2")
local target = tmp .. "/bin/tool"
local label = "com.test.fake_daemon"
local marker = tmp .. "/marker"
local log = tmp .. "/log"

-- fake launchctl：记录调用，exit 由 launchctl_fail 控制。
local launchctl_calls = {}
local launchctl_fail = false
local fake_launchctl = tmp .. "/bin2/launchctl"
local lf = assert(io.open(fake_launchctl, "w"))
lf:write([[
#!/bin/bash
echo "$*" >> "$LAUNCHCTL_LOG"
if [ "$LAUNCHCTL_FAIL" = "1" ]; then exit 1; fi
exit 0
]])
lf:close()
os.execute("chmod +x " .. fake_launchctl)

local PATH_prefix = tmp .. "/bin2"
local function run_apply(make_body, env)
	local makefile = tmp .. "/Makefile"
	local mf = assert(io.open(makefile, "w"))
	mf:write(make_body)
	mf:close()
	local cmd = table.concat({
		"PATH=" .. PATH_prefix .. ":$PATH",
		"LAUNCHCTL_LOG=" .. tmp .. "/launchctl.log",
		"LAUNCHCTL_FAIL=" .. (launchctl_fail and "1" or "0"),
		"bash",
		script,
		string.format("%q", tmp),
		string.format("%q", target),
		string.format("%q", (env and env.label) or ""),
		string.format("%q", marker),
		string.format("%q", log),
	}, " ")
	local handle = io.popen(cmd .. " 2>&1; printf '\\nRC=%s' \"$?\"")
	local out = handle:read("*a")
	handle:close()
	local rc = tonumber(out:match("RC=(%d+)"))
	-- 记录 launchctl 调用次数
	local llog = io.open(tmp .. "/launchctl.log", "r")
	launchctl_calls = {}
	if llog then
		for line in llog:lines() do
			launchctl_calls[#launchctl_calls + 1] = line
		end
		llog:close()
	end
	os.remove(tmp .. "/launchctl.log")
	return rc
end

local function read_marker()
	local f = io.open(marker, "r")
	if not f then return nil end
	local content = f:read("*a")
	f:close()
	return content
end

local MAKE_BODY = ([[
all:
	@printf 'tool-v1' > %s
	@chmod +x %s
]]):format(target, target)

-- ===== 无 label → 只构建，不 kickstart，不写 marker =====
do
	launchctl_fail = false
	local rc = run_apply(MAKE_BODY, { label = "" })
	assert(rc == 0, "no-label apply must exit 0, got " .. tostring(rc))
	assert(#launchctl_calls == 0, "no-label apply must not call launchctl")
	assert(read_marker() == nil, "no-label apply must not write a marker")
end

-- ===== label + mismatch marker → kickstart + 写 marker =====
do
	launchctl_fail = false
	local rc = run_apply(MAKE_BODY, { label = label })
	assert(rc == 0, "apply must exit 0, got " .. tostring(rc))
	assert(#launchctl_calls == 1, "mismatch must kickstart exactly once")
	assert(launchctl_calls[1]:find("kickstart", 1, true) and launchctl_calls[1]:find(label, 1, true),
		"kickstart must target the label")
	local m = read_marker()
	assert(m and m:match("^" .. label .. "\n(%x+)\n?$"), "marker must record label + digest")
end

-- ===== label + digest 已匹配 → no-op，不再 kickstart =====
do
	local rc = run_apply(MAKE_BODY, { label = label })
	assert(rc == 0, "up-to-date apply must exit 0")
	assert(#launchctl_calls == 0, "up-to-date must not re-kickstart")
end

-- ===== kickstart 失败 → 非零，marker 保持不变 =====
do
	-- 先清掉 marker，制造 mismatch
	os.remove(marker)
	launchctl_fail = true
	local rc = run_apply(MAKE_BODY, { label = label })
	assert(rc ~= 0, "kickstart failure must propagate non-zero")
	assert(read_marker() == nil, "kickstart failure must not write the marker")
	launchctl_fail = false
end

os.execute("rm -rf " .. tmp)

print("helper_apply_test: ok")
