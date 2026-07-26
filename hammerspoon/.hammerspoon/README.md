# Hammerspoon 配置说明

## 输入法切换（input.lua）

### 状态模型

只有两态：`EN`（当前输入源是 ABC）和 `ZH`（任意非 ABC 输入源，目前是苹果双拼）。
系统侧要求恰好启用"ABC + 一个中文输入法"，否则"选择上一个输入源"不是确定性操作；
启动时 `warnInputSourceConfiguration()` 会校验并弹警告。

### 切换的两条腿

- **切英文**：TIS API 直切 `hs.keycodes.currentSourceID(ABC_SRC)`，同步、可靠。
- **切中文**：macOS 没有"切到指定中文输入法"的公开 API，读取系统快捷键
  `com.apple.symbolichotkeys.plist` 第 60 项（"选择上一个输入源"，默认 Ctrl+Space）并模拟按下。
  修饰键按下 → Space 按下 → 50ms 后逆序抬修饰键 → 100ms 后抬 Space。
  已按下的键有精确记录，`releasePendingInputShortcut()` 在所有失败出口
  （重入、投递中途抛错、watchdog 超时、`hs.shutdownCallback`）同步补偿释放，防卡键。

### 触发：Caps 单击 = 孤立 Command 短按

Hyperkey 按住 Caps 发 Hyper（⌃⌥⌘⇧）用于组合键；单击时的触发链路是：

```
单击 Caps → Hyperkey 呈现为孤立左 Command 事件 → Hammerspoon 检测短按 → toggleInputSource()
```

门铃判定：左 Command（kc=55）按下后 0.3s 内松开（`CMD_TAP_MAX_HOLD`），
期间没有任何其他按键或鼠标（否则视为组合键，不触发）。

### 为什么不是别的方案（踩坑记录）

1. **macOS 原生"Caps 切换输入法"**：与 Raycast/Hyperkey 的事件重放存在时序竞态，
   偶发"菜单栏图标已切、按键路由没切"，打出来是英文，Shift 无效，反复切几次自愈。
   黑盒无法修，弃用。
2. **检测 Hyper 四修饰键**：Hyperkey 根本不发 ⌃⌥⌘⇧ 修饰事件——实测 flagsChanged 日志，
   Caps 只产生孤立的 kc=55（左 Command）；组合键是改写后续按键的 flags 实现的。
3. **检测 Caps 锁存**：Hyperkey 单击转发的 Caps 事件不进入系统事件流（实测无任何日志）。
4. **Karabiner 驱动层映射**：历史上也有 caps 漏出，未采用。

### 已知边界

- **物理左 Command 快速单点**与 Caps 单击在系统里不可区分，也会触发切换（正常操作不会单点 Cmd）。
- **快速双击 Caps** 等于双击 Command，会触发微信语音的浮层检测（仅微信前台有实际影响）。
- 微信语音输入期间，纯 Command 事件只启动短时浮层检测，不会误切。

### 其他模块

- `caps_guard.lua`：Raycast/Hyperkey 的 Hyper 映射偶发把 Caps Lock 锁存漏进系统，
  检测到锁存立即清除（并在 50ms/200ms 补清）。事件驱动，无轮询。
- `wps.lua`：WPS 右键自动切英文，通过 input 模块的 async 接口调用。
- `window_watcher.lua` / `floating_focus.lua`：浮动窗口安全区归位、Hyper+P 聚焦，见根 README。

### 调试入口

- Hammerspoon Console：`[Input]` 开头是 input.lua，`[caps_guard]` 开头是 caps_guard。
- 语法检查：`luac -p ~/.hammerspoon/*.lua`。
- reload 语义：`hs.reload()` 使用全新 Lua 环境，旧全局变量不继承；
  需要 reload 前同步收尾的逻辑挂 `hs.shutdownCallback`（参考 input.lua 的按键补偿释放）。
