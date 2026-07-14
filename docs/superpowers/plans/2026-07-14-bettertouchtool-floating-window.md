# BetterTouchTool Floating Window Plan

## 目标

由 Hammerspoon 监听窗口生命周期并查询 AeroSpace 的真实布局状态；当窗口确认是
`floating` 后，由 Hammerspoon 调用 BetterTouchTool 的 Pin 动作，把指定窗口置于
普通窗口之上。BTT 不负责识别 App、不负责监听创建窗口，也不维护每个 App 的触发器规则。

## 已纠正的架构

```text
窗口创建/显示事件
        |
        v
Hammerspoon
  1. 获取窗口 ID
  2. 查询 aerospace list-windows --json
  3. 只接受当前仍存在且 layout= floating 的窗口
  4. 延迟重试，等待 AeroSpace 完成布局
        |
        v
BetterTouchTool AppleScript API
  Pin (402) + WindowMode=1 + WindowID=<目标窗口>
        |
        v
目标 float 窗口置顶，不改变当前焦点
```

旧版“Specific App Did Create Window”方案已废弃。它把窗口观测权交给 BTT，
会造成应用规则重复、时序不稳定，也无法自然复用 AeroSpace 的 floating 判断。

## 实施阶段

### 阶段 1：桥接接口探针

1. 确认 BTT 已运行且 Accessibility 可用。
2. 从 BTT 的 `BTTScripting.sdef` 确认 `trigger_action` 的实际调用形式，
   并确认它能接受一个包含 `BTTPredefinedActionType=402` 与
   `BTTActionPinOnTopWindowID` 的动作配置。
3. 首选 Hammerspoon 直接调用 BTT 预定义动作，不创建任何 BTT 触发器。
4. 若 BTT 直接动作接口无法传递动态窗口 ID，再退到一个固定的 BTT 命名桥接动作：
   Hammerspoon 先写入运行时窗口 ID，再调用该命名动作。这个桥接动作仍只有一个，
   不按 Finder、Zen、Typeless 等 App 建规则。
5. 不采用 Toggle Pin（337），优先使用显式 Pin（402），避免重复事件导致误取消置顶。

### 阶段 2：Hammerspoon 监控模块

1. 在现有实验模块边界内改造，不修改稳定的 `window_watcher.lua` 逻辑。
2. 监听 `windowCreated`、`windowVisible`，必要时监听 `windowFocused` 做一次性重试；
   不使用持续轮询。
3. 每次事件先通过 AeroSpace JSON 按窗口 ID 精确匹配，只有以下条件全部满足才调用 BTT：
   - 是标准窗口；
   - 窗口仍存在；
   - AeroSpace 能找到该 ID；
   - `window-layout` 或父容器布局为 `floating`；
   - 不属于排除名单（保留现有 CleanShot X 排除规则）。
4. 使用约 `0.30s` 初始延迟和有限重试，等待 AeroSpace 完成窗口归属；
   事件合并按窗口 ID 做 debounce，避免同一窗口并发调用。
5. 以窗口 ID 作为状态键，窗口销毁后清理状态；Hammerspoon reload 时做一次启动校正，
   但只校正当前 AeroSpace 仍报告为 floating 的窗口。
6. BTT 调用失败只记录错误并结束本次尝试，不改变焦点、不调用 `hs.window:focus()`，
   也不把隐藏在其他 workspace 或右下角的窗口误判为当前窗口。

### 阶段 3：Finder + Zen 最小测试

1. 先让 Zen 保持普通 tiled/focused 基线。
2. 创建或显示 Finder 窗口，记录窗口 ID、创建前后焦点和 AeroSpace JSON。
3. 验证 Hammerspoon 只对 Finder 的 ID 调用 BTT，Finder 位于 Zen 之上，焦点不闪烁。
4. 切换焦点到 Zen，再切回 Finder，确认置顶状态不被 Hammerspoon 重复事件破坏。
5. 关闭并重开 Finder，确认旧窗口 ID 不会影响新窗口。
6. reload Hammerspoon，确认 watcher 不重复注册，已有 float 只被校正一次。

### 阶段 4：扩展范围

Finder + Zen 通过后，再加入 Typeless 与其他已确认的 AeroSpace floating 应用。
应用名单仍维护在 AeroSpace/Hammerspoon 的判断侧；BTT 只接收窗口 ID，不知道应用名单。

## 方案取舍

| 方案 | 责任边界 | 结论 |
| --- | --- | --- |
| Hammerspoon 直接调用 BTT 预定义 Pin | Hammerspoon 监控和判断，BTT 执行动作 | 首选，规则最少 |
| 一个固定的 BTT 命名桥接动作 | Hammerspoon 传动态窗口 ID，BTT 执行固定动作 | 直接 API 不足时的备选 |
| BTT `Specific App Did Create Window` | BTT 自己监控 App 和创建时机 | 不采用 |
| 先聚焦再调用 focused-window Pin | 依赖焦点，可能闪烁或误 pin | 仅作为最后故障兜底，不进入首版 |

## 回滚

停用 Hammerspoon 新模块或注释其 `require` 即可恢复现状；若采用命名桥接动作，
只删除那一个桥接动作。不会添加 AeroSpace 的 App 创建规则，也不需要 SIP 或 yabai。

## 风险与验证重点

- BTT 的直接 `trigger_action` 字典入口已确认存在，但需用最小动作探针确认动态 JSON 参数的具体传递方式。
- Pin 是否完全不改变焦点必须用 Finder + Zen 实测，不能只根据动作名称推断。
- AeroSpace 对其他 workspace 的浮动窗口必须在过滤阶段排除，不能仅凭窗口几何位置判断。
- BTT 重启、Hammerspoon reload、窗口关闭重开都要验证状态清理和幂等性。
