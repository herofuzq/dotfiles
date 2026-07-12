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

1. `sketchybarrc` loads `helpers/` first (compile stale Swift/C helpers if needed; bar starts `hidden` to avoid default-height flash), then starts `init.lua`.
2. `init.lua` runs `begin_config` → appearance defaults, `bar.lua` (still hidden), `items/`.
3. After `end_config`, `helpers/enter_animation.lua`: `prepare` (item colors → alpha 0) → `run_bar` (instant unhide with final height/colors) → `run` (item alpha fade).
4. `sbar.event_loop()` receives SketchyBar native events and custom triggers from helper daemons.

### Startup fade

| Step | Module | Behavior |
|------|--------|----------|
| `prepare()` | `enter_animation` | After `end_config`, `sketchybar --query` each main-bar item; set icon/label/`geometry.background` colors to alpha 0 when those channels are drawing (bar still hidden) |
| `run_bar()` | same | **Instant** unhide + final height/color/border (not a color-alpha animation) |
| `run()` | same | Single linear alpha animate for all snapped items (~500ms) |

- Item fade only: no `y_offset`, no stagger, does not force `drawing=true`.
- Popup rows are skipped (`position` starts with `popup`, or names containing `popup` / calendar grid / sys process rows).
- Item timing: `helpers/timing.lua` → `ENTER_ITEM_FADE_FRAMES`. `ENTER_BAR_FADE_FRAMES` is reserved if bar alpha fade is re-enabled later.

Snapshot must run **after** `end_config` because some widgets `sbar.set` backgrounds after `add` (e.g. into a shared bracket). Fading from creation-time props would re-show those backgrounds.

### File Map

| Path | Purpose |
|------|---------|
| `sketchybarrc` | Entry: helpers + settings + `init` |
| `init.lua` | `begin_config` / startup fade / `event_loop` |
| `settings.lua` | Bar height, default spacing, reveal-zone helper setup |
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
| `helpers/init.lua` | Helper build freshness check and event-provider restart |
| `helpers/enter_animation.lua` | Reload startup alpha fade (bar + items) |
| `helpers/popup_animation.lua` | Popup show/hide alpha helpers |
| `helpers/popup_utils.lua` | Shared pin / hover / delayed hide for single popups |
| `helpers/borders.lua` | Focused workspace segment styling |
| `helpers/timing.lua` | Shared animation timing constants |
| `helpers/services/*` | Docker compose config / status / control scripts |
| `helpers/git/*` | Watched repos config + status script |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe + fullscreen diff |
| `helpers/event_providers/docker_watch/` | Docker events → `services_change` |
| `helpers/event_providers/input_method/` | Input-method watcher |
| `helpers/event_providers/media_watch/` | `media-control stream` watcher |
| `helpers/event_providers/cpu_load/` | CPU percentage event provider |
| `helpers/event_providers/sys_watch/` | System sensors while sys popup is open |
| `helpers/bar_height/` | Native bar-height helper |
| `helpers/dock_width/` | Native Dock-width helper for Apple item spacing |

### Desktop Event Flow

| Producer | Event | Consumer | Purpose |
|----------|-------|----------|---------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | Update focused workspace cache and segment border (no full window query) |
| `aerospace_watch` | `window_focus_change` | _(unused)_ | Still emitted; bar only highlights the **workspace segment**, not the focused app icon |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | Refresh full window snapshot after native window create/destroy |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | Refresh after AeroSpace reports a newly detected window |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | Full snapshot + fullscreen mark on the workspace number |
| SketchyBar | `display_change` | `items/spaces.lua` | Sync bar height, reveal zone, workspace display mapping, protected snapshot |
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

### Input Method Widget

Displays the current macOS input source and fcitx5 mode. The Swift daemon emits `input_method_change`; Lua queries once on reload for the initial display.

| Input Source | Display |
|--------------|---------|
| `com.apple.keylayout.ABC` | `A` |
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

Hover the pill for percentage and estimated time remaining. Data from:

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

1. `sketchybarrc` 先加载 `helpers/`（必要时编译 helper；bar 先 `hidden` 避免默认高度闪一下），再进入 `init.lua`。
2. `init.lua` 执行 `begin_config` → 外观默认、`bar.lua`（仍 hidden）、`items/`。
3. `end_config` 之后：`prepare`（item 颜色 alpha→0）→ `run_bar`（瞬时 unhide + 最终高度/颜色）→ `run`（item alpha 渐入）。
4. `sbar.event_loop()` 接收 SketchyBar 原生事件和 helper 守护进程的自定义 trigger。

### 启动渐隐

| 步骤 | 模块 | 行为 |
|------|------|------|
| `prepare()` | `enter_animation` | `end_config` 后 query 主条 item；对 drawing=on 的 icon/label/`geometry.background` 设 alpha=0（bar 仍 hidden） |
| `run_bar()` | 同上 | **瞬时** unhide + 最终 height/color/border（不是 color alpha 动画） |
| `run()` | 同上 | 所有快照 item 一次 linear alpha 渐入（约 500ms） |

- 仅 item 走颜色 alpha：不改 `y_offset`、不做 stagger、不强行 `drawing=true`。
- 跳过 popup 行（`position` 以 `popup` 开头，或名称含 `popup` / 月历格 / sys 进程行）。
- item 时长：`helpers/timing.lua` 的 `ENTER_ITEM_FADE_FRAMES`。`ENTER_BAR_FADE_FRAMES` 留给以后若恢复 bar alpha 渐入。

必须在 **end_config 之后** snapshot：部分 widget 会在 `add` 后再 `sbar.set` 关掉 background 以并入 bracket；用创建时 props 渐入会把背景错误地画回来。

### 文件地图

| 路径 | 作用 |
|------|------|
| `sketchybarrc` | 入口：helpers + settings + `init` |
| `init.lua` | `begin_config` / 启动渐隐 / `event_loop` |
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
| `helpers/init.lua` | helper 编译 freshness 检查和 event provider 重启 |
| `helpers/enter_animation.lua` | reload 启动 alpha 渐入（bar + item） |
| `helpers/popup_animation.lua` | popup 显隐 alpha |
| `helpers/popup_utils.lua` | 单 popup 的 pin / hover / 延迟隐藏 |
| `helpers/borders.lua` | 工作区焦点分段样式 |
| `helpers/timing.lua` | 共享动画时间常量 |
| `helpers/services/*` | Docker Compose 配置 / 状态 / 控制脚本 |
| `helpers/git/*` | 监视仓库配置 + 状态脚本 |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe 与 fullscreen diff |
| `helpers/event_providers/docker_watch/` | Docker events → `services_change` |
| `helpers/event_providers/input_method/` | 原生输入法监听 |
| `helpers/event_providers/media_watch/` | `media-control stream` 监听 |
| `helpers/event_providers/cpu_load/` | CPU 百分比 event provider |
| `helpers/event_providers/sys_watch/` | sys popup 打开期间的传感器 |
| `helpers/bar_height/` | 原生 bar 高度 helper |
| `helpers/dock_width/` | Apple item 用的 Dock 宽度 helper |

### 桌面事件流

| 发送方 | 事件 | 接收方 | 用途 |
|--------|------|--------|------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | 更新焦点工作区缓存和分段边框（不做完整窗口查询） |
| `aerospace_watch` | `window_focus_change` | （未订阅） | 仍会触发；主条只高亮**工作区段**，不按当前窗口高亮 app 图标 |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | 原生窗口创建/销毁后刷新完整窗口快照 |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | AeroSpace 检测到新窗口后补一次刷新 |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | 完整快照 + 工作区编号旁 fullscreen 标记 |
| SketchyBar | `display_change` | `items/spaces.lua` | 同步 bar 高度、显隐区域、工作区屏幕映射和受保护快照 |
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

### 输入法 Widget

显示当前 macOS 输入源和 fcitx5 状态。Swift 守护进程触发 `input_method_change`；Lua 在 reload 时查询一次初始状态。

| 输入法 | 显示 |
|--------|------|
| `com.apple.keylayout.ABC` | `A` |
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

悬停查看电量百分比和预估剩余时间。数据来源：

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
```

item 渐入快慢：改 `helpers/timing.lua` 里的 `ENTER_ITEM_FADE_FRAMES`（bar 当前为瞬时 unhide，不读 `ENTER_BAR_FADE_FRAMES`）。
