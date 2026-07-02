# Dotfiles

这是我的 macOS dotfiles 源码仓库，主要管理开发环境、窗口管理、状态栏、输入法和终端工具配置。

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

## 常用验证

```bash
git diff --check
luac -p ~/.config/sketchybar/items/spaces.lua
make -C ~/.config/sketchybar/helpers/event_providers/aerospace_watch
launchctl print gui/$(id -u)/com.fuzhuoqun.aerospace_watch
sketchybar --reload
```

## 入口文档

| 文档 | 用途 |
|------|------|
| [SETUP.md](./SETUP.md) | 新机器安装、Stow、Brewfile、Launchd |
| [sketchybar/.config/sketchybar/README.md](./sketchybar/.config/sketchybar/README.md) | SketchyBar 模块、事件流、调试入口 |
