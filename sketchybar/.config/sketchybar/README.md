# Sketchybar Configuration / Sketchybar 配置

[EN](#english) | [中文](#chinese)

---

## English

This is a highly modular and event-driven Sketchybar configuration written in Lua with Swift helpers.

### How It Works

1.  **`sketchybarrc`** → hands over to `init.lua`
2.  **`init.lua`** → loads appearance, bar, items in batch (`begin_config`)
3.  **`bar.lua`** → bar geometry, blur, colors
4.  **`items/`** → apple logo, aerospace spaces, calendar, widgets
5.  **`sbar.event_loop()`** → listens for system events (aerospace, input method, media, etc.)
6.  **`helpers/`** → C/Swift helpers for CPU load, input method, and media playback. Auto-compiled via `make`.

### File Structure

#### Main Settings

*   `settings.lua`: Bar height, padding defaults.
*   `appearance.lua`: Catppuccin color palette + semantic colors + global defaults. Switch theme via `M.active`.
*   `fonts.lua`: All font definitions.
*   `icons.lua`: Central icon repository.

#### Bar & Items

*   `bar.lua`: Bar position, blur, background.
*   `items/`: All bar elements.
    *   Comment out a `require` in `items/init.lua` to remove an item.
    *   Reorder `require` calls to change item order.

#### Advanced

*   `helpers/borders.lua`: Focused/fullscreen workspace segment styling.
*   `event_providers/input_method/`: Swift daemon — macOS input method change notifications.
*   `event_providers/media_watch/`: Swift daemon — monitors media playback via `media-control stream`, updates label + play/pause icon in real-time (no polling).
*   `sketchybarrc`: Entry point and automatic reveal helper bootstrap.

### Desktop Integration Events

| Producer | Event | Consumer | Purpose |
|----------|-------|----------|---------|
| AeroSpace | `aerospace_workspace_change` | `items/spaces.lua` | Immediate focus highlight and workspace refresh |
| Hammerspoon | `space_windows_change` | `items/spaces.lua` | Refresh after a window is created or destroyed |
| AeroSpace | `aerospace_fullscreen_change` | `items/spaces.lua` | Refresh fullscreen segment state |
| Swift watcher + Hammerspoon | `input_method_change` | `widgets/input_method.lua` | macOS source and fcitx5 internal mode changes |
| SketchyBar | `display_change` / `system_woke` | `items/spaces.lua` | Sync bar height, reveal zone, and workspace displays |

Window focus is owned by AeroSpace. Hammerspoon only fills the create/destroy event gap: creation waits 250 ms for workspace routing, while window destruction and app termination use a 50 ms debounce.

### Setup on a New Machine

1. **Stow dotfiles:**
   ```bash
   git clone <your-dotfiles-repo> ~/dotfiles
   cd ~/dotfiles && stow --no-folding sketchybar
   ```

2. **Install Homebrew dependencies:**
   ```bash
   brew bundle install --file=~/dotfiles/Brewfile
   ```

3. **Install Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```

4. **Register launchd services:**
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   ln -s ~/.config/sketchybar/helpers/event_providers/media_watch/com.fuzhuoqun.media_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.media_watch.plist
   ```

5. **Reload Sketchybar** (helpers auto-compile on first run):
   ```bash
   sketchybar --reload
   ```

6. **Optional extras:**
   - **Clash Verge Rev** (TUN status): [releases](https://github.com/clash-verge-rev/clash-verge-rev/releases)
   - **fcitx5** (Chinese input): `brew install --cask fcitx5`
   - **media-control** (media widget): `brew install media-control`

### Input Method Widget

Displays the current macOS input source and fcitx5 mode. The Swift daemon handles source changes; Hammerspoon notifies SketchyBar when it changes fcitx5's internal English/Chinese state.

| Input Source | Display |
|-------------|---------|
| `com.apple.keylayout.ABC` | `A` |
| fcitx5 Chinese | `CH` |
| fcitx5 English | `EN` |
| Unknown | `?` |

### Media Widget

Event-driven (no polling). The `media_watch` Swift daemon wraps `media-control stream` and directly sets label + play/pause icon when song or playback state changes.

- **Song info**: title, artist, album displayed on hover-able pill
- **Controls**: previous track, play/pause, next track
- **Init**: Lua queries `media-control get` once on reload for initial display

### System Widget

The main CPU percentage remains driven by the lightweight native helper. The popup reads cached temperature/fan data immediately and refreshes it with a single `mactop` sample when stale; a lightweight `ps` sampler updates the ten busiest apps only while the popup is open. Install with `brew install mactop`.

### Battery Widget

Hover the pill to see a popup with battery percentage and estimated time remaining. Data sourced from `ioreg -rn AppleSmartBattery`.

---

## 中文

高度模块化、事件驱动的 Sketchybar 配置，Lua + Swift 守护进程。

### 工作流程

1.  **`sketchybarrc`** → 入口，转交 `init.lua`
2.  **`init.lua`** → 批量加载 appearance、bar、items
3.  **`bar.lua`** → bar 几何、模糊、颜色
4.  **`items/`** → apple logo、aerospace 工作区、日历、widgets
5.  **`sbar.event_loop()`** → 监听 aerospace、输入法、媒体等系统事件
6.  **`helpers/`** → C/Swift helpers（CPU、输入法、媒体），`make` 自动编译

### 文件结构

#### 主要设置

*   `settings.lua`: Bar 高度、默认边距。
*   `appearance.lua`: Catppuccin 色板 + 语义化颜色 + 全局默认样式。编辑 `M.active` 切换主题。
*   `fonts.lua`: 字体定义。
*   `icons.lua`: 图标仓库。

#### Bar 与 Item

*   `bar.lua`: Bar 位置、模糊、背景。
*   `items/`: 所有 bar 元素。
    *   在 `items/init.lua` 中注释 `require` 可移除 item。
    *   调整 `require` 顺序可改变 item 排列。

#### 高级

*   `helpers/borders.lua`: workspace 焦点/全屏分段样式。
*   `event_providers/input_method/`: Swift 守护进程 — macOS 输入法切换。
*   `event_providers/media_watch/`: Swift 守护进程 — 监听媒体播放，直接更新歌名和播放/暂停图标（零轮询）。
*   `sketchybarrc`: 入口文件，并负责启动自动显隐 helper。

### 桌面集成事件

| 发送方 | 事件 | 接收方 | 用途 |
|--------|------|--------|------|
| AeroSpace | `aerospace_workspace_change` | `items/spaces.lua` | 立即更新焦点和工作区内容 |
| Hammerspoon | `space_windows_change` | `items/spaces.lua` | 窗口创建或销毁后刷新内容 |
| AeroSpace | `aerospace_fullscreen_change` | `items/spaces.lua` | 刷新全屏分段状态 |
| Swift watcher + Hammerspoon | `input_method_change` | `widgets/input_method.lua` | 同步 macOS 输入源和 fcitx5 内部状态 |
| SketchyBar | `display_change` / `system_woke` | `items/spaces.lua` | 同步 bar 高度、自动显隐区域和工作区屏幕 |

窗口焦点由 AeroSpace 负责；Hammerspoon 只补充窗口创建/销毁事件：创建等待 250ms 让工作区路由完成，窗口销毁和应用退出使用 50ms 防抖。

### 新机器部署

1. **Stow dotfiles：**
   ```bash
   git clone <your-dotfiles-repo> ~/dotfiles
   cd ~/dotfiles && stow --no-folding sketchybar
   ```

2. **安装 Homebrew 依赖：**
   ```bash
   brew bundle install --file=~/dotfiles/Brewfile
   ```

3. **安装 Xcode Command Line Tools：**
   ```bash
   xcode-select --install
   ```

4. **注册 launchd 服务：**
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   ln -s ~/.config/sketchybar/helpers/event_providers/media_watch/com.fuzhuoqun.media_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.media_watch.plist
   ```

5. **重载 Sketchybar**（helpers 首次运行自动编译）：
   ```bash
   sketchybar --reload
   ```

6. **可选安装：**
   - **Clash Verge Rev**（TUN 状态）：[releases](https://github.com/clash-verge-rev/clash-verge-rev/releases)
   - **fcitx5**（中文输入法）：`brew install --cask fcitx5`
   - **media-control**（媒体 widget）：`brew install media-control`

### 输入法 Widget

显示当前 macOS 输入源和 fcitx5 状态。Swift 守护进程负责输入源变化；Hammerspoon 修改 fcitx5 内部中英文状态后主动通知 SketchyBar。

| 输入法 | 显示 |
|--------|------|
| `com.apple.keylayout.ABC` | `A` |
| fcitx5 中文 | `CH` |
| fcitx5 英文 | `EN` |
| 未知 | `?` |

### 媒体 Widget

事件驱动（零轮询）。`media_watch` 守护进程包装 `media-control stream`，歌曲或播放状态变化时直接更新歌名和播放/暂停图标。

- **歌曲信息**：悬停 pill 显示歌名、歌手、专辑
- **控制**：上一首、播放/暂停、下一首
- **初始化**：reload 时 Lua 主动查一次显示

### 系统 Widget

主 CPU 百分比继续由轻量原生 helper 推送。popup 会立即读取温度/风扇缓存，仅在缓存过期时用 `mactop` 采样一次；CPU 前十应用由轻量 `ps` 仅在 popup 打开期间更新。安装命令：`brew install mactop`。

### 电池 Widget

悬停弹出剩余电量百分比和预估剩余时间。数据来源 `ioreg -rn AppleSmartBattery`。
