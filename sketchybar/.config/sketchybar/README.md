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

4.  **Items and Widgets**: After the core setup, it loads all the individual bar items from the `items/` directory. Each file in this directory (e.g., `cpu.lua`, `wifi.lua`, `media.lua`) corresponds to a specific element on the bar.

5.  **Event Loop**: Once the entire configuration is loaded, an event loop (`sbar.event_loop()`) is started. This loop listens for system events (like Wi-Fi changes, media playback, or front application switches) and updates the corresponding bar items in real-time.

6.  **Helpers**: The `helpers/` directory contains custom C programs that act as event providers for things not natively supported by Sketchybar, such as CPU load. These are compiled automatically.

### File Structure & Customization

To customize the bar, you should edit the following files:

#### Main Settings

These files control the overall look and feel of the bar.

*   `settings.lua`: The primary file for customization. Here you can change the bar's height, corner radius, and default item/text padding.
*   `appearance.lua`: Defines the color palette for the entire bar. Change the colors here to theme your bar.
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
    *   `event_providers/input_method/`: A Swift daemon that listens for macOS input method switch notifications and triggers Sketchybar events. See [Input Method Widget](#input-method-widget) below.
*   `sketchybarrc`: The main entry point. You should not need to edit this file.

### Input Method Widget

The input method widget (`⌨ ABC` / `⌨ 拼音`) displays the current macOS input source on the bar and updates in real-time.

#### How It Works

Instead of polling, the widget uses a **Swift daemon** that listens for the macOS system notification `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`. When the input method changes, the daemon triggers `sketchybar --trigger input_method_change`, and the widget's Lua callback queries `macism` to get the current input source name.

#### Files Involved

| File | Purpose |
|------|---------|
| `helpers/event_providers/input_method/input_method_watch.swift` | Swift daemon source |
| `helpers/event_providers/input_method/bin/input_method_watch` | Compiled daemon binary |
| `helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist` | LaunchAgent plist (auto-start + keep-alive) |
| `items/widgets/input_method.lua` | Widget Lua configuration |

#### Setup on a New Machine

1. **Install dependencies:**
   ```bash
   brew install macism sketchybar
   ```

2. **Compile the daemon:**
   ```bash
   cd ~/.config/sketchybar/helpers/event_providers/input_method
   swiftc -O -o bin/input_method_watch input_method_watch.swift
   ```

3. **Install the LaunchAgent** (auto-start at login, auto-restart on crash):
   ```bash
   cp com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   ```

4. **Reload Sketchybar:**
   ```bash
   sketchybar --reload
   ```

#### Customization

*   **Input method display names**: Edit the `im_map` table in `items/widgets/input_method.lua` to map macOS input source IDs to custom labels and colors.
*   **Click action**: By default, clicking the widget sends Cmd+Ctrl+Opt+Q to switch input methods. Edit the `mouse.clicked` handler in `items/widgets/input_method.lua` to change this behavior.
*   **Daemon binary path**: If you installed Sketchybar via a different method, update the `launchPath` in `input_method_watch.swift` and the `ProgramArguments` in the plist.

---

## 中文

这是一套高度模块化、可定制化的 Sketchybar 配置，主要使用 Lua 编写，通过 Sketchybar 的 Lua 插件实现动态事件驱动的状态栏。

### 工作流程

配置按以下顺序加载：

1.  **入口文件（`sketchybarrc`）**：Sketchybar 启动时执行 `sketchybarrc`，作为整个配置的入口。

2.  **Lua 初始化（`init.lua`）**：`sketchybarrc` 立即将控制权交给 `init.lua`，由它按顺序加载所有配置文件。

3.  **核心配置**：`init.lua` 先加载 bar 主体设置（`bar.lua`），再加载应用于所有 item 的默认属性（`settings.lua`、`appearance.lua` 等）。

4.  **Item 与 Widget**：接着加载 `items/` 目录下所有 bar 元素。每个文件（如 `cpu.lua`、`wifi.lua`）对应 bar 上的一个组件。

5.  **事件循环**：全部加载完成后启动事件循环（`sbar.event_loop()`），监听系统事件（Wi-Fi 变化、媒体播放、前台应用切换等）并实时更新对应 item。

6.  **Helpers**：`helpers/` 目录包含自定义 C 程序，为 Sketchybar 原生不支持的功能提供事件，如 CPU 负载。

### 文件结构与自定义

如需自定义 bar，编辑以下文件：

#### 主要设置

这些文件控制 bar 的整体外观。

*   `settings.lua`：主要自定义文件。可修改 bar 高度、圆角半径、默认 item/文字内边距。
*   `appearance.lua`：定义整个 bar 的配色方案。在此修改颜色以改变主题。
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
    *   `event_providers/input_method/`：一个 Swift 守护进程，监听 macOS 输入法切换通知并触发 Sketchybar 事件。详见下方[输入法 Widget](#输入法-widget)。
*   `sketchybarrc`：主入口文件，一般不需要编辑。

### 输入法 Widget

输入法 widget（`⌨ ABC` / `⌨ 拼音`）在 bar 上实时显示当前 macOS 输入法状态。

#### 工作原理

采用 **Swift 守护进程**监听 macOS 系统级通知 `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`，而非轮询。输入法切换时，守护进程触发 `sketchybar --trigger input_method_change`，widget 的 Lua 回调随即调用 `macism` 获取当前输入法名称。

#### 相关文件

| 文件 | 用途 |
|------|------|
| `helpers/event_providers/input_method/input_method_watch.swift` | Swift 守护进程源码 |
| `helpers/event_providers/input_method/bin/input_method_watch` | 编译后的二进制 |
| `helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist` | LaunchAgent plist（开机自启 + 保活） |
| `items/widgets/input_method.lua` | Widget Lua 配置 |

#### 新机器部署步骤

1. **安装依赖：**
   ```bash
   brew install macism sketchybar
   ```

2. **编译守护进程：**
   ```bash
   cd ~/.config/sketchybar/helpers/event_providers/input_method
   swiftc -O -o bin/input_method_watch input_method_watch.swift
   ```

3. **安装 LaunchAgent**（开机自启，崩溃自动重启）：
   ```bash
   cp com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
   ```

4. **重载 Sketchybar：**
   ```bash
   sketchybar --reload
   ```

#### 自定义

*   **输入法显示名称**：编辑 `items/widgets/input_method.lua` 中的 `im_map` 表，将 macOS 输入源 ID 映射到自定义标签和颜色。
*   **点击行为**：默认点击 widget 发送 Cmd+Ctrl+Opt+Q 切换输入法。修改 `items/widgets/input_method.lua` 中的 `mouse.clicked` 回调可改变行为。
*   **守护进程路径**：如果 Sketchybar 安装路径不同，需同步更新 `input_method_watch.swift` 中的 `launchPath` 和 plist 中的 `ProgramArguments`。
