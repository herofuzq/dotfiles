# 窗口边框（jankyborders）颜色跟随 sketchybar 主题 — 方案 v1.2

日期：2026-07-28。状态：已实施并完成视觉验收。

v1.2 变更：

- 每套 scheme 独立选择一个代表色角色，dark/light 自动取各自色板中的对应颜色。
- jankyborders 不再由 AeroSpace 启动，改由 SketchyBar 在同步确定当前系统深浅主题后直接以正确颜色启动。
- 不采用透明启动、状态文件、pgrep 守卫或延迟补推；SketchyBar 加载和主题切换统一调用 bordersrc。
- 修正命令构造：使用项目现有 `helpers.utils.shell_quote`，不用 Lua `%q` 代替 shell 转义。

v1.1 已落实并继续保留的裁定：

- 热更新不会重写进程 argv，验证使用 A/B 明显色目视，不依赖 `ps aux`。
- jankyborders 不支持随 `sbar.animate` 渐变，主题切换时边框瞬时换色属于正常。

## 背景与问题

jankyborders（窗口外框）当前由 AeroSpace 启动，颜色硬编码：

- `aerospace/.config/aerospace/aerospace.toml:16`：
  `exec-and-forget borders active_color=0xfffab387 inactive_color=0x00000000 width=5.0 hidpi=on order=above`
- `borders/.config/borders/bordersrc`：同样的 `active_color=0xfffab387`（Catppuccin Mocha peach）。
- aerospace.toml 第 12-14 行注释已承认痛点：切主题后窗口外框需手动改这一行。

sketchybar 主题系统（e4735e9 起）有 6 套 scheme × 深浅 flavor，热切换机制完备（注册表 appliers）。
窗口外框是唯一不联动的常驻彩色元素，当前值 mocha peach 在非 catppuccin 主题下明显不搭。

## 已验证的关键事实

- 本机 borders v1.9.0 `man borders`：实例已运行时，再次调用 `borders <args>` 会**更新现有进程**；
  无实例且无参数调用 `borders` 时会自行执行 `~/.config/borders/bordersrc`。→ bordersrc 可做唯一入口。
- 热更新不会重写进程 argv：验证不能靠 `ps aux`，要靠明显色 A/B 切换 + 目视。
- 命名冲突提醒：sketchybar 已有 `helpers/borders.lua`（workspace 高亮，主题阶段二已接入注册表），
  与 jankyborders 无关。本方案新文件命名避开 borders。

## 设计（v1.2）

### 1. 每套 scheme 登记边框代表色

在 `schemes` 表中为每套主题登记一个 palette 色彩角色：

```lua
catppuccin = { dark = "mocha", light = "latte", window_border = "mauve" },
tokyonight = { dark = "tokyonight_storm", light = "tokyonight_day", window_border = "blue" },
rosepine = { dark = "rosepine", light = "rosepine_dawn", window_border = "rosewater" },
everforest = { dark = "everforest_dark", light = "everforest_light", window_border = "green" },
kanagawa = { dark = "kanagawa_wave", light = "kanagawa_lotus", window_border = "blue" },
gruvbox = { dark = "gruvbox_dark", light = "gruvbox_light", window_border = "peach" },
```

`build_colors` 根据当前 scheme 的 `window_border` 读取 `P[key]`，最终仍只向消费者暴露：

```lua
colors.identity.window_border
```

边框 helper 不认识主题名，也不维护第二份映射。inactive_color 恒为 `0x00000000`（透明），不进登记表。

### 2. bordersrc：唯一参数配置源 + 环境变量覆盖

`borders/.config/borders/bordersrc`：

```bash
#!/bin/bash
# 窗口外框唯一参数配置源。SketchyBar 启动/主题切换时通过
# BORDERS_ACTIVE_COLOR 传入准确颜色；手动执行时使用当前默认 scheme 的 dark fallback。
# 改 M.scheme 默认值或它的 window_border 角色时，同步更新 fallback。
active_color="${BORDERS_ACTIVE_COLOR:-0xffa7c080}" # everforest dark green

borders \
  style=round \
  width=5.0 \
  hidpi=on \
  order=above \
  active_color="$active_color" \
  inactive_color=0x00000000
```

删除 `aerospace.toml` 中的 borders 启动行和“手动同步颜色”注释。参数统一采用当前实际运行的
`width=5.0 hidpi=on order=above`，不再分别维护 6.0/5.0 两套值。

### 3. 新 helper：`helpers/window_border.lua`

职责：把当前主题边框色通过 bordersrc 推给 jankyborders。

```lua
-- 伪代码
local shell_quote = require("helpers.utils").shell_quote

local function border_cmd(hex)
    local color = string.format("0x%08x", hex)
    local bordersrc = os.getenv("HOME") .. "/.config/borders/bordersrc"
    return "BORDERS_ACTIVE_COLOR=" .. shell_quote(color) .. " " .. shell_quote(bordersrc)
end

local function apply(C)
    sbar.exec(border_cmd(C.identity.window_border), function() end)
end

appearance.register_colors("window_border", apply)
apply(appearance.colors) -- appearance 已同步确定系统深浅主题，首次调用即使用准确颜色
```

- 热切换：注册即免费获得（switch_theme 遍历 appliers）。
- 启动：borders 未运行时首次推送会直接启动它；运行中则热更新现有实例。
- 自愈：SketchyBar reload 或实际发生的深浅主题切换会恢复意外退出的 borders，无需 pgrep/补推。
- `border_cmd` 独立成纯函数，便于测试命令构造。
- helper 在 `startup.configure()` 内、`appearance.install_defaults()` 后加载。

### 4. 已知限制（接受，不处理）

- 边框瞬时换色：sbar.animate 只作用于 sketchybar 内部元素，jankyborders 换色无渐变。
- SketchyBar 不运行时，不自动启动窗口边框；手动执行 bordersrc 时使用 Everforest dark green fallback。
- borders 在两次 SketchyBar 推送之间意外退出时不会常驻保活；下次 reload 或实际主题切换时自愈。

## 涉及文件

| 文件 | 改动 |
|---|---|
| `sketchybar/.config/sketchybar/appearance.lua` | schemes 增加代表色角色；build_colors 生成 identity.window_border |
| `sketchybar/.config/sketchybar/helpers/window_border.lua` | 新建（~40 行） |
| `sketchybar/.config/sketchybar/init.lua` | 在 startup.configure 内加载 helper |
| `sketchybar/tests/theme_test.lua` | 六套 scheme 代表色、深浅结果及 owner_sources 断言 |
| `sketchybar/tests/`（新或现有测试文件） | border_cmd 命令构造测试（hex 格式、路径转义） |
| `borders/.config/borders/bordersrc` | 重写（env 覆盖 + 统一参数） |
| `aerospace/.config/aerospace/aerospace.toml` | 删除 borders 启动行及过时注释 |

## 验证

1. 自动测试：theme_test 断言六套 scheme 的边框角色，以及 12 个 dark/light flavor 的最终颜色；
   border_cmd 输出格式、环境变量和路径转义正确。全套测试绿 + luac。
2. 手动 A/B：临时把当前 scheme 的 window_border 改成另一现有角色 → reload → 目视窗口边框变色 → 改回。
   不依赖 ps 参数判断。
3. 深浅切换：系统外观切换后边框跟随 flavor（目视）。
4. 冷启动：结束 borders 后 reload SketchyBar，确认由 SketchyBar 以当前准确颜色拉起。
5. scheme 切换：逐套修改 M.scheme + reload，确认使用紫/蓝/玫瑰/绿/蓝/橙（瞬时，无渐变）。
6. AeroSpace reload：确认不再负责启动或改写 borders，窗口边框保持现状。

## 不做

- 不改 jankyborders 的 style/width/hidpi/order 语义（仅收敛到 bordersrc 单文件）。
- 不动 sketchybar 内部 `helpers/borders.lua`。
- 不追求边框换色渐变（外部进程无法实现）。
- 不增加 LaunchAgent/KeepAlive；出现真实频繁崩溃证据后再评估。
