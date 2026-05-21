# Dotfiles Setup Guide

本仓库管理 macOS 开发环境的所有关键配置文件，使用 [GNU Stow](https://www.gnu.org/software/stow/) 管理符号链接。

## 目录

- [快速开始](#快速开始)
- [Brewfile — 统一安装](#brewfile--统一安装)
- [按类别配置](#按类别配置)
  - [终端 / Shell](#终端--shell)
  - [编辑器](#编辑器)
  - [Git](#git)
  - [macOS 工具](#macos-工具)
  - [Sketchybar](#sketchybar)
  - [输入法](#输入法)
  - [SSH](#ssh)
- [Launchd 服务](#launchd-服务)
- [跨机同步 checklist](#跨机同步-checklist)

---

## 快速开始

```bash
# 1. 克隆
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles

# 2. 安装所有 Homebrew 包（brew CLI + cask apps + fonts）
brew bundle install --file=Brewfile

# 3. Stow 所有配置包
stow aerospace bash bat borders btop cmux fastfetch fcitx5 fd \
     ghostty git hammerspoon karabiner lazygit npm nvim \
     sketchybar ssh starship tmux yazi zsh

# 4. 安装 Xcode Command Line Tools（编译 helpers 需要）
xcode-select --install

# 5. Reload 应用
sketchybar --reload       # 状态栏（helpers 自动编译）
```

---

## Brewfile — 统一安装

`Brewfile` 包含了所有 Homebrew 管理的软件，分为以下几类：

| 类别 | 典型软件 |
|------|---------|
| Terminal | ghostty, tmux, starship, zoxide, fzf, bat, fd, yazi |
| Editor | neovide, lazygit |
| macOS Tools | raycast, hammerspoon, karabiner-elements, aerospace, borders |
| Desktop Apps | obsidian, typora, bitwarden, iina |
| Fonts | fira/hack/meslo/victor-mono-nerd-font, sf-pro, sf-mono |
| Dev | node, pnpm, ruby, opencode, docker |
| Network | wireshark, transmission-cli, mole |

用法：
```bash
brew bundle install --file=Brewfile       # 安装全部
brew bundle check --file=Brewfile         # 检查缺失
brew bundle cleanup --file=Brewfile       # 清理未列出项
```

---

## 按类别配置

### 终端 / Shell

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `zsh` | `~/.zshrc` `~/.zimrc` | Zsh 配置 + Zim 模块 |
| `bash` | `~/.bash_profile` | Bash 兼容配置 |
| `starship` | `~/.config/starship.toml` | Shell 提示符主题 |
| `tmux` | `~/.config/tmux/` | Tmux 配置 + 插件（tpm, catppuccin 等） |

**新机器注意：**
- Zim 需要额外安装：`curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh`
- Tmux 插件：启动 tmux 后按 `prefix + I`（大写 I）安装

### 编辑器

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `nvim` | `~/.config/nvim/` | Neovim 配置（lazy.nvim + LazyVim） |
| `lazygit` | `~/.config/lazygit/config.yml` | Lazygit 配置 |

**新机器注意：**
- 首次启动 Neovim 会自动安装所有插件
- `lazygit` 在 `brew bundle` 中已包含

### Git

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `git` | `~/.gitconfig` | Git 全局配置 |
| `git` | `~/.gitignore` | 全局 gitignore（`**/bin/`） |

### macOS 工具

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `aerospace` | `~/.config/aerospace/aerospace.toml` | 平铺窗口管理器 |
| `borders` | `~/.config/borders/bordersrc` | 窗口边框 |
| `hammerspoon` | `~/.hammerspoon/init.lua` | macOS 自动化 |
| `karabiner` | `~/.config/karabiner/` | 键盘改键（含 complex_modifications） |
| `ghostty` | `~/.config/ghostty/` | 终端模拟器配置 + GLSL 着色器 |
| `yazi` | `~/.config/yazi/` | 终端文件管理器（含插件） |
| `cmux` | `~/.config/cmux/cmux.json` | 窗口布局管理 |
| `bat` | `~/.config/bat/config` | 语法高亮增强 cat |
| `fd` | `~/.config/fd/ignore` | find 替代品忽略规则 |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` | 系统信息 |
| `btop` | `~/.config/btop/btop.conf` | 终端资源监视器 |

### Sketchybar

功能完备的状态栏，包含系统监控、工作区切换、输入法显示、媒体播放等 widget。

详见 [sketchybar/.config/sketchybar/README.md](./sketchybar/.config/sketchybar/README.md)。

**关键路径：**

| 文件/目录 | 说明 |
|-----------|------|
| `sketchybarrc` | 入口文件 |
| `init.lua` | Lua 主控（加载所有模块 + 编译 helpers） |
| `helpers/event_providers/` | 后台守护进程源码（CPU、输入法、主题） |
| `items/` | 所有 bar widget 定义 |

**启动方式：**
- 主程序：`sketchybar`（brew 安装，可配置 launchd 自启）
- 输入法监听守护进程 → launchd 管理（见下方）
- 主题监听守护进程 → launchd 管理（见下方）

### 输入法

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `fcitx5` | `~/.config/fcitx5/` | Fcitx5 输入法框架配置 |
| `fcitx5` | `~/.config/fcitx5/conf/macos*.conf` | macOS 前端/通知设置 |

### SSH

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `ssh` | `~/.ssh/config` | SSH 客户端配置 |

> ⚠️ `~/.ssh/id_ed25519*`（私钥/公钥）和 `~/.ssh/known_hosts` **不纳入** dotfiles 管理，由各机器独立维护。

---

## Launchd 服务

以下后台守护进程由 launchd 管理，需要在新机器上注册一次：

| 服务 | 功能 | 注册命令 |
|------|------|---------|
| `com.fuzhuoqun.input_method_watch` | 监听输入法切换 → `sketchybar --trigger input_method_change` | 见下方 |
| `com.fuzhuoqun.theme_watch` | 监听深色/浅色模式切换 → `sketchybar --trigger system_appearance_changed` | 见下方 |

**注册步骤：**

```bash
# 软链 plist 到 LaunchAgents 目录
ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist \
      ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/theme/com.fuzhuoqun.theme_watch.plist \
      ~/Library/LaunchAgents/

# 加载服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.theme_watch.plist
```

二进制由 `sketchybar --reload` 时自动编译（通过 `helpers/init.lua` + `make`）。

---

## 跨机同步 checklist

在新 Mac 上部署的完整步骤：

```bash
# ▸ 前置条件
xcode-select --install

# ▸ 克隆 dotfiles
cd ~ && git clone <your-dotfiles-repo> dotfiles

# ▸ Stow 所有配置
cd dotfiles && stow $(ls -d */ | tr -d '/')

# ▸ 安装 Homebrew 软件
brew bundle install --file=Brewfile

# ▸ 注册 launchd 服务
ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/theme/com.fuzhuoqun.theme_watch.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.theme_watch.plist

# ▸ 初始化 Zim（Zsh 插件管理）
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh

# ▸ 重载
sketchybar --reload
```

---

## 文件结构总览

```
dotfiles/
├── Brewfile              # Homebrew 包清单
├── SETUP.md              # ← 本文件
├── aerospace/            # 窗口管理器
├── bash/                 # Bash 配置
├── bat/                  # 语法高亮
├── borders/              # 窗口边框
├── btop/                 # 系统监控
├── cmux/                 # 窗口布局
├── fastfetch/            # 系统信息
├── fcitx5/               # 输入法框架
├── fd/                   # find 替代品
├── ghostty/              # 终端模拟器
├── git/                  # Git 全局配置
├── hammerspoon/          # macOS 自动化
├── karabiner/            # 键盘改键
├── lazygit/              # Git TUI
├── npm/                  # npm 配置
├── nvim/                 # Neovim
├── sketchybar/           # 状态栏
├── ssh/                  # SSH 客户端
├── starship/             # Shell 提示符
├── tmux/                 # 终端复用器
├── yazi/                 # 文件管理器
└── zsh/                  # Zsh 配置
```
