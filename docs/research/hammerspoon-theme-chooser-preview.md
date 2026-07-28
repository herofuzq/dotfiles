# Hammerspoon 主题选择器色板预览设计

日期：2026-07-28。状态：已确认设计，待实施。

## 目标

改善 `Hyper+Shift+T` 的主题选择界面，在保留原生 `hs.chooser` 行为的前提下，让用户在选择前看到各主题的实际配色。

## 已确认方案

采用“原生 chooser + 当前系统 flavor 色板缩略图”：

- 保留现有搜索、键盘导航、快捷选择、`Esc` 取消和原子切换链路。
- 每个主题行左侧显示一张内存生成的五色色板缩略图。
- 缩略图只展示 macOS 当前深浅模式真正会生效的颜色。
- chooser 搜索框提示当前模式，例如 `Theme · Dark · follows macOS`。
- 当前主题继续使用 `✓` 标记。
- 不提供独立的 dark/light 开关；深浅模式仍完全跟随 macOS。

## 色板内容

缩略图从左到右展示：

1. `base`：主题主背景，宽度略大。
2. `accent`：该 scheme 用于 Apple、FrontApp 和 jankyborders 的代表色。
3. `green`：正常/成功状态。
4. `yellow`：警告状态。
5. `red`：错误状态。

配色直接来自 `theme.lua` 当前 flavor，不维护第三份颜色数据。

## 实现边界

- 在 `theme.lua` 的 Hammerspoon 配色子集中补充 `accent`，并继续由跨应用测试与 SketchyBar 色板逐项校验。
- `theme_switcher.lua` 每次打开 chooser 时，根据 `theme.current_flavor()` 为六个主题生成缩略图。
- 使用 `hs.canvas` 生成 `hs.image`，仅保存在 chooser choices 的内存中。
- 不写图片文件，不增加 watcher、轮询、动画或自定义窗口。
- macOS 深浅模式变化后，下次打开 chooser 自动重建为新 flavor。

## 错误处理

单张缩略图生成失败时，该主题仍以纯文字 choice 显示，不能影响主题切换。

## 验证

- dark/light 两种 flavor 的缩略图颜色与 SketchyBar 对应色板一致。
- chooser 仍有 6 个主题，当前项标记正确。
- 搜索、上下键、回车、`Esc` 和 `⌘1` 至 `⌘6` 行为保持不变。
- 预览图生成失败时仍能完成选择。
- 不改变状态文件、Hammerspoon HUD、SketchyBar 和 jankyborders 的既有切换顺序。
