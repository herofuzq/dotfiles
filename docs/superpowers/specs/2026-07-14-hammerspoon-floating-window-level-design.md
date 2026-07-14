# Hammerspoon Floating Window Level

## Goal

让 AeroSpace 中新创建的 floating 窗口自动提升到 macOS 的 floating window level，使它们在使用 `focus --ignore-floating` 时仍保持可见。

## Design

- 新增独立模块 `hammerspoon/.hammerspoon/floating_level.lua`。
- `init.lua` 只负责加载该模块，不把窗口层级逻辑混入现有 `window_watcher.lua`。
- 模块监听 Hammerspoon 的标准窗口创建事件。
- 创建后短暂等待 AeroSpace 完成窗口分类，再通过 `aerospace list-windows --monitor all --json` 判断窗口布局。
- 只有布局为 `floating` 的窗口调用 `window:setLevel(hs.window.level.floating)`。
- 查询失败时重试有限次数，最终静默放弃，不改变窗口焦点。
- Hammerspoon 重载时扫描现有窗口，补处理已经存在的 floating 窗口。

## Boundaries

- 不修改 AeroSpace 的工作区、focus 或 floating 规则。
- 不主动调用 `focus`，不让新窗口抢焦点。
- 不使用持续轮询；只使用窗口创建事件和一次启动补扫。
- 窗口关闭后不保留状态。

## Verification

- Lua 文件语法检查通过。
- Hammerspoon reload 后模块成功加载。
- 创建 Typeless 或其他 floating 窗口后，层级为 `hs.window.level.floating`。
- 创建普通 tiling 窗口时不提升层级。
- 当前焦点窗口在测试前后保持一致。
