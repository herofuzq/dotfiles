# SketchyBar 主题系统方案（v2.1，架构已批准，进入阶段一）

> 状态：方案阶段，未动代码。本文档办结后按惯例折叠进 sketchybar README 并删除。
> v1 → v2 修订：M.colors 原地更新防反弹；bar_bg 保留（v1 误判为死配置）；
> 弃用 Swift theme_watch，改用 SketchyBar 原生分布式通知事件；启动同步检测；
> dim/popup 默认值移出零变化阶段；注册覆盖测试加强；旧架构死因改为推断表述。
> v2 → v2.1 修订：补入内部 helpers/borders（focused_bg 标量缓存漏色）；
> 注册 owner 清单补全（status_widget/spaces 全家桶/enter_animation 目标色同步）；
> 原地更新伪代码修正为 build_colors 输出并递归维护子表；标量缓存禁令限定为
> 模块生命周期。

## 1. 背景与动机

当前配色架构（`sketchybar/.config/sketchybar/appearance.lua`）：Catppuccin 双主题色板
（mocha + latte），但 `M.active` 写死 mocha，latte 为死代码；颜色在配置期写死为静态值，
切换主题只能改源码 + `--reload`（会重播整个启动渐入流程）。

历史上存在过热换色架构，已被拆除：`5fe2d08`（固定深色、注释触发逻辑）→ `3b946f0`
（删 theme_watch 守护进程）→ `a765cf6`（精简 appearance 315→104 行，删动态色表机制）
→ `264b34e`（清死订阅）。弃用时用户记录的原因只有"烦、有 bug"，具体根因已无法完全还原。

**对旧架构缺陷的推断**（非完全还原的事实）：旧 `switch_theme` 依赖手工硬编码的 item
名单逐个 set 颜色，名单维护脆弱（如当时已有 `media_next`/`media_play_pause` 却漏了
`media_previous`）。这种"名单永远追不上 widget 增长"的结构很可能导致了切换后部分
widget 残留旧色。重建必须用机制保证覆盖完整性，而非靠人记名单。

## 2. 已锁定的设计决策

1. **目标**：真正的主题系统，不只是调色。
2. **浅色模式**：跟随 macOS 系统自动切换（latte 是真需求）。
3. **身份色保留彩虹（路线 A）**：身份色集中到 `appearance.lua` 登记表命名管理，
   widget 禁止裸引用 `colors.peach` 等色板色。已知代价（警报色被装饰色稀释）用户认账。
4. **切换方式**：热换色，**不 reload**。注册表驱动 + 0.2-0.3s 换色过渡。
5. **边界**：只管 sketchybar 本体。borders（jankyborders）及其他应用不联动。

## 3. 架构设计

### 3.1 三层颜色语义

```
palette (mocha/latte 纯色板，保留现状)
  └─ build_colors(P) → 中性层：pill_bg/pill_fg/bar_bg/border/text/subtext1/...
       ├─ identity 登记表（新增）：music/sys/network/git/docker/... 各 widget 固定强调色
       └─ status 语义层（新增）：ok/warn/error/info（映射到 green/yellow|peach/red/sapphire）
```

- widget 引用规则：`colors.identity.<widget>` 或 `colors.status.*` 或中性色，
  禁止裸引用色板色。
- 阶段一加入这两层时**所有数值必须与现状逐一相等**（identity.music = 现有 music
  实际用色，status.ok = 现有 green……），保证肉眼零变化。

### 3.2 M.colors 稳定引用 + 原地更新（v2 核心修正）

现状有 9 个 widget 文件顶部缓存 `local colors = appearance.colors`（media、network、
input_method、clash_tun、battery、sys、calendar、services、git）。**直接替换
`M.colors = 新表` 会让这批缓存全部指向旧 mocha 表**：切换当下正常，下一次 CPU/电池/
网络状态更新又写回旧色板——这正是"反弹"。

因此：

- `M.colors` 表对象**终身不变**，`switch_theme` 只**原地更新其内容**：
  ```lua
  -- 注意右侧必须是 build_colors 的输出（含 pill_bg/bar_bg/identity/status），
  -- 不能把纯 palette 直接写进语义颜色表
  update_colors_in_place(M.colors, build_colors(palette[theme]))
  ```
  更新函数逐 key 覆盖；identity/status 子表**保持对象不变、递归原地更新内容**；
  并删除目标表不存在于源表的旧 key（key 集一致性测试是第二道保险）。
- 约束：`build_colors` 输出的 key 集合对两个主题必须完全一致，原地更新后无残留 key。
- 新约束写入注释：**模块生命周期内不得缓存标量色值**
  （文件顶部的 `local focused_bg = colors.red` 禁止）；只允许缓存表引用
  （表内容会被原地更新）。函数体内的单次计算（如 battery 更新函数里的
  `local color = colors.green`）不跨调用持久化，不在禁止之列。
- `startup.lua`/`enter_animation.lua` 在调用时现读 `appearance.colors.bar_bg`，
  原地更新后天然正确。

### 3.3 注册表驱动的热换色

```lua
-- appearance.lua
local appliers = {}  -- name -> fn(colors)
function M.register_colors(name, fn) appliers[name] = fn end

function M.switch_theme(theme)
    if theme == M.active then return end
    M.active = theme
    update_colors_in_place(M.colors, build_colors(palette[theme]))  -- 表对象不变
    sbar.animate("linear", N, function()              -- 0.2-0.3s 过渡
        for name, fn in pairs(appliers) do fn(M.colors) end
    end)
end
```

widget 侧模式（以 battery 为例）：

```lua
local function apply_colors(C)
    -- 按当前状态（电量、充电中）用新色板重算颜色并 set
    item:set({ icon = { color = current_level_color(C) }, ... })
end
apply_colors(appearance.colors)                       -- 配置期初值
appearance.register_colors("battery", apply_colors)   -- 主题切换时重放
```

要点：

- **apply 回调必须按 widget 当前状态重算颜色**（低电时用新色板的 status.error），
  widget 需把当前状态存为局部变量（多数已有）。切换后再次状态刷新不得反弹——
  由于 M.colors 原地更新，状态刷新路径读的缓存表引用天然拿到新值，双保险。
- 覆盖完整性靠机制 + 测试（§7），不靠名单自觉。
- spaces（AeroSpace 异步创建）的 item 在创建回调里同样走 register/apply 模式；
  status_widget 等共享组件也要登记。
- **`sbar.default` 只影响之后创建的 item**：重新调用不会重染现有 item、bracket 和
  popup，各 owner 的 apply_colors 必须显式覆盖现有对象。
- **helpers/borders 特殊处理**：`borders.lua:18` 的 `local focused_bg = colors.red`
  是模块级标量缓存（内部 workspace 高亮模块，不在"外部 jankyborders 不联动"的排除
  范围内）。修复：`focused_bg` 改为运行时从语义色读取；且其 apply 重放**必须走
  `set_focused`/`set_inactive` 函数**而非直接 `sbar.set`——这两个函数会同步
  `enter_animation.update_target`（reveal 动画目标色缓存），直接 set 会导致下次
  reveal 闪回旧色。为此 borders 需记住最近一次 `distribute` 的参数
  （visible 名单 + focused 名）供重放。
- `pairs` 遍历顺序随机，各 widget 独立 set 无相互依赖，顺序无关。

### 3.4 主题检测与触发（v2：弃用 Swift 守护进程）

- **事件源**：SketchyBar 原生支持把 NSDistributedNotification 注册为自定义事件：
  ```lua
  sbar.add("event", "system_appearance_changed", "AppleInterfaceThemeChangedNotification")
  ```
  然后对某个 drawing=false 的 item `:subscribe("system_appearance_changed", ...)`。
  **不需要** Swift 常驻进程、makefile、plist、helper_build 登记、LaunchAgent 维护。
  （分布式通知不保证必达，故仍需 wake 复检兜底。）
- **启动检测（同步）**：首次配置必须在 `begin_config` **之前**知道主题，否则浅色模式
  reload 会先显示 mocha 再切 latte。启动时同步 `defaults read -g AppleInterfaceStyle`
  一次（输出 `Dark` = 深色；无输出/命令失败 = 浅色），设好 M.active 再 begin_config。
  同步读取只此一次（<100ms），可接受。
- **运行期检测（异步）**：通知回调里异步 `defaults read` + 与 M.active 比较，
  相同则零动作；generation token 防抖防重入。
- **兜底**：订阅 `system_woke` 复检一次（睡眠期间错过通知）。不要 120s 轮询。

### 3.5 换色过渡动画

- 注册表遍历包在一个 `sbar.animate("linear", ~12-18 frames)`（0.2-0.3s）里。
- 与 hidden 门控关系：切换发生在正常运行期，不走 hidden/reveal；若切换时 bar 恰好
  hidden（睡眠中），set 颜色照样生效，reveal 时已是新色。
- 与局部动画（media 换歌、按压反馈）冲突：最坏情况是局部动画被覆盖一帧，可接受。
- 性能退路：若 30+ item 同帧 animate 掉帧，退化为无动画瞬时切换 +
  仅 pill/bar 背景做动画。阶段四实测决定。

## 4. 现存问题清单（修正 v1 误判 + 重新排期）

1. ~~删除 `bar_bg`~~ **撤回**：`bar_bg` 被 `startup.lua:129`（reload 渐入）和
   `enter_animation.lua:367/374/421`（显示器/睡眠门控渐入）使用；`bar.lua` 的全透明
   只是配置隐藏期临时态，真正显示时恢复的就是 bar_bg。**保留**。
2. **`dim` 误命名 + 默认前景色问题**：`dim` 实为 pill 背景色，`install_defaults` 把默认
   icon/label 前景设成它，新 widget 不显式设色会"隐形"。**但改默认前景是视觉行为变化，
   移出零变化阶段**，放到阶段五单独评估。
3. **popup 默认值不一致**：`install_defaults` popup（alpha 0.667 圆角 6）与
   `appearance.popup_bg()` helper（alpha 0.85 圆角 12）不统一。**同样移到阶段五**。

## 5. latte 对比度验证（阶段四实机必做）

- `surface0 @ 0.667` 的 pill 叠浅色壁纸可能发灰；popup alpha 0.85 同理。
- 调节旋钮（按优先级）：latte 用 surface1/base 做 pill 底 / 提高 pill alpha / 加深 border。
- media 歌名类亮色文字（latte yellow #df8e1d、green #40a02b）对比度偏低，实机重点看。

## 6. 验收标准

1. 切换后全 bar **零残留**旧色板颜色（含状态色：低电红、CPU 档位、git dirty、clash 五态）。
2. 切换后**再次状态刷新不反弹**（M.colors 原地更新保证，测试覆盖）。
3. 切换有 0.2-0.3s 过渡，不瞬时翻转。
4. 系统外观变化后 ≤1s 内 bar 跟随；睡眠期间变化时唤醒后自动跟上。
5. 连续/重复通知不产生重复切换或闪烁。
6. 不 reload、不播放启动渐入动画、不影响 hidden 门控逻辑。

## 7. 测试计划（sketchybar/tests/，lua 直跑）

- `theme_test.lua`（新增）：
  - build_colors 输出含 identity/status 两层；两主题 key 集合完全一致；mocha 数值与
    现行硬编码值逐一相等（防阶段一引入视觉变化）。
  - **原地更新**：switch_theme 前后 `appearance.colors` 表对象为同一引用；
    identity/status 子表同为同一引用；更新后无旧 key 残留。
  - 注册表：register 后 switch_theme 调所有回调恰好一次；同主题重复切换 no-op；
    防抖 token 生效。
  - **模块注册断言**：按完整 owner 清单逐一断言已注册（防旧架构式名单漂移）：
    appearance.core（bar、sbar.default）、apple、spaces（workspace、front_app、
    aerospace_mode、workspace bracket/popup）、helpers.borders、calendar、git、
    services、media、network（含 widgets.system bracket）、input_method、clash_tun、
    battery、sys、status_widget.dingtalk、status_widget.wechat。
    已知 owner 缺少注册时测试失败；新增主题相关模块必须同步加入 owner 清单
    （清单只保护已知模块，测试无法自动发现未登记的新模块）。
    不靠扫描 `colors%.`（抓不到别名、status_widget、动态 spaces、状态回调）。
  - **反弹测试**：模拟电池低电、CPU 告警、git dirty、docker 部分运行、clash 各态，
    切主题后再触发状态刷新，断言写出的色值来自新色板。
  - detect 解析三分支（Dark / 空输出 / 命令失败 → dark/light/light，mock sbar.exec）。
- 全部现有测试保持通过；`luac -p` 全量语法检查。

## 8. 实施步骤（Codex 修订批次，每阶段独立可提交）

1. **阶段一：语义层**。只加 identity/status 层 + 登记表；widget 改语义引用；
   **数值与现状完全一致，肉眼零变化**；不动 dim/popup/bar_bg。
2. **阶段二：原地更新 + 注册表**。M.colors 稳定引用机制；逐模块加状态感知
   apply_colors 并注册；手动触发 switch_theme 验证热换色与过渡动画；不接系统事件。
3. **阶段三：自动切换**。原生 NSDistributedNotification 事件注册 + 启动同步检测 +
   运行期异步检测 + 防抖 + system_woke 复检。
4. **阶段四：实机验证**。latte 对比度（§5）、30+ item 动画性能、各状态反弹实测（§6）。
5. **阶段五（独立评估）**：dim 改名/默认前景修正、popup 默认值统一——单独目测决定，
   与主题功能解耦。

## 9. 已知限制与风险

- 注册表只能保证"注册了的必然切换"，"该注册的都注册了"靠 §7 的模块注册断言兜底。
- 分布式通知可能延迟或丢失（Apple 官方说明）→ wake 复检覆盖主漏网场景；极端情况
  （通知丢失且未睡眠）等下次外观变化自愈。
- 模块级标量色值缓存禁令靠 code review + 注释维持，无法在运行时强制；
  helpers/borders 的 focused_bg 是已知现存违例，阶段二一并修复。
- borders 不联动是明确决定：切浅色后窗口边框仍是 peach，用户认账。
