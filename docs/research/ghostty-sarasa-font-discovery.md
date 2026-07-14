# Ghostty、Kitty 与 Sarasa 字体发现调查

调查日期：2026-07-14
范围：Ghostty 1.3.1、macOS/CoreText、`Sarasa Term SC Nerd`、官方非 Nerd 版 `Sarasa Mono SC` / `Sarasa Term SC`。本调查没有安装、删除字体，也没有修改终端配置。

## 结论

1. **`Sarasa Mono SC` 是官方存在且可以用于 Ghostty 的字体 family。** `Mono` 使用 Iosevka 拉丁字符并保留连字，破折号为全角；`Term` 同样使用 Iosevka，破折号为半角；`Fixed` 关闭连字。`SC` 代表简体中文地区字形。官方 release 同时提供 Mono/SC 与 Term/SC 的单 family、单语言 TTF 包。对终端而言，`Sarasa Term SC` 通常语义更贴切，但两者都可用，最终以 Ghostty 是否能枚举为准。
   来源：[Sarasa Gothic README](https://github.com/be5invis/Sarasa-Gothic#what-are-the-names)、[官方 Releases](https://github.com/be5invis/Sarasa-Gothic/releases)

2. **不需要删除现有 NF 字体。** `Sarasa Term SC Nerd` 项目明确说明原始 `Sarasa Term SC` 与 Nerd 版可共存。该 Nerd 版是第三方补丁字体，基于官方 Sarasa Term SC，再合并 Nerd Fonts 并修改部分字体元数据；它不是 Sarasa Gothic 上游发布的标准 family。
   来源：[laishulu/Sarasa-Term-SC-Nerd README](https://github.com/laishulu/Sarasa-Term-SC-Nerd#特性)

3. **Kitty 能识别而 Ghostty 不能，不能再解释成“CoreText 完全没有注册字体”。** 两者在 macOS 都会使用 CoreText，但发现路径不同：Ghostty 1.3.1 从 family name 构造 descriptor、创建经过过滤的 font collection，再取匹配项；Kitty 从系统可用字体全集开始枚举，并按规范化的 family、PostScript name、full name 建索引。因此同一字体可能被 Kitty 的宽松索引找到，却没有通过 Ghostty 的 family 查询。进程内字体缓存也仍是合理嫌疑，但没有找到官方资料证明本例就是缓存导致。
   来源：[Ghostty 1.3.1 `discovery.zig` family 查询](https://github.com/ghostty-org/ghostty/blob/332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28/src/font/discovery.zig#L155-L168)、[Ghostty collection 匹配](https://github.com/ghostty-org/ghostty/blob/332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28/src/font/discovery.zig#L345-L368)、[Kitty CoreText 全集枚举](https://github.com/kovidgoyal/kitty/blob/83ffaf60bfbbf89aa4bc727b9dc4ec0c2a71c6f8/kitty/core_text.m#L256-L288)、[Kitty family/PostScript/full-name 索引](https://github.com/kovidgoyal/kitty/blob/83ffaf60bfbbf89aa4bc727b9dc4ec0c2a71c6f8/kitty/fonts/core_text.py#L26-L59)

4. **Ghostty 的决定性测试是它自己能否按 family 找到字体。** 官方配置文档要求 `font-family` 使用 `ghostty +list-fonts` 给出的有效值；1.3.1 源码说明 `+list-fonts --family=X` 采用与配置项相同的处理方式。因此 Kitty、字体册或字体文件里的名称只能作为线索，不能替代 Ghostty 自身的查询结果。
   来源：[Ghostty `font-family` 文档](https://ghostty.org/docs/config/reference#font-family)、[Ghostty 1.3.1 `list_fonts.zig`](https://github.com/ghostty-org/ghostty/blob/332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28/src/cli/list_fonts.zig#L38-L61)

5. **官方 Homebrew 方案存在，但不一定是最小化诊断方案。** 官方 cask 是 `font-sarasa-gothic`，安装命令为 `brew install --cask font-sarasa-gothic`。Homebrew API 显示它安装的是包含多个 family 的 `Sarasa-SuperTTC.ttc` 到 `~/Library/Fonts`，而不是只安装 `Sarasa Mono SC`。Sarasa 上游特别警告大型 TTC 的旧、新版本可能令操作系统或软件缓存出现问题。因此若目标是隔离 Ghostty 的匹配问题，官方 release 的单 family、单语言 TTF 包比 SuperTTC 更小、更容易排查；若偏好 Homebrew 管理，则可使用官方 cask，但应知道它会一次安装完整 SuperTTC。
   来源：[Homebrew `font-sarasa-gothic`](https://formulae.brew.sh/cask/font-sarasa-gothic)、[Homebrew cask API](https://formulae.brew.sh/api/cask/font-sarasa-gothic.json)、[Sarasa 上游缓存警告](https://github.com/be5invis/Sarasa-Gothic#note)

6. **没有找到 Ghostty 官方 issue/discussion 对“macOS 上 Ghostty 不识别 Sarasa Term SC Nerd、Kitty 却能识别”这一精确组合的确认。** 当前证据足以说明发现机制差异，却不足以把它定性为已知 Ghostty bug。

## 建议的无损验证顺序

保留现有 `Sarasa Term SC Nerd`，并列安装官方非 Nerd 版后：

```sh
ghostty +list-fonts --family='Sarasa Mono SC'
ghostty +list-fonts --family='Sarasa Term SC'
```

如果 1.3.1 本机 CLI 支持相应参数，再分别用 `+show-face` 检查中英文实际 face。安装后应完全退出并重启 Ghostty，避免仅重载配置留下进程级缓存变量。

配置候选应只使用 Ghostty 确实列出的名称，例如：

```ini
font-family = JetBrains Maple Mono
font-family = Sarasa Term SC
```

或：

```ini
font-family = JetBrains Maple Mono
font-family = Sarasa Mono SC
```

如果两者都能识别，终端场景优先试 `Sarasa Term SC`；如果只有一个能识别，就使用 Ghostty 能列出的那个。

## 本机验证结果

本机随后通过 Homebrew 安装了 `font-sarasa-gothic 1.0.40`，与已有的
`font-sarasa-nerd 2.3.1` 和 `font-jetbrains-maple-mono-nf 1.2304.79`
并存，没有删除 NF 字体。沙箱内的 CoreText 枚举只返回系统字体，属于假阴性；
在沙箱外使用 Ghostty、Kitty 和 AppKit 重新枚举后，三套字体均可识别。

Ghostty 1.3.1 能列出并匹配：

- `JetBrains Maple Mono`
- `Sarasa Mono SC`
- `Sarasa Term SC`
- `Sarasa Term SC Nerd`

`ghostty +show-face` 还显示 `JetBrains Maple Mono` 自身包含中文字符，因此将
Sarasa 配置为第二个 `font-family` 时，它只会作为缺字回退，而不会自动接管中文。
