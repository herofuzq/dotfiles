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
  - [Hammerspoon + BetterTouchTool](#hammerspoon--bettertouchtool)
  - [SketchyBar](#sketchybar)
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

# 3. Stow 所有配置包（--no-folding 避免目录折叠）
stow --no-folding aerospace bash bat borders btop clash cmux fastfetch fcitx5 fd \
     ghostty git hammerspoon karabiner kitty lazygit npm nvim \
     sketchybar ssh starship yazi zsh

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
| Terminal | ghostty, starship, zoxide, fzf, bat, fd, ripgrep, yazi |
| Editor | neovide-app, lazygit |
| macOS Tools | raycast, hammerspoon, bettertouchtool, karabiner-elements, aerospace, borders |
| Desktop Apps | obsidian, typora, bitwarden, iina |
| Fonts | hack-nerd-font, jetbrains-maple-mono-nf, sarasa-gothic, sketchybar-app-font |
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


**新机器注意：**
- Zim 需要额外安装：`curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh`

### 编辑器

| Stow 包 | 目标路径 | 说明 |
|---------|---------|------|
| `nvim` | `~/.config/nvim/` | Neovim 配置（lazy.nvim + LazyVim） |
| `lazygit` | `~/.config/lazygit/config.yml` | Lazygit 配置 |
| `npm` | `~/.npmrc` | npm 镜像源配置 |

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
| `kitty` | `~/.config/kitty/` | GPU 终端模拟器 + Catppuccin 主题 |
| `ghostty` | `~/.config/ghostty/` | 终端模拟器配置 + GLSL 着色器 |
| `yazi` | `~/.config/yazi/` | 终端文件管理器（含插件） |
| `cmux` | `~/.config/cmux/cmux.json` | 窗口布局管理 |
| `bat` | `~/.config/bat/config` | 语法高亮增强 cat |
| `fd` | `~/.config/fd/ignore` | find 替代品忽略规则 |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` | 系统信息 |
| `btop` | `~/.config/btop/btop.conf` | 终端资源监视器 |
| `clash` | `~/script.js` | Clash Verge Rev / Mihomo Party 分流脚本（YaNet） |

### Hammerspoon + BetterTouchTool

Hammerspoon 是窗口事件和状态的控制端，BetterTouchTool（BTT）是浮动窗口 Pin/Unpin 的执行端。两者的安装包都在 `Brewfile` 中：

```bash
brew install --cask hammerspoon bettertouchtool
stow --no-folding hammerspoon
```

首次使用需要在 macOS「系统设置 → 隐私与安全性」中允许 Hammerspoon 和 BetterTouchTool 的**辅助功能**权限。修改 `hammerspoon/.hammerspoon/*.lua` 后，在 Hammerspoon 菜单中 Reload，或使用：

```bash
hs -c 'hs.reload()'
hs -c 'print(_floatingLevel_filter ~= nil, _windowWatcher_filter ~= nil)'
```

#### 浮动窗口工作流

- AeroSpace 负责判断窗口是否为 `floating`；Hammerspoon 负责监听窗口事件、避开 SketchyBar 顶部区域并将符合条件的新浮动窗口移到安全区域中央。
- Hammerspoon 通过窗口 ID 和 Bundle ID 调用 BTT Pin/Unpin。BTT 不需要额外创建前端触发器规则。
- 置顶按窗口创建顺序维护：后创建且仍存在的浮动窗口优先 Pin，旧窗口保持 Unpin；后创建窗口关闭后才恢复上一个窗口。
- `Hyper+P` 切换自动置顶。关闭时解除现有浮动窗口的 Pin，开启时重新扫描当前工作区。
- `Typeless` 不参与自动置顶，`CleanShot X` 不参与安全区归位。窗口事件驱动为主，不使用常驻轮询。

#### 浮动窗口排查

```bash
# 确认 AeroSpace 对当前工作区窗口的布局判断
aerospace list-windows --workspace focused --format '%{window-id}%{tab}%{app-bundle-id}%{tab}%{window-layout}' --json

# 检查 Hammerspoon 模块是否已加载
hs -c 'print(_floatingLevel_filter ~= nil, _windowWatcher_filter ~= nil)'

# 检查 BTT 是否在运行
pgrep -fl BetterTouchTool
```

若重新打开窗口后行为异常，先 Reload Hammerspoon，再分别检查 AeroSpace 的 `window-layout` 和 BTT 进程；不要通过新增 BTT 触发器绕过 Hammerspoon 的窗口顺序管理。

### SketchyBar

功能完备的状态栏，包含系统监控、工作区切换、输入法显示、媒体播放等 widget。

详见 [sketchybar/.config/sketchybar/README.md](./sketchybar/.config/sketchybar/README.md)。

**关键路径：**

| 文件/目录 | 说明 |
|-----------|------|
| `sketchybarrc` | 入口文件 |
| `init.lua` | Lua 主控（加载所有模块 + 编译 helpers） |
| `helpers/init.lua` | helper freshness 检查，只在 binary 缺失或源码更新时跑 make |
| `helpers/event_providers/` | 后台守护进程源码（AeroSpace、输入法、媒体、CPU、系统信息） |
| `items/` | 所有 bar widget 定义 |

**启动方式：**
- 主程序：`sketchybar`（brew 安装，可配置 launchd 自启）
- AeroSpace / 输入法 / 媒体 / Docker 监听 → launchd 管理（见下方 Launchd 服务）
- `cpu_load`：由 `items/widgets/sys.lua` 在 reload 时用 pidfile 拉起（非 launchd）
- `sys_watch`：仅 sys popup 打开期间由 Lua 拉起，关闭 popup 时杀掉
- helper 二进制在 `~/.config/sketchybar/helpers/.../bin/`，不进 git；源码更新后 reload 会 `make`，并只 kickstart **本次重建过** 的 launchd agent

**可选 / 推荐依赖：**
- `jq`：Clash TUN 状态解析更准确（无 jq 时 `clash_status.sh` 用粗 grep；`brew install jq`）
- `media-control`：媒体 widget / `media_watch`
- `ifstat`：网速 widget
- `mactop`：sys popup 温度/风扇
- Accessibility：系统设置 → 隐私与安全性 → 辅助功能，允许相关终端/脚本；否则 Apple logo 点菜单（`helpers/menus`）会失败

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
| `com.fuzhuoqun.aerospace_watch` | 桥接 AeroSpace 事件 → SketchyBar 工作区/焦点状态 | 见下方 |
| `com.fuzhuoqun.docker_watch` | 监听 Docker 容器事件 → `sketchybar --trigger services_change` | 见下方 |
| `com.fuzhuoqun.input_method_watch` | 监听输入法切换 → `sketchybar --trigger input_method_change` | 见下方 |
| `com.fuzhuoqun.media_watch` | 监听媒体播放状态 → 实时更新 SketchyBar 媒体组件 | 见下方 |

**注册步骤：**

```bash
# 软链 plist 到 LaunchAgents 目录
ln -s ~/.config/sketchybar/helpers/event_providers/aerospace_watch/com.fuzhuoqun.aerospace_watch.plist \
      ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/docker_watch/com.fuzhuoqun.docker_watch.plist \
      ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist \
      ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/media_watch/com.fuzhuoqun.media_watch.plist \
      ~/Library/LaunchAgents/

# 加载服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.aerospace_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.docker_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.media_watch.plist
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
cd dotfiles && stow --no-folding aerospace bash bat borders btop clash cmux fastfetch fcitx5 fd \
     ghostty git hammerspoon karabiner kitty lazygit npm nvim \
     sketchybar ssh starship yazi zsh

# ▸ 安装 Homebrew 软件
brew bundle install --file=Brewfile

# ▸ 注册 launchd 服务
ln -s ~/.config/sketchybar/helpers/event_providers/aerospace_watch/com.fuzhuoqun.aerospace_watch.plist ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/docker_watch/com.fuzhuoqun.docker_watch.plist ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/input_method/com.fuzhuoqun.input_method_watch.plist ~/Library/LaunchAgents/
ln -s ~/.config/sketchybar/helpers/event_providers/media_watch/com.fuzhuoqun.media_watch.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.aerospace_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.docker_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.input_method_watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fuzhuoqun.media_watch.plist

# ▸ macOS 系统偏好（dotfiles 管不到系统级 defaults，需手动执行）
# 关闭窗口创建/关闭/resize 动画
# 用途：aerospace 的 `[[on-window-detected]]` 是 post-creation hook，
# 浮窗应用打开时会被先 tile 一下再切回 float（见 aerospace 源码 + issue #1562）。
# 关闭自动动画后，两次 setFrame 的视觉跳变更直接，肉眼几乎察觉不到。
# 还原：defaults delete -g NSAutomaticWindowAnimationsEnabled
# 生效：需重启相关 app
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# ▸ 安装 yazi 插件（package.toml 里声明，需手动 fetch）
ya pack -i

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
├── clash/                # 代理脚本
├── cmux/                 # 窗口布局
├── fastfetch/            # 系统信息
├── fcitx5/               # 输入法框架
├── fd/                   # find 替代品
├── ghostty/              # 终端模拟器
├── git/                  # Git 全局配置
├── hammerspoon/          # macOS 自动化
├── karabiner/            # 键盘改键
├── kitty/                # 终端模拟器
├── lazygit/              # Git TUI
├── npm/                  # npm 配置
├── nvim/                 # Neovim
├── sketchybar/           # 状态栏
├── ssh/                  # SSH 客户端
├── starship/             # Shell 提示符
├── yazi/                 # 文件管理器
└── zsh/                  # Zsh 配置
```
