local path = "sketchybar/.config/sketchybar/helpers/git/status.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()

assert(not source:find('".git/HEAD"', 1, true), "git probe must not assume .git is a directory")
assert(source:find("rev-parse --is-inside-work-tree", 1, true), "git probe must use rev-parse for worktrees")

print("git_status_probe_test: ok")
