# Dotfiles

这是我的 macOS dotfiles 源码仓库，管理窗口管理、状态栏、输入法、终端、编辑器、Shell 和常用桌面工具配置。

详细安装步骤见 [SETUP.md](./SETUP.md)。这个 README 只保留整体地图和日常排查入口。

## 核心原则

- 本仓库是源码存储，实际运行路径通常在 `$HOME` 下。
- 使用 GNU Stow 管理 symlink，建议统一使用 `stow --no-folding`。
- 调试实时问题时优先检查运行路径，例如 `~/.config/sketchybar`、`~/.config/aerospace`、`~/.hammerspoon`。
- SketchyBar 的 Swift/C helper 二进制不进 git，会在实际运行路径下编译生成。

## 主要模块

| 模块 | 运行路径 | 说明 |
|------|----------|------|
| AeroSpace | `~/.config/aerospace/aerospace.toml` | 平铺窗口管理、工作区、快捷键 |
| SketchyBar | `~/.config/sketchybar` | 状态栏、工作区、系统信息、输入法、媒体组件 |
| Hammerspoon | `~/.hammerspoon` | macOS 自动化和少量窗口辅助 |
| Karabiner | `~/.config/karabiner` | 键盘改键 |
| Kitty / Ghostty | `~/.config/kitty`, `~/.config/ghostty` | 终端配置 |
| Neovim | `~/.config/nvim` | 编辑器配置 |
| fcitx5 | `~/.config/fcitx5` | 中文输入法配置 |
| Shell / TUI | `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, `~/.bashrc`, `~/.config/{yazi,lazygit,starship,zellij}` | Shell、文件管理、终端复用和 Git TUI |

## SketchyBar 提醒

SketchyBar 的源码在：

```bash
./sketchybar/.config/sketchybar
```

实际运行在：

```bash
~/.config/sketchybar
```

helper 二进制会生成在实际运行路径，例如：

```bash
~/.config/sketchybar/helpers/event_providers/aerospace_watch/bin/aerospace_watch
```

相关架构和事件流见 [sketchybar/.config/sketchybar/README.md](./sketchybar/.config/sketchybar/README.md)。

## 浮动窗口联动

浮动窗口的职责分成两层：

1. **AeroSpace** 判断窗口是否为 `floating`，并负责工作区与窗口布局规则。
2. **Hammerspoon** 监听窗口创建、聚焦和移动事件；新建的浮动窗口会避开顶部 SketchyBar 并移动到屏幕安全区域中央。

`Hyper+P` 在当前工作区的可聚焦浮动窗口之间循环；`Typeless` 不参与该快捷键，`CleanShot X` 不参与安全区归位。

Hammerspoon 不使用常驻轮询，主要依赖窗口事件和有限次数的 AeroSpace 查询重试。浮动窗口移入 SketchyBar 顶部区域时，会在实际发生归位后显示一次提示。

## 常用验证

```bash
git diff --check
luac -p ~/.config/sketchybar/items/spaces.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload

# Hammerspoon Lua 语法
luac -p ~/.hammerspoon/*.lua
```

在 Hammerspoon Console 中检查浮动窗口模块的运行状态：

```lua
print(_floatingLevel_filter ~= nil, _windowWatcher_filter ~= nil)
```

## 入口文档

| 文档 | 用途 |
|------|------|
| [SETUP.md](./SETUP.md) | 新机器安装、Stow、Brewfile、Launchd |
| [sketchybar/.config/sketchybar/README.md](./sketchybar/.config/sketchybar/README.md) | SketchyBar 模块、事件流、调试入口 |
| [nvim/.config/nvim/README.md](./nvim/.config/nvim/README.md) | Neovim 配置与插件说明 |

仓库当前没有单独的 `readme/` 目录；以上根文档和模块 README 是维护入口。
