# Ghostty Catppuccin Mocha Implementation Plan

> **For agentic workers:** Execute this single configuration task inline and verify with Ghostty's parser.

**Goal:** Use Catppuccin Mocha with a fully opaque, unblurred terminal background.

**Architecture:** Change only Ghostty's theme, opacity, and blur settings. Preserve the transparent macOS titlebar and visible window buttons.

**Tech Stack:** Ghostty 1.3.1 configuration

## Global Constraints

- Keep `macos-titlebar-style = transparent`.
- Keep `macos-window-buttons = visible`.
- Do not commit without an explicit user request.

---

### Task 1: Apply and verify the appearance settings

**Files:**
- Modify: `ghostty/.config/ghostty/config`

- [x] Confirm the current configuration uses `theme = Mellow`, `background-opacity = 0.8`, and `background-blur = 10`.
- [x] Replace those values with `theme = Catppuccin Mocha`, `background-opacity = 1`, and `background-blur = 0`.
- [x] Run `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config` and confirm it exits successfully.
- [x] Confirm the theme through `+show-config`; Ghostty omits settings that equal defaults, so confirm opacity, blur, and preserved titlebar settings directly in the validated source config.
- [x] Run `git diff --check` and reload Ghostty configuration.
