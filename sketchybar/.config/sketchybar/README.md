# SketchyBar Configuration / SketchyBar 配置

[EN](#english) | [中文](#chinese)

---

## English

This is a modular, event-driven SketchyBar configuration written in Lua with a few native Swift/C helpers.

### Runtime Path

This repository is the source copy. After `stow --no-folding sketchybar` (from the dotfiles root), the active runtime lives at `~/.config/sketchybar`.

Compiled helper binaries are not stored in git. They are built under the active runtime path, for example:

- `~/.config/sketchybar/helpers/event_providers/aerospace_watch/bin/aerospace_watch`
- `~/.config/sketchybar/helpers/event_providers/docker_watch/bin/docker_watch`
- `~/.config/sketchybar/helpers/event_providers/input_method/bin/input_method_watch`
- `~/.config/sketchybar/helpers/event_providers/media_watch/bin/media_watch`

When debugging live behavior, inspect `~/.config/sketchybar` first. Source edits in this repo become active through the stow symlink, but helper binaries still need to be rebuilt when their source changes. After adding or changing stow-managed files, re-run `stow --no-folding sketchybar`.

### How It Works

1. `sketchybarrc` loads `helpers/` first. One batched mtime scan skips fresh helpers, builds missing binaries synchronously, and rebuilds stale binaries in the background; the bar starts `hidden` to avoid the default-height flash.
2. `init.lua` runs `begin_config` → appearance defaults, `bar.lua` (still hidden), `items/`.
3. After `end_config`, `helpers/enter_animation.lua` records the fade set; `helpers/startup.lua` reveals the bar immediately, then item foregrounds and explicit backgrounds fade together.
4. `sbar.event_loop()` receives SketchyBar native events and custom triggers from helper daemons.

### Startup fade

| Step | Module | Behavior |
|------|--------|----------|
| `install()` | `enter_animation` | Before `begin_config`, wrap `sbar.add` and record main-bar item names (skip popup rows) |
| `prepare()` | same | After `end_config`, snapshot declared foreground/background colors for tracked main-bar items (bar still hidden) |
| `startup.reveal()` | `startup` | Unhide with transparent bar colors, then animate bar background/border to final alpha (~500ms) |
| `run()` | same | Single linear alpha animate for declared foreground, background, and border colors (~500ms, synchronized with bar) |

- Color fade only: no `y_offset`, no stagger, does not force `drawing=true` or change geometry.
- Popup rows are skipped (`position` starts with `popup`, or names containing `popup` / calendar grid / sys process rows).
- Bar/item timing: `helpers/timing.lua` → `ENTER_BAR_FADE_FRAMES` / `ENTER_ITEM_FADE_FRAMES` (both 30 steps, about 500ms at SketchyBar's 60 steps/s).

Main-bar icon/label colors and explicitly declared background/border colors are made transparent at `sbar.add` time. Only colors are restored, so later `drawing=false` changes used to join a shared bracket remain intact. Initial asynchronous status results are collected in parallel and their latest UI updates are released after the startup fade, preventing ordinary `set` calls from cancelling the animation halfway through.

**Pitfall — wrapping `sbar.add`:** always forward with `raw_add(...)`. Never call `raw_add(kind, name, props, nil)` for a 3-arg `add("item", name, props)`. Passing an explicit `nil` 4th argument makes SbarLua mis-parse the call (treats it like a 4-arg form); popup items can lose `position = "popup.…"` and appear as normal bar items (Docker/Git popup rows flooding the bar). The `install()` wrapper uses varargs on purpose.

**Pitfall — helper `bin/` lives only under the live config dir, not in the git tree:**

| Path | Role |
|------|------|
| `~/dotfiles/sketchybar/...` (repo) | Source: `.lua`, `.swift`, `makefile`, plists (stowed as symlinks) |
| `~/.config/sketchybar` (runtime) | What SketchyBar / launchd actually run; `CONFIG_DIR` points here |
| `~/.config/sketchybar/helpers/**/bin/` | **Compiled binaries only here** (gitignore `bin`; stow does not manage them) |

- Makefiles write to relative `bin/` based on **cwd**. They are not “wrong files”; the bug is running `make` in the **repo** path.
- Correct builds:
  - preferred: `sketchybar --reload` → `helpers/helper_build.lua` builds only missing/stale targets under `$CONFIG_DIR`; stale binaries remain usable during the background build;
  - manual: `cd ~/.config/sketchybar/helpers && make` (or `make -C ~/.config/sketchybar/helpers/event_providers/<name>`).
- Helper recipes compile to `bin/<name>.new` and replace the active binary only after success. Swift recipes share `helpers/swift.mk`; `SKETCHYBAR_SWIFT_SDK` can override its compatible SDK fallback.
- **Wrong:** `make -C ~/dotfiles/sketchybar/.config/sketchybar/helpers/...` — creates a **second** `bin/` under the repo tree. That binary is **not** what launchd loads (`exec $HOME/.config/sketchybar/helpers/.../bin/...`).
- If `bin/` exists under the **dotfiles** checkout, treat it as a mistake: delete those `helpers/**/bin` dirs (they are gitignored) and rebuild under `~/.config`.
- After editing Swift/C: confirm `ls -l ~/.config/sketchybar/helpers/**/bin/` mtimes, then `launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.<agent>` if needed.

### File Map

| Path | Purpose |
|------|---------|
| `sketchybarrc` | Entry: helpers + settings + `init` |
| `init.lua` | `begin_config` / startup fade / `event_loop` |
| `helpers/startup.lua` | Startup hide, batched configuration, and reveal timing |
| `settings.lua` | Bar height, Dock-width detection, and default spacing |
| `appearance.lua` | Catppuccin palette, semantic colors, global defaults |
| `fonts.lua` | Font families and styles |
| `icons.lua` | Shared icon definitions |
| `bar.lua` | Bar-level geometry, blur, background |
| `status_widget.lua` | Factory for app badge counters (WeChat / DingTalk) |
| `items/init.lua` | Item load order |
| `items/apple.lua` | Apple logo + Dock-width padding |
| `items/services.lua` | Notch-left Docker dock + control popup |
| `items/git.lua` | Git dirty summary + repo popup |
| `items/spaces.lua` | AeroSpace workspaces, app icons, focus segment, window popup |
| `items/calendar.lua` | Date/time + month popup |
| `items/widgets/*` | Right-side pills (sys, battery, network, media, …) |
| `helpers/init.lua` | Early startup setup and helper-build entry |
| `helpers/helper_build.lua` | Batched freshness plan, targeted build, and event-provider restart |
| `helpers/swift.mk` | Shared Swift compiler, SDK, and module-cache settings |
| `helpers/enter_animation.lua` | Reload startup alpha fade for main-bar items |
| `helpers/popup_animation.lua` | Popup show/hide alpha helpers |
| `helpers/popup_utils.lua` | Deferred UI updates from popup event callbacks |
| `helpers/borders.lua` | Focused workspace segment styling |
| `helpers/timing.lua` | Shared animation timing constants |
| `helpers/services/*` | Docker compose config / status / control scripts |
| `helpers/git/*` | Watched repos config + status script |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe + fullscreen diff |
| `helpers/event_providers/docker_watch/` | Docker events and bounded availability retry → `services_change` |
| `helpers/event_providers/input_method/` | Input-method watcher |
| `helpers/event_providers/media_watch/` | `media-control stream` watcher |
| `helpers/event_providers/cpu_load/` | CPU % (host_statistics); started from `sys.lua` with pidfile |
| `helpers/event_providers/sys_watch/` | System sensors while sys popup is open (on-demand from `sys.lua`) |
| `helpers/bar_height/` | Native bar-height helper |
| `helpers/dock_width/` | Native Dock-width helper for Apple item spacing |

### Process lifecycle (who starts / who kills)

| Process | How it starts | How it stops / restarts |
|---------|---------------|-------------------------|
| `sketchybar` | brew service / manual / login | `sketchybar --reload` restarts the Lua config process |
| `aerospace_watch`, `docker_watch`, `input_method_watch`, `media_watch` | launchd LaunchAgents (`KeepAlive`) | `helper_build.lua` runs `launchctl kickstart` only after the corresponding binary rebuild succeeds |
| `cpu_load` | `items/widgets/sys.lua` on config load (pidfile under `$TMPDIR`) | killed/replaced on next reload of `sys.lua` |
| `sys_watch` | only while sys popup is open | stopped in popup `on_hidden` |

### Desktop Event Flow

| Producer | Event | Consumer | Purpose |
|----------|-------|----------|---------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | Update focused workspace cache and segment border (no full window query) |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | Refresh full window snapshot after native window create/destroy |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | Refresh after AeroSpace reports a newly detected window |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | Full snapshot + fullscreen mark on the workspace number |
| SketchyBar | `display_change` / `system_woke` | `items/spaces.lua` | Verify-first graded response (see below): pure wake = no-op; height-only = set height, no fade; mapping change = full-bar fade + apply + window refresh |
| `aerospace_watch` | `aerospace_mode_change` | `items/spaces.lua` | Show or hide AeroSpace service-mode indicator |
| `input_method_watch` | `input_method_change` | `items/widgets/input_method.lua` | Sync macOS input source and fcitx5 mode |
| `media_watch` | `media_update` | `items/widgets/media.lua` | Media title and playback state |
| `docker_watch` | `services_change` | `items/services.lua` | Refresh Docker service lamp after container lifecycle events |

### Spaces Widget

`items/spaces.lua` is the only renderer for workspace UI. It keeps a cached AeroSpace window snapshot and redraws workspaces from that snapshot.

- The bar shows one icon per app; the popup lists every window.
- **Workspace focus** updates the red segment + icon/label colors on that workspace only (cheap path, no full window query).
- **Window focus** does not recolor individual app icons on the bar.
- Window create/destroy and fullscreen changes refresh the full snapshot.
- Fullscreen is marked at workspace level with ` <workspace>`, not around the app icon.
- `aerospace_watch` uses AeroSpace 0.21's socket protocol for the tiny fullscreen diff query, with a CLI fallback. Lua still uses `aerospace list-windows` for the full render snapshot.

### Display topology sync (`display_change` / `system_woke`)

Event types are not trusted: topology changes made while asleep (clamshell, unplugging a display during sleep) may only deliver `system_woke`, and `display_change` often fires when nothing needs adjustment. Both events share one verify-first flow in `items/spaces.lua`:

- Probe at 0.25s / 1.25s with generation + round token (stale callbacks from a slow earlier round are dropped): bar height via the `bar_height` helper, and the workspace→display mapping signature from `aerospace list-workspaces --monitor-appkit-nsscreen-screens-id`.
- The mapping counts only when every known workspace has a valid monitor ID (`monitor_valid`); partial AeroSpace results during settle are treated as unknown and retried on the next round.
- Graded response: nothing changed → no-op (a pure wake plays no fade and sets nothing); height-only → set the bar height directly, no fade; mapping changed → `enter_animation.transition()` fades the bar to mask workspaces moving across displays, then the probed snapshot is applied as-is (no second query), the focused-workspace cache is invalidated, and the window snapshot refreshes.
- On a confirmed change from the `system_woke` path, spaces.lua triggers `display_topology_change`; `items/apple.lua` re-measures Dock width on it, but ignores it if a raw `display_change` arrived within the last 2 seconds.

### Input Method Widget

Displays the current macOS input source and fcitx5 mode. The Swift daemon emits `input_method_change`; Lua queries once on reload for the initial display.

| Input Source | Display |
|--------------|---------|
| `com.apple.keylayout.ABC` | `A` |
| WeChat Input (`com.tencent.inputmethod.wetype.pinyin`) | `微` with green icon |
| fcitx5 Chinese | `CH` |
| fcitx5 English | `EN` |
| Unknown | `?` |

### Media Widget

Event-driven. The `media_watch` Swift daemon wraps `media-control stream` and triggers `media_update`; Lua updates the label and play/pause icon.

- Song info: title, artist, album
- Controls: previous track, play/pause, next track
- Init: Lua queries `media-control get` once on reload

### System Widget

The main CPU percentage is driven by the lightweight native CPU helper. The popup shows cached temperature/fan data immediately, then refreshes with one asynchronous `mactop` sample on open. A lightweight `ps` sampler updates the busiest apps only while the popup is open.

```bash
brew install mactop
```

### Battery Widget

Click the pill for percentage and estimated time remaining. Data from:

```bash
ioreg -rn AppleSmartBattery
```

### Common Validation

```bash
# From dotfiles root after source edits:
stow --no-folding sketchybar

luac -p ~/.config/sketchybar/items/spaces.lua
luac -p ~/.config/sketchybar/helpers/enter_animation.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload

# Run unit tests from the dotfiles root (tests resolve source paths relative to it):
for t in sketchybar/tests/*_test.lua; do lua "$t"; done
```

Fade speed: edit `ENTER_BAR_FADE_FRAMES` / `ENTER_ITEM_FADE_FRAMES` in `helpers/timing.lua`.

---

## 中文

这是一套模块化、事件驱动的 SketchyBar 配置：主要 UI 用 Lua 写，少数需要原生能力或常驻监听的部分用 Swift/C helper。

### 运行路径

本仓库是源码存储。在 **dotfiles 根目录** 执行 `stow --no-folding sketchybar` 后，实际运行路径是 `~/.config/sketchybar`。

helper 的编译产物不进 git，而是在实际运行路径里生成，例如：

- `~/.config/sketchybar/helpers/event_providers/aerospace_watch/bin/aerospace_watch`
- `~/.config/sketchybar/helpers/event_providers/docker_watch/bin/docker_watch`
- `~/.config/sketchybar/helpers/event_providers/input_method/bin/input_method_watch`
- `~/.config/sketchybar/helpers/event_providers/media_watch/bin/media_watch`

排查实时问题时优先看 `~/.config/sketchybar`。仓库源码通过 stow symlink 生效；**新增或修改 stow 管理的文件后需要重新 `stow --no-folding sketchybar`**。Swift/C helper 源码变化后仍要重建二进制。

### 工作流程

1. `sketchybarrc` 先加载 `helpers/`：一次批量 mtime 扫描跳过新鲜产物，缺失 binary 同步定向编译，已有但过期的 binary 后台定向编译；bar 先 `hidden` 避免默认高度闪一下。
2. `init.lua` 执行 `begin_config` → 外观默认、`bar.lua`（仍 hidden）、`items/`。
3. `end_config` 之后：首屏查询并行完成即放行，最长等待 1 秒；先填入已返回的真实内容，再统一归零并渐入。
4. `sbar.event_loop()` 接收 SketchyBar 原生事件和 helper 守护进程的自定义 trigger。

### 启动渐入

| 步骤 | 模块 | 行为 |
|------|------|------|
| `install()` | `enter_animation` | `begin_config` 前劫持 `sbar.add`，只登记主条 item 名（跳过 popup） |
| `track()` / `when_ready()` | `startup` | 等待首轮异步状态；全部完成立即继续，1 秒超时则用已完成数据降级显示 |
| `prepare()` / `conceal()` | `enter_animation` | 记录显式目标颜色，并在真实字符串/计数填入后重新压到透明态 |
| `startup.reveal()` | `startup` | 以透明 bar 背景/边框 unhide，再渐入到最终 alpha（约 500ms） |
| `run()` | 同上 | 所有显式前景、背景和边框颜色一次 linear alpha 渐入（约 500ms，与 bar 同步） |

- 只插值颜色 alpha：不改 `y_offset`、不做 stagger、不强行 `drawing=true`，也不改变几何。
- 跳过 popup 行（`position` 以 `popup` 开头，或名称含 `popup` / 月历格 / sys 进程行）。
- bar/item 时长：`helpers/timing.lua` 的 `ENTER_BAR_FADE_FRAMES` / `ENTER_ITEM_FADE_FRAMES`，当前均为 30 steps（SketchyBar 按 60 steps/s 计算，约 500ms）。

必须在 **end_config 之后** prepare。首屏屏障只等待状态，不串行执行外部命令；超时也不会取消晚到的查询。动画使用 `add` 时声明的目标颜色，不逐项调用同步 `query()`，避免 item 数量增长后拖慢 reload。首次 UI 结果在隐藏阶段先填充内容，并在渐入结束后以最新值收尾，避免普通 `set` 半途取消动画。

**坑：包装 `sbar.add` 时必须用 `raw_add(...)` 原样转发。**  
不要对 3 参数的 `add("item", name, props)` 写成 `raw_add(kind, name, props, nil)`。多传的 `nil` 会让 SbarLua 按 4 参形态误解析，popup item 的 `position = "popup.…"` 丢失，Docker/Git 等 popup 行会整排铺到主条上。`install()` 故意用可变参数 `...`，改这段时务必保留。

**坑：helper 的 `bin/` 只应出现在运行目录，不应出现在 dotfiles 仓库树里。**

| 路径 | 角色 |
|------|------|
| `~/dotfiles/sketchybar/...`（仓库） | 源码：`.lua` / `.swift` / `makefile` / plist（stow 成 symlink） |
| `~/.config/sketchybar`（运行） | SketchyBar / launchd 实际使用；`CONFIG_DIR` 指向这里 |
| `~/.config/sketchybar/helpers/**/bin/` | **编译产物只放这里**（`.gitignore` 的 `bin`；stow 不管） |

- makefile 里是相对路径 `bin/`，跟 **当前 cwd** 走，不是 makefile「写错路径」。
- 正确编译：
  - 推荐：`sketchybar --reload` → `helpers/helper_build.lua` 只在 `$CONFIG_DIR` 下编译缺失或过期 target；后台编译期间旧 binary 仍可继续运行；
  - 手动：`cd ~/.config/sketchybar/helpers && make`。
- helper 先输出到 `bin/<name>.new`，成功后才替换现有 binary。Swift helper 共用 `helpers/swift.mk`；必要时可用 `SKETCHYBAR_SWIFT_SDK` 覆盖兼容 SDK fallback。
- **错误：** `make -C ~/dotfiles/sketchybar/.config/sketchybar/helpers/...` — 会在**仓库树**下再生成一份 `bin/`，launchd 仍加载 `$HOME/.config/.../bin/...`，改了等于白改。
- 若在 **dotfiles 检出目录**里看到 `helpers/**/bin`：当作误编译，删掉这些目录（本来就不进 git），再到 `~/.config` 下重编。
- 改 Swift/C 后：看 `~/.config/sketchybar/helpers/**/bin/` 的 mtime，必要时 `launchctl kickstart -k gui/$(id -u)/com.fuzhuoqun.<agent>`。

### 文件地图

| 路径 | 作用 |
|------|------|
| `sketchybarrc` | 入口：helpers + settings + `init` |
| `init.lua` | `begin_config` / 启动渐入 / `event_loop` |
| `settings.lua` | bar 高度、默认间距、自动显隐 helper |
| `appearance.lua` | Catppuccin 色板、语义颜色、全局默认样式 |
| `fonts.lua` | 字体族和样式 |
| `icons.lua` | 共享图标定义 |
| `bar.lua` | bar 几何、模糊、背景 |
| `status_widget.lua` | 应用角标工厂（微信 / 钉钉） |
| `items/init.lua` | item 加载顺序 |
| `items/apple.lua` | Apple logo + Dock 宽度间距 |
| `items/services.lua` | Notch 左侧 Docker 状态灯 + 控制 popup |
| `items/git.lua` | Git dirty 汇总 + 仓库 popup |
| `items/spaces.lua` | AeroSpace 工作区、app 图标、焦点分段、窗口 popup |
| `items/calendar.lua` | 日期时间 + 月历 popup |
| `items/widgets/*` | 右侧 pills（sys、battery、network、media 等） |
| `helpers/init.lua` | 最早期启动设置与 helper build 入口 |
| `helpers/helper_build.lua` | 批量 freshness 计划、定向编译与 event provider 重启 |
| `helpers/swift.mk` | 共享 Swift 编译器、SDK 与 module cache 配置 |
| `helpers/startup.lua` | reload 启动阶段协调：隐藏、批量配置、揭示 |
| `helpers/enter_animation.lua` | reload 启动 item alpha 渐入 |
| `helpers/popup_animation.lua` | popup 显隐 alpha |
| `helpers/popup_utils.lua` | popup 事件回调中的延后 UI 更新 |
| `helpers/borders.lua` | 工作区焦点分段样式 |
| `helpers/timing.lua` | 共享动画时间常量 |
| `helpers/services/*` | Docker Compose 配置 / 状态 / 控制脚本 |
| `helpers/git/*` | 监视仓库配置 + 状态脚本 |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe 与 fullscreen diff |
| `helpers/event_providers/docker_watch/` | Docker events 与有上限的可用性重试 → `services_change` |
| `helpers/event_providers/input_method/` | 原生输入法监听 |
| `helpers/event_providers/media_watch/` | `media-control stream` 监听 |
| `helpers/event_providers/cpu_load/` | CPU%（host_statistics）；由 `sys.lua` 用 pidfile 拉起 |
| `helpers/event_providers/sys_watch/` | sys popup 打开期间的传感器（按需） |
| `helpers/bar_height/` | 原生 bar 高度 helper |
| `helpers/dock_width/` | Apple item 用的 Dock 宽度 helper |

### 进程生命周期（谁启动 / 谁杀掉）

| 进程 | 如何启动 | 如何停止 / 重启 |
|------|----------|-----------------|
| `sketchybar` | brew service / 手动 / 登录项 | `sketchybar --reload` 重跑 Lua 配置进程 |
| `aerospace_watch` / `docker_watch` / `input_method_watch` / `media_watch` | launchd LaunchAgents（`KeepAlive`） | `helper_build.lua` 仅在对应 binary 成功重建后 `launchctl kickstart` |
| `cpu_load` | `items/widgets/sys.lua` 加载时（pidfile 在 `$TMPDIR`） | 下次 reload `sys.lua` 时 kill 旧进程再起 |
| `sys_watch` | 仅在 sys popup 打开期间 | popup `on_hidden` 时停止 |

### 桌面事件流

| 发送方 | 事件 | 接收方 | 用途 |
|--------|------|--------|------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | 更新焦点工作区缓存和分段边框（不做完整窗口查询） |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | 原生窗口创建/销毁后刷新完整窗口快照 |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | AeroSpace 检测到新窗口后补一次刷新 |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | 完整快照 + 工作区编号旁 fullscreen 标记 |
| SketchyBar | `display_change` / `system_woke` | `items/spaces.lua` | 先验证、分级响应（见下节）：纯唤醒零动作；仅高度变直接改高度不渐入；映射变才整条渐入 + 应用 + 刷新窗口 |
| `aerospace_watch` | `aerospace_mode_change` | `items/spaces.lua` | 显示或隐藏 AeroSpace service mode 指示器 |
| `input_method_watch` | `input_method_change` | `items/widgets/input_method.lua` | 同步 macOS 输入源和 fcitx5 状态 |
| `media_watch` | `media_update` | `items/widgets/media.lua` | 媒体标题和播放状态 |
| `docker_watch` | `services_change` | `items/services.lua` | 容器生命周期变化后刷新服务状态灯 |

### Spaces Widget

`items/spaces.lua` 是工作区 UI 的唯一渲染点。它维护一份 AeroSpace 窗口快照，并基于这份快照重画工作区。

- 主条每个 app 只显示一个图标；popup 仍然逐个显示该工作区的每个窗口。
- **工作区焦点**只更新该工作区红底分段与 icon/label 颜色（轻量路径，不查完整窗口列表）。
- **窗口焦点**不会单独改变主条上某个 app 图标的颜色。
- 窗口创建/销毁、全屏状态变化才刷新完整快照。
- fullscreen 标记在工作区编号旁：` <workspace>`。
- `aerospace_watch` 用 AeroSpace 0.21 socket 做很小的 fullscreen diff，失败回退 CLI。Lua 仍用 `aerospace list-windows` 做完整渲染快照。

### 显示器拓扑同步（`display_change` / `system_woke`）

事件类型不可信：睡眠期间的拓扑变化（合盖、睡后拔显示器）可能只投递 `system_woke`，而 `display_change` 也常发于无需调整的场景。两个事件在 `items/spaces.lua` 共用一套"先验证、分级响应"流程：

- 0.25s / 1.25s 双轮 probe，generation + round token 丢弃慢查询的过期回调。验证信号：bar 高度（`bar_height` helper）和 workspace→显示器映射签名（`aerospace list-workspaces --monitor-appkit-nsscreen-screens-id`）。
- 映射数据只有在每个已知 workspace 都有合法 monitor ID 时才有效（`monitor_valid`）；AeroSpace settle 期间的部分结果按"未知"处理，等下一轮重试。
- 分级响应：都没变 → 零动作（纯唤醒不播渐入、不 set）；仅高度变 → 直接改 bar 高度，不渐入；映射变 → `enter_animation.transition()` 渐入遮住跨屏搬家，随后直接应用 probe 到的同一份快照（不二次查询）、失效 focused workspace 缓存、刷新窗口快照。
- system_woke 路径确认变化后由 spaces.lua 触发 `display_topology_change`；`items/apple.lua` 据此重测 Dock 宽度，但若 2 秒内已收到 raw `display_change` 则忽略。

### 输入法 Widget

显示当前 macOS 输入源和 fcitx5 状态。Swift 守护进程触发 `input_method_change`；Lua 在 reload 时查询一次初始状态。

| 输入法 | 显示 |
|--------|------|
| `com.apple.keylayout.ABC` | `A` |
| 微信输入法（`com.tencent.inputmethod.wetype.pinyin`） | 绿色图标 + `微` |
| fcitx5 中文 | `CH` |
| fcitx5 英文 | `EN` |
| 未知 | `?` |

### 媒体 Widget

事件驱动。`media_watch` 包装 `media-control stream` 并触发 `media_update`；Lua 更新歌名和播放/暂停图标。

- 歌曲信息：歌名、歌手、专辑
- 控制：上一首、播放/暂停、下一首
- 初始化：reload 时 Lua 主动查一次 `media-control get`

### 系统 Widget

主 CPU 百分比由轻量原生 CPU helper 推送。popup 先显示温度/风扇缓存，打开时用一帧异步 `mactop` 刷新；CPU 前十应用仅在 popup 打开期间用 `ps` 更新。

```bash
brew install mactop
```

### 电池 Widget

点击查看电量百分比和预估剩余时间。数据来源：

```bash
ioreg -rn AppleSmartBattery
```

### 常用验证

```bash
# 在 dotfiles 根目录，改完源码后：
stow --no-folding sketchybar

luac -p ~/.config/sketchybar/items/spaces.lua
luac -p ~/.config/sketchybar/helpers/enter_animation.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload

# 在 dotfiles 根目录跑单元测试（测试按相对路径定位源码）：
for t in sketchybar/tests/*_test.lua; do lua "$t"; done
```

bar 和 item 渐入快慢：改 `helpers/timing.lua` 里的 `ENTER_BAR_FADE_FRAMES` / `ENTER_ITEM_FADE_FRAMES`。
