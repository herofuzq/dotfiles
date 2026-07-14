# Hammerspoon Floating Window Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an isolated Hammerspoon module that keeps AeroSpace floating windows above normal tiling windows without changing focus.

**Architecture:** `floating_level.lua` owns window-created detection, AeroSpace layout lookup, bounded retry, and macOS window-level updates. `init.lua` only loads the module; the existing `window_watcher.lua` and AeroSpace rules remain unchanged.

**Tech Stack:** Hammerspoon Lua, `hs.window.filter`, `hs.window.level`, `hs.task`, AeroSpace 0.21 CLI JSON output.

## Global Constraints

- Only windows reported by AeroSpace with `window-layout == "floating"` receive the macOS floating level.
- The module must not call `focus`, `activate`, or move windows.
- AeroSpace lookup retries are bounded and event-driven; no continuous polling.
- Existing unrelated `ghostty/.config/ghostty/config` changes must remain untouched.

---

### Task 1: Add the atomic floating-level module

**Files:**
- Create: `hammerspoon/.hammerspoon/floating_level.lua`

**Interfaces:**
- Consumes: Hammerspoon window-created events and `command.aerospace`.
- Produces: a global watcher named `_floatingLevel_filter` and window-level updates through `hs.window.level.floating`.

- [ ] **Step 1: Add the module with bounded AeroSpace lookup**

Implement a watcher for `hs.window.filter.windowCreated`. For each created standard window, retry after `0.30s`, `0.50s`, and `0.80s`; query `list-windows --monitor all --format "%{window-id}%{window-layout}" --json`; match the Hammerspoon window ID; set `window:setLevel(hs.window.level.floating)` only when the returned layout is `floating`.

- [ ] **Step 2: Add startup reconciliation**

After registering the watcher, iterate `hs.window.allWindows()` and schedule the same bounded lookup for each standard window. This ensures Hammerspoon reloads do not leave existing floating windows behind.

- [ ] **Step 3: Load the module from `init.lua`**

Add `require("floating_level")` beside the other independent Hammerspoon modules.

### Task 2: Validate runtime behavior

**Files:**
- Modify: none
- Test: `hammerspoon/.hammerspoon/floating_level.lua`

**Interfaces:**
- Consumes: the installed `~/.hammerspoon` configuration after Stow.
- Produces: successful Lua load and observed window-level behavior.

- [ ] **Step 1: Run Lua syntax checks**

Run `luac -p hammerspoon/.hammerspoon/floating_level.lua hammerspoon/.hammerspoon/init.lua` and require exit code 0.

- [ ] **Step 2: Deploy and reload Hammerspoon**

Run `stow --no-folding hammerspoon`, then reload through the existing Hammerspoon IPC path. Confirm the module load message or absence of reload errors.

- [ ] **Step 3: Verify a real floating window**

Create or show Typeless, query its AeroSpace layout, and confirm the Hammerspoon window level is `floating` without changing the focused window.

- [ ] **Step 4: Verify repository scope**

Run `git diff --check` and `git status --short`; only the new Hammerspoon module and `init.lua` may be changed by this task, while the pre-existing Ghostty modification remains unstaged.
