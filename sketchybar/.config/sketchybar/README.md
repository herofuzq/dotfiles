# Sketchybar Configuration / Sketchybar 配置

[EN](#english) | [中文](#chinese)

---

## English

This is a highly modular and customizable Sketchybar configuration written primarily in Lua. It leverages Sketchybar's Lua plugin to create a dynamic and event-driven bar.

### How It Works

The configuration is loaded in the following sequence:

1.  **Entry Point (`sketchybarrc`)**: When Sketchybar starts, it executes the `sketchybarrc` file. This script is the main entry point for the entire configuration.

2.  **Lua Initialization (`init.lua`)**: `sketchybarrc` immediately hands over control to the main `init.lua` script. This script is the orchestrator for the entire setup. It loads all other configuration files in a specific order.

3.  **Core Configuration**: `init.lua` first loads the core bar settings (`bar.lua`) and then a set of default properties (`settings.lua`, `appearance.lua`, etc.) that apply to all items.

4.  **Items and Widgets**: After the core setup, it loads all the individual bar items from the `items/` directory. Each file in this directory (e.g., `apple.lua`, `spaces.lua`, `calendar.lua`) corresponds to a specific element on the bar.

5.  **Event Loop**: Once the entire configuration is loaded, an event loop (`sbar.event_loop()`) is started. This loop listens for system events (like input method changes, front application switches, or aerospace workspace changes) and updates the corresponding bar items in real-time.

6.  **Helpers**: The `helpers/` directory contains custom C and Swift programs that act as event providers for things not natively supported by Sketchybar, such as CPU load, input method changes, and theme switching. These are compiled automatically on first run via the unified `make` chain (`helpers/Makefile` → `event_providers/Makefile` → each provider's `Makefile`).

### File Structure & Customization

To customize the bar, you should edit the following files:

#### Main Settings

These files control the overall look and feel of the bar.

*   `settings.lua`: The primary file for customization. Here you can change the bar's height, corner radius, and default item/text padding.
*   `appearance.lua`: Catppuccin color palette + semantic colors + global defaults. Switch theme by editing `M.active`.
*   `fonts.lua`: All font definitions are located here. You can change font families, sizes, and styles.
*   `icons.lua`: A central repository for all icons used across the bar.

#### Bar Layout and Items

*   `bar.lua`: Configures the main properties of the bar itself, such as its position, blur, and background color.
*   `items/`: This directory contains the configuration for every item and widget on the bar.
    *   To **remove an item**, comment out its `require` statement in `items/init.lua`.
    *   To **add a new item**, create a new `.lua` file in this directory and `require` it in `items/init.lua`.
    *   To **change the position of items**, you can reorder the `require` statements in `items/init.lua` or change the `position` property within the item's file itself.

#### Advanced

*   `helpers/`: This directory contains the source code for custom event providers. You generally won't need to touch these files unless you are adding a new, complex feature that requires an external helper.
    *   `helpers/borders.lua`: Workspace dynamic border manager (focus/fullscreen highlight). Each item manages its own static border color.
    *   `event_providers/input_method/`: A Swift daemon that listens for macOS input method switch notifications and triggers Sketchybar events. See [Input Method Widget](#input-method-widget) below.
*   `sketchybarrc`: The main entry point. You should not need to edit this file.

### Setup on a New Machine

1. **Stow dotfiles:**
   ```bash
   git clone <your-dotfiles-repo> ~/dotfiles
   cd ~/dotfiles && stow --no-folding sketchybar
   ```

2. **Install all Homebrew dependencies** (includes sketchybar, aerospace, fonts, and more):
   ```bash
   brew bundle install --file=~/dotfiles/Brewfile
   ```

3. **Install Xcode Command Line Tools** (required for compiling helpers):
   ```bash
   xcode-select --install
   ```

4. **Register launchd services** (input method & theme watching daemons):
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   ln -s ~/.config/sketchybar/helpers/event_providers/theme/com.fuzhuoqun.theme_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.theme_watch.plist
   ```

5. **Reload Sketchybar** — helpers are compiled automatically on first run:
   ```bash
   sketchybar --reload
   ```

6. **Install optional extras:**
   - **Clash Verge Rev** (for TUN status widget): Download from [clash-verge-rev/releases](https://github.com/clash-verge-rev/clash-verge-rev/releases)
   - **fcitx5** (Chinese input method): `brew install --cask fcitx5`

### Input Method Widget

The input method widget displays the current macOS input source on the bar and updates in real-time. It supports three states:

| Input Source | Display |
|-------------|---------|
| `com.apple.keylayout.ABC` | `⌨ ABC` |
| fcitx5 (Chinese mode) | `⌨ 中州韵(ZH)` |
| fcitx5 (English mode) | `⌨ 中州韵(EN)` |

#### How It Works

The widget uses a **Swift daemon** that listens for the macOS system notification `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`. When the input method changes, the daemon triggers `sketchybar --trigger input_method_change`. The Lua callback queries `macism` to get the input source, and for fcitx5, additionally queries `fcitx5-remote` to determine Chinese/English mode.

#### Files Involved

| File | Purpose |
|------|---------|
| `helpers/event_providers/input_method/input_method_watch.swift` | Swift daemon source |
| `helpers/event_providers/input_method/bin/input_method_watch` | Compiled daemon binary |
| `helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist` | LaunchAgent plist (auto-start + keep-alive) |
| `items/widgets/input_method.lua` | Widget Lua configuration |

#### Setup on a New Machine

The daemon binary is **compiled automatically** by `helpers/init.lua` on first sketchybar reload — no manual `swiftc` needed.

1. **Install the LaunchAgent** (auto-start at login, auto-restart on crash):
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   ```

2. **Reload Sketchybar:**
   ```bash
   sketchybar --reload
   ```

#### Customization

*   **Input method display names**: Edit the `update_display` function in `items/widgets/input_method.lua` to change labels and colors for each state.
*   **fcitx5 binary path**: If fcitx5 is installed in a custom location, update the `FCITX_REMOTE` variable in `items/widgets/input_method.lua`.
*   **Daemon binary path**: If you installed Sketchybar via a different method, update the `launchPath` in `input_method_watch.swift` and the `ProgramArguments` in the plist.

---

## 中文

这是一套高度模块化、可定制化的 Sketchybar 配置，主要使用 Lua 编写，通过 Sketchybar 的 Lua 插件实现动态事件驱动的状态栏。

### 工作流程

配置按以下顺序加载：

1.  **入口文件（`sketchybarrc`）**：Sketchybar 启动时执行 `sketchybarrc`，作为整个配置的入口。

2.  **Lua 初始化（`init.lua`）**：`sketchybarrc` 立即将控制权交给 `init.lua`，由它按顺序加载所有配置文件。

3.  **核心配置**：`init.lua` 先加载 bar 主体设置（`bar.lua`），再加载应用于所有 item 的默认属性（`settings.lua`、`appearance.lua` 等）。

4.  **Item 与 Widget**：接着加载 `items/` 目录下所有 bar 元素。每个文件（如 `apple.lua`、`spaces.lua`、`calendar.lua`）对应 bar 上的一个组件。

5.  **事件循环**：全部加载完成后启动事件循环（`sbar.event_loop()`），监听系统事件（输入法切换、前台应用切换、aerospace 工作区变化等）并实时更新对应 item。

6.  **Helpers**：`helpers/` 目录包含自定义 C / Swift 程序，为 Sketchybar 原生不支持的功能提供事件，如 CPU 负载、输入法切换、主题切换。首次运行时通过统一的 `make` 链自动编译（`helpers/Makefile` → `event_providers/Makefile` → 各 provider 的 `Makefile`）。

### 文件结构与自定义

如需自定义 bar，编辑以下文件：

#### 主要设置

这些文件控制 bar 的整体外观。

*   `settings.lua`：主要自定义文件。可修改 bar 高度、圆角半径、默认 item/文字内边距。
*   `appearance.lua`：Catppuccin 色板 + 语义化颜色 + 全局默认样式。编辑 `M.active` 切换主题。
*   `fonts.lua`：所有字体定义。可修改字体族、大小和样式。
*   `icons.lua`：所有图标的统一仓库。

#### Bar 布局与 Item

*   `bar.lua`：配置 bar 本身的属性，如位置、模糊效果、背景色。
*   `items/`：包含 bar 上所有 item 和 widget 的配置。
    *   要**删除一个 item**，在 `items/init.lua` 中注释掉对应的 `require`。
    *   要**添加一个 item**，在此目录创建新的 `.lua` 文件并在 `items/init.lua` 中 `require`。
    *   要**调整 item 顺序**，在 `items/init.lua` 中调整 `require` 顺序，或修改 item 自身的 `position` 属性。

#### 高级

*   `helpers/`：包含自定义事件提供者的源码。除非需要新增复杂功能，通常无需修改。
    *   `helpers/borders.lua`：工作区动态边框管理（焦点/全屏高亮）。各 item 自行管理静态边框色。
    *   `event_providers/input_method/`：一个 Swift 守护进程，监听 macOS 输入法切换通知并触发 Sketchybar 事件。详见下方[输入法 Widget](#输入法-widget)。
*   `sketchybarrc`：主入口文件，一般不需要编辑。

### 新机器部署

1. **Stow dotfiles：**
   ```bash
   git clone <your-dotfiles-repo> ~/dotfiles
   cd ~/dotfiles && stow --no-folding sketchybar
   ```

2. **安装所有 Homebrew 依赖**（包含 sketchybar、aerospace、字体等）：
   ```bash
   brew bundle install --file=~/dotfiles/Brewfile
   ```

3. **安装 Xcode Command Line Tools**（编译 helpers 需要）：
   ```bash
   xcode-select --install
   ```

4. **注册 launchd 服务**（输入法 & 主题监听守护进程）：
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   ln -s ~/.config/sketchybar/helpers/event_providers/theme/com.fuzhuoqun.theme_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.theme_watch.plist
   ```

5. **重载 Sketchybar** — helpers 首次运行自动编译：
   ```bash
   sketchybar --reload
   ```

6. **安装可选组件：**
   - **Clash Verge Rev**（TUN 状态 widget 需要）：从 [clash-verge-rev/releases](https://github.com/clash-verge-rev/clash-verge-rev/releases) 下载
   - **fcitx5**（中文输入法）：`brew install --cask fcitx5`

### 输入法 Widget

输入法 widget 在 bar 上实时显示当前 macOS 输入法状态，支持三种显示：

| 输入源 | 显示 |
|--------|------|
| `com.apple.keylayout.ABC` | `⌨ ABC` |
| fcitx5 中文模式 | `⌨ 中州韵(ZH)` |
| fcitx5 英文模式 | `⌨ 中州韵(EN)` |

#### 工作原理

采用 **Swift 守护进程**监听 macOS 系统通知 `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`。输入法切换时触发 `sketchybar --trigger input_method_change`，Lua 回调调用 `macism` 获取输入源，对 fcitx5 额外调用 `fcitx5-remote` 判定中/英文模式。

#### 相关文件

| 文件 | 用途 |
|------|------|
| `helpers/event_providers/input_method/input_method_watch.swift` | Swift 守护进程源码 |
| `helpers/event_providers/input_method/bin/input_method_watch` | 编译后的二进制 |
| `helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist` | LaunchAgent plist（开机自启 + 保活） |
| `items/widgets/input_method.lua` | Widget Lua 配置 |

#### 新机器部署步骤

守护进程由 `helpers/init.lua` **在首次 reload 时自动编译**，无需手动执行 `swiftc`。

1. **安装 LaunchAgent**（开机自启，崩溃自动重启）：
   ```bash
   ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   ```

2. **重载 Sketchybar：**
   ```bash
   sketchybar --reload
   ```

#### 自定义

*   **输入法显示名称**：编辑 `items/widgets/input_method.lua` 中的 `update_display` 函数，修改各状态标签和颜色。
*   **fcitx5 路径**：如果 fcitx5 安装在非默认路径，更新 `items/widgets/input_method.lua` 中的 `FCITX_REMOTE` 变量。
*   **守护进程路径**：如果 Sketchybar 安装路径不同，需同步更新 `input_method_watch.swift` 中的 `launchPath` 和 plist 中的 `ProgramArguments`。
