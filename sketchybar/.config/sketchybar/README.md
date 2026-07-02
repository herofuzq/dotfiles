# SketchyBar Configuration / SketchyBar 配置

[EN](#english) | [中文](#chinese)

---

## English

This is a modular, event-driven SketchyBar configuration written in Lua with a few native Swift/C helpers.

### Runtime Path

This repository is the source copy. After `stow --no-folding sketchybar`, the active runtime lives at `~/.config/sketchybar`.

Compiled helper binaries are not stored in git. They are built under the active runtime path, for example:

- `~/.config/sketchybar/helpers/event_providers/aerospace_watch/bin/aerospace_watch`
- `~/.config/sketchybar/helpers/event_providers/input_method/bin/input_method_watch`
- `~/.config/sketchybar/helpers/event_providers/media_watch/bin/media_watch`

When debugging live behavior, inspect `~/.config/sketchybar` first. Source edits in this repo become active through the symlinked runtime, but helper binaries still need to be rebuilt when their source changes.

### How It Works

1. `sketchybarrc` starts SketchyBar and hands control to `init.lua`.
2. `init.lua` loads appearance, bar settings, item definitions, and `helpers/init.lua`.
3. `helpers/init.lua` checks helper source mtimes and runs `make` only when a binary is missing or stale.
4. `bar.lua` owns bar geometry, blur, background, and height.
5. `items/` owns visible UI: Apple item, AeroSpace spaces, calendar, and widgets.
6. `sbar.event_loop()` receives SketchyBar native events and custom triggers from helper daemons.

### File Map

| Path | Purpose |
|------|---------|
| `settings.lua` | Bar height, default spacing, reveal-zone helper setup |
| `appearance.lua` | Catppuccin palette, semantic colors, global defaults |
| `fonts.lua` | Font families and styles |
| `icons.lua` | Shared icon definitions |
| `bar.lua` | Bar-level geometry, blur, background |
| `items/init.lua` | Item load order |
| `items/spaces.lua` | AeroSpace workspace renderer, app icons, focus segment, window popup |
| `items/widgets/input_method.lua` | Input source and fcitx5 status pill |
| `items/widgets/media.lua` | Media title and previous/play/next controls |
| `helpers/init.lua` | Helper build freshness check and event-provider restart |
| `helpers/borders.lua` | Focused workspace segment styling |
| `helpers/timing.lua` | Shared animation timing constants |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe bridge and fullscreen diff watcher |
| `helpers/event_providers/input_method/` | Native input-method watcher |
| `helpers/event_providers/media_watch/` | `media-control stream` watcher |
| `helpers/event_providers/cpu_load/` | CPU percentage event provider |
| `helpers/event_providers/sys_watch/` | System helper event provider |
| `helpers/bar_height/` | Native bar-height helper |
| `helpers/dock_width/` | Native Dock-width helper for Apple item spacing |

### Desktop Event Flow

| Producer | Event | Consumer | Purpose |
|----------|-------|----------|---------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | Update focused workspace cache and border with no full window query |
| `aerospace_watch` | `window_focus_change` | `items/spaces.lua` | Repaint the cached workspace icons for active-window highlight |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | Refresh the full window snapshot after native window create/destroy |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | Refresh after AeroSpace reports a newly detected window |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | Refresh the full snapshot and show the fullscreen marker on the workspace number |
| SketchyBar | `display_change` | `items/spaces.lua` | Sync bar height, reveal zone, workspace display mapping, and protected window snapshot |
| `aerospace_watch` | `aerospace_mode_change` | `items/spaces.lua` | Show or hide the AeroSpace service-mode indicator |
| `input_method_watch` | `input_method_change` | `items/widgets/input_method.lua` | Sync macOS input source and fcitx5 internal mode |
| `media_watch` | `media_update` | `items/widgets/media.lua` | Push media title and playback state changes |

### Spaces Widget

`items/spaces.lua` is the only renderer for workspace UI. It keeps a cached AeroSpace window snapshot and redraws workspaces from that snapshot.

- Multiple windows from the same app intentionally render multiple app icons.
- Focus changes are cheap: they update caches and redraw the affected workspace from the existing snapshot.
- Window create/destroy and fullscreen changes refresh the full snapshot.
- Fullscreen is marked at workspace level with ` <workspace>`, not around the app icon.
- `aerospace_watch` uses AeroSpace 0.21's socket protocol for its tiny fullscreen diff query, with a CLI fallback. Lua still uses `aerospace list-windows` for the full render snapshot.

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
- Init: Lua queries `media-control get` once on reload for the initial display

### System Widget

The main CPU percentage is driven by the lightweight native CPU helper. The popup displays cached temperature/fan data immediately, then refreshes it with one asynchronous `mactop` sample on open. A lightweight `ps` sampler updates the busiest apps only while the popup is open.

Install optional system data dependency with:

```bash
brew install mactop
```

### Battery Widget

Hover the pill to see a popup with battery percentage and estimated time remaining. Data comes from:

```bash
ioreg -rn AppleSmartBattery
```

### Common Validation

```bash
luac -p ~/.config/sketchybar/items/spaces.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload
```

---

## 中文

这是一套模块化、事件驱动的 SketchyBar 配置：主要 UI 用 Lua 写，少数需要原生能力或常驻监听的部分用 Swift/C helper。

### 运行路径

本仓库是源码存储。执行 `stow --no-folding sketchybar` 后，实际运行路径是 `~/.config/sketchybar`。

helper 的编译产物不进 git，而是在实际运行路径里生成，例如：

- `~/.config/sketchybar/helpers/event_providers/aerospace_watch/bin/aerospace_watch`
- `~/.config/sketchybar/helpers/event_providers/input_method/bin/input_method_watch`
- `~/.config/sketchybar/helpers/event_providers/media_watch/bin/media_watch`

排查实时问题时优先看 `~/.config/sketchybar`。仓库源码会通过 symlink 生效，但 Swift/C helper 的二进制仍然要在源码变化后重建。

### 工作流程

1. `sketchybarrc` 启动 SketchyBar，并把控制权交给 `init.lua`。
2. `init.lua` 加载外观、bar 设置、item 定义和 `helpers/init.lua`。
3. `helpers/init.lua` 检查 helper 源码和二进制的 mtime，只在缺 binary 或 stale 时跑 `make`。
4. `bar.lua` 负责 bar 的几何、模糊、背景和高度。
5. `items/` 负责可见 UI：Apple、AeroSpace 工作区、日历和各种 widget。
6. `sbar.event_loop()` 接收 SketchyBar 原生事件和 helper 守护进程发来的自定义 trigger。

### 文件地图

| 路径 | 作用 |
|------|------|
| `settings.lua` | bar 高度、默认间距、自动显隐 helper |
| `appearance.lua` | Catppuccin 色板、语义颜色、全局默认样式 |
| `fonts.lua` | 字体族和样式 |
| `icons.lua` | 共享图标定义 |
| `bar.lua` | bar 几何、模糊、背景 |
| `items/init.lua` | item 加载顺序 |
| `items/spaces.lua` | AeroSpace 工作区渲染、app 图标、焦点分段、窗口 popup |
| `items/widgets/input_method.lua` | 输入源和 fcitx5 状态 |
| `items/widgets/media.lua` | 媒体标题和上一首/播放/下一首控制 |
| `helpers/init.lua` | helper 编译 freshness 检查和 event provider 重启 |
| `helpers/borders.lua` | 工作区焦点分段样式 |
| `helpers/timing.lua` | 共享动画时间常量 |
| `helpers/event_providers/aerospace_watch/` | AeroSpace subscribe 桥接和 fullscreen diff 监听 |
| `helpers/event_providers/input_method/` | 原生输入法监听 |
| `helpers/event_providers/media_watch/` | `media-control stream` 监听 |
| `helpers/event_providers/cpu_load/` | CPU 百分比 event provider |
| `helpers/event_providers/sys_watch/` | 系统信息 helper event provider |
| `helpers/bar_height/` | 原生 bar 高度 helper |
| `helpers/dock_width/` | Apple item 间距用的 Dock 宽度 helper |

### 桌面事件流

| 发送方 | 事件 | 接收方 | 用途 |
|--------|------|--------|------|
| `aerospace_watch` | `aerospace_workspace_change` | `items/spaces.lua` | 更新焦点工作区缓存和边框，不做完整窗口查询 |
| `aerospace_watch` | `window_focus_change` | `items/spaces.lua` | 用已有快照重画对应工作区 app 图标高亮 |
| SketchyBar | `space_windows_change` | `items/spaces.lua` | 原生窗口创建/销毁后刷新完整窗口快照 |
| `aerospace_watch` | `space_windows_change` | `items/spaces.lua` | AeroSpace 检测到新窗口后补一次刷新 |
| `aerospace_watch` | `aerospace_fullscreen_change` | `items/spaces.lua` | 刷新完整快照，并在工作区编号旁显示 fullscreen 标记 |
| SketchyBar | `display_change` | `items/spaces.lua` | 同步 bar 高度、自动显隐区域、工作区屏幕映射和受保护窗口快照 |
| `aerospace_watch` | `aerospace_mode_change` | `items/spaces.lua` | 显示或隐藏 AeroSpace service mode 指示器 |
| `input_method_watch` | `input_method_change` | `items/widgets/input_method.lua` | 同步 macOS 输入源和 fcitx5 内部状态 |
| `media_watch` | `media_update` | `items/widgets/media.lua` | 推送媒体标题和播放状态变化 |

### Spaces Widget

`items/spaces.lua` 是工作区 UI 的唯一渲染点。它维护一份 AeroSpace 窗口快照，并基于这份快照重画工作区。

- 同一个 app 有多个窗口时，会显示多个 app 图标。
- 焦点变化走轻量路径：更新缓存，并用已有快照重画相关工作区。
- 窗口创建/销毁、全屏状态变化才刷新完整快照。
- fullscreen 标记显示在工作区编号旁：` <workspace>`，不再包住 app 图标。
- `aerospace_watch` 用 AeroSpace 0.21 socket 协议做很小的 fullscreen diff 查询，失败时回退 CLI。Lua 仍然用 `aerospace list-windows` 做完整渲染快照。

### 输入法 Widget

显示当前 macOS 输入源和 fcitx5 状态。Swift 守护进程触发 `input_method_change`；Lua 在 reload 时查询一次初始状态。

| 输入法 | 显示 |
|--------|------|
| `com.apple.keylayout.ABC` | `A` |
| fcitx5 中文 | `CH` |
| fcitx5 英文 | `EN` |
| 未知 | `?` |

### 媒体 Widget

事件驱动。`media_watch` Swift 守护进程包装 `media-control stream` 并触发 `media_update`；Lua 更新歌名和播放/暂停图标。

- 歌曲信息：歌名、歌手、专辑
- 控制：上一首、播放/暂停、下一首
- 初始化：reload 时 Lua 主动查一次 `media-control get`

### 系统 Widget

主 CPU 百分比由轻量原生 CPU helper 推送。popup 会先显示温度/风扇缓存，并在打开时用一帧异步 `mactop` 刷新；CPU 前十应用由轻量 `ps` 仅在 popup 打开期间更新。

可选依赖：

```bash
brew install mactop
```

### 电池 Widget

悬停弹出剩余电量百分比和预估剩余时间。数据来源：

```bash
ioreg -rn AppleSmartBattery
```

### 常用验证

```bash
luac -p ~/.config/sketchybar/items/spaces.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload
```
