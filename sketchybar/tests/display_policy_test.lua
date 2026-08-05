local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)sketchybar/tests/") or ""
package.path = repo_root .. "sketchybar/.config/sketchybar/?.lua;" .. package.path

local policy = require("helpers.display_policy")

-- Idle events must probe first instead of hiding the bar immediately.
assert(policy.classify("idle", 100, 90, nil, 3) == "verify")
assert(policy.classify("idle", 100, 0, nil, 3) == "verify")

-- Events inside the post-reveal grace window are absorbed.
assert(policy.classify("idle", 92, 90, nil, 3) == "absorb")

-- Post-sleep events stay probe-only while the verify window is open.
assert(policy.classify("idle", 100, 90, 105, 3) == "verify_post_sleep")

-- Wake events while sleeping are absorbed until unlock.
assert(policy.classify("sleep_hidden", 100, nil, nil, 3) == "absorb_wake")

-- Settling storms renew the session; revealing ignores late events.
assert(policy.classify("settling", 100, nil, nil, 3) == "renew")
assert(policy.classify("revealing", 100, nil, nil, 3) == "ignore")

print("display_policy_test: ok")
