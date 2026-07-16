-- ========== Helper 二进制编译管理 ==========
-- 启动时检查 helpers 下 Swift/C 源码是否比 bin/ 产物新，是则在 **CONFIG_DIR** 下 make。
--
-- 重要：产物必须写在 ~/.config/sketchybar/helpers/**/bin/（运行目录）。
-- 不要在 ~/dotfiles/... 树里 make——那会生成第二份 gitignored 的 bin/，
-- launchd 仍执行 $HOME/.config/.../bin/，等于没更新运行中的 daemon。
-- 详见 README「Pitfall — helper bin/」。

local home = os.getenv("HOME")
local config_dir = os.getenv("CONFIG_DIR") or (home and (home .. "/.config/sketchybar")) or "."

-- Lua modules should resolve from the live SketchyBar config directory, not
-- from whatever working directory launchd / sketchybar happens to use.
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path
if home then
	package.cpath = package.cpath .. ";" .. home .. "/.local/share/sketchybar_lua/?.so"
end

-- 最早把 bar 藏起来，并把 height 压到 0：
-- reload 后 internal default 常用错误高度（如 25/32）先画一帧，再被配置改掉，
-- 看起来就是「先闪一条高度不对的 bar」。hidden + height=0 把这条默认条掐掉。
require("helpers.startup").hide()

local cfg = os.getenv("CONFIG_DIR")
if cfg then
	require("helpers.helper_build").ensure(cfg)
end
