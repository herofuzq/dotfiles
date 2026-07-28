# Hammerspoon Theme Chooser Palette Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在原生 `hs.chooser` 的每个主题行左侧显示 macOS 当前 dark/light flavor 的五色色板缩略图。

**Architecture:** `theme.lua` 继续作为唯一 Hammerspoon 配色数据源，新增每套 palette 的 `accent` 和纯数据接口 `preview_colors(scheme, flavor)`。`theme_switcher.lua` 使用 `hs.canvas` 把这五个颜色画成内存 `hs.image`，每次打开 chooser 时重新生成；任何图片生成错误只降级为纯文字 choice。

**Tech Stack:** Lua 5.5、Hammerspoon `hs.chooser` / `hs.canvas` / `hs.image`、现有 Lua assert 测试。

## Global Constraints

- 保留原生 `hs.chooser`、`Hyper+Shift+T`、搜索、键盘导航、`Esc` 和现有主题切换顺序。
- 只展示 macOS 当前 flavor；不增加独立 dark/light 开关。
- 缩略图顺序固定为 `base / accent / green / yellow / red`，其中 `base` 宽度略大。
- 图片只存在内存，不写缓存文件，不增加 watcher、轮询、动画或自定义窗口。
- 图片生成失败时仍返回可选择的纯文字 choice。
- 不修改 SketchyBar、jankyborders、状态文件与 HUD 的既有运行逻辑。

---

### Task 1: Add preview colors to the theme service

**Files:**
- Modify: `hammerspoon/.hammerspoon/theme.lua:17-160`
- Test: `hammerspoon/tests/theme_test.lua:45-65`

**Interfaces:**
- Consumes: `M.schemes[scheme].dark/light`、`M.raw_palettes[palette_name]`
- Produces: `theme.preview_colors(scheme, flavor) -> { base, accent, green, yellow, red }`，每个值为 `hs.drawing.color` 兼容表

- [ ] **Step 1: Write the failing cross-palette test**

把跨应用槽位检查扩展为 `accent`，并按 SketchyBar scheme 的 `window_border` 角色校验：

```lua
local slots = { "base", "surface0", "subtext1", "green", "yellow", "red" }
for scheme_name, mapping in pairs(theme.schemes) do
	local accent_role = appearance.schemes[scheme_name].window_border
	for _, flavor in ipairs({ "dark", "light" }) do
		local theme_palette = theme.raw_palettes[mapping[flavor]]
		local sketchybar_palette = appearance.palette[appearance.schemes[scheme_name][flavor]]
		for _, slot in ipairs(slots) do
			assert(theme_palette[slot] == sketchybar_palette[slot])
		end
		assert(theme_palette.accent == sketchybar_palette[accent_role])
	end
end

local preview = theme.preview_colors("everforest", "dark")
assert(preview.base.alpha == 1.0)
assert(preview.accent.alpha == 1.0)
assert(preview.green.alpha == 1.0)
assert(preview.yellow.alpha == 1.0)
assert(preview.red.alpha == 1.0)

for _, flavor in ipairs({ "dark", "light" }) do
	for _, scheme_name in ipairs(theme.scheme_order) do
		local colors = assert(theme.preview_colors(scheme_name, flavor))
		assert(colors.base and colors.accent and colors.green and colors.yellow and colors.red)
	end
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
lua hammerspoon/tests/theme_test.lua
```

Expected: FAIL because `raw_palettes[*].accent` and `theme.preview_colors` do not exist.

- [ ] **Step 3: Add the accent values and pure preview API**

In every dark/light entry of `M.raw_palettes`, add the scheme representative color already defined by SketchyBar:

```lua
-- Examples; repeat with the exact existing scheme role for all 12 palettes.
mocha = {
	base = 0xff1e1e2e,
	accent = 0xffcba6f7, -- Catppuccin mauve
	-- existing slots...
},
everforest_dark = {
	base = 0xff2d353b,
	accent = 0xffa7c080, -- Everforest green
	-- existing slots...
},
```

Add:

```lua
function M.preview_colors(scheme, flavor)
	local mapping = M.schemes[scheme]
	if not mapping or (flavor ~= "dark" and flavor ~= "light") then
		return nil
	end
	local palette = M.raw_palettes[mapping[flavor]]
	return {
		base = color(palette.base, 1.0),
		accent = color(palette.accent, 1.0),
		green = color(palette.green, 1.0),
		yellow = color(palette.yellow, 1.0),
		red = color(palette.red, 1.0),
	}
end
```

- [ ] **Step 4: Run focused and full tests**

Run:

```bash
lua hammerspoon/tests/theme_test.lua
for test in sketchybar/tests/*_test.lua hammerspoon/tests/*_test.lua; do lua "$test" || exit 1; done
```

Expected: all tests PASS with no new warning.

- [ ] **Step 5: Commit Task 1**

```bash
git add hammerspoon/.hammerspoon/theme.lua hammerspoon/tests/theme_test.lua
git commit -m "feat(theme): expose chooser preview colors"
```

---

### Task 2: Render native chooser palette thumbnails

**Files:**
- Modify: `hammerspoon/.hammerspoon/theme_switcher.lua:96-170`
- Test: `hammerspoon/tests/theme_switcher_test.lua:22-92`
- Test: `hammerspoon/tests/theme_integration_test.lua`
- Modify: `hammerspoon/.hammerspoon/README.md`

**Interfaces:**
- Consumes: `theme.preview_colors(scheme, flavor)`, `theme.current_flavor()`
- Produces: `controller.choices() -> choice[]`, where each choice optionally contains `image = hs.image`
- Internal: `palette_image(preview) -> hs.image|nil`

- [ ] **Step 1: Write failing choice and fallback tests**

Extend the theme stub with `current_flavor`, inject `image_for_scheme`, and assert both success and failure:

```lua
local image_calls = {}
local preview_image = {}
local controller = switcher.create({
	-- existing dependencies...
	image_for_scheme = function(name, flavor)
		image_calls[#image_calls + 1] = name .. ":" .. flavor
		if name == "rosepine" then error("render failed") end
		return preview_image
	end,
	theme = {
		-- existing methods...
		current_flavor = function() return "dark" end,
	},
})

local choices = controller.choices()
assert(choices[1].image == preview_image)
assert(choices[3].image == nil, "render failure must fall back to text")
assert(image_calls[1] == "catppuccin:dark")
```

Add a static integration assertion that `install()` sets the flavor-aware placeholder:

```lua
assert(source:find('chooser:placeholderText("Theme · " .. flavor_label .. " · follows macOS"', 1, true))
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
lua hammerspoon/tests/theme_switcher_test.lua
lua hammerspoon/tests/theme_integration_test.lua
```

Expected: FAIL because choices ignore `image_for_scheme` and the chooser has no flavor placeholder.

- [ ] **Step 3: Add optional image generation to the controller**

In `M.create(deps)`:

```lua
local image_for_scheme = deps.image_for_scheme

-- Inside controller.choices():
local choice = {
	text = (name == current and "✓ " or "") .. display,
	scheme = name,
}
if image_for_scheme then
	local ok, image = pcall(image_for_scheme, name, theme.current_flavor())
	if ok and image then choice.image = image end
end
choices[#choices + 1] = choice
```

Do not log a per-row rendering failure; pure-text fallback is intentional and avoids noisy reload logs.

- [ ] **Step 4: Generate a 72×34 in-memory image with `hs.canvas`**

Add a local renderer used only by `M.install()`:

```lua
local function palette_image(theme, scheme, flavor)
	local preview = theme.preview_colors(scheme, flavor)
	if not preview then return nil end

	local widths = { 24, 12, 12, 12, 12 }
	local colors = { preview.base, preview.accent, preview.green, preview.yellow, preview.red }
	local canvas = hs.canvas.new({ x = 0, y = 0, w = 72, h = 34 })
	if not canvas then return nil end

	local x = 0
	for index, width in ipairs(widths) do
		canvas:appendElements({
			type = "rectangle",
			action = "fill",
			fillColor = colors[index],
			frame = { x = x, y = 0, w = width, h = 34 },
		})
		x = x + width
	end
	local image = canvas:imageFromCanvas()
	canvas:delete()
	return image
end
```

Pass it into `M.create`:

```lua
image_for_scheme = function(scheme, flavor)
	return palette_image(theme, scheme, flavor)
end,
```

When opening the chooser, set the current flavor label before choices:

```lua
local flavor_label = theme.current_flavor() == "dark" and "Dark" or "Light"
chooser:placeholderText("Theme · " .. flavor_label .. " · follows macOS")
chooser:choices(controller.choices())
chooser:show()
```

- [ ] **Step 5: Document the preview**

In `hammerspoon/.hammerspoon/README.md`, update the theme chooser section:

```markdown
每个主题行左侧显示 macOS 当前 dark/light 模式下的五色色板预览：
背景、主题强调色、正常、警告、错误。预览由 `hs.canvas` 在内存中生成，
不写图片文件；生成失败时自动退回纯文字列表。
```

- [ ] **Step 6: Run all automated verification**

Run:

```bash
for test in sketchybar/tests/*_test.lua hammerspoon/tests/*_test.lua; do lua "$test" || exit 1; done
find sketchybar hammerspoon -name '*.lua' -type f -print0 | xargs -0 -n1 luac -p
git diff --check
```

Expected: all tests and syntax checks PASS.

- [ ] **Step 7: Sync and perform real GUI verification**

Run from the dotfiles root:

```bash
stow --no-folding hammerspoon
```

Do not compile any helper. Reload Hammerspoon, then verify:

1. `Hyper+Shift+T` opens six rows，并显示当前 macOS flavor 对应的色板。
2. Current Gruvbox row retains `✓`.
3. Up/down, Enter, `Esc`, and `⌘1`–`⌘6` still work.
4. 自动测试已覆盖 dark/light 两套 preview 数据；如果用户愿意临时切换系统外观，再补做另一 flavor 的目视复核。
5. 保持原始 macOS 外观和原始 scheme 不变；验证过程不主动修改系统外观。

- [ ] **Step 8: Commit Task 2**

```bash
git add hammerspoon/.hammerspoon/theme_switcher.lua \
	hammerspoon/.hammerspoon/README.md \
	hammerspoon/tests/theme_switcher_test.lua \
	hammerspoon/tests/theme_integration_test.lua
git commit -m "feat(theme): preview palettes in chooser"
```
