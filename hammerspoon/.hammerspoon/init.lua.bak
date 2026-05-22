-- ============================================================
-- 输入法切换 - fcitx5-remote
-- 1 = 英文, 2 = 中文
-- ============================================================
local FCITX = "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"
local EN = 1
local ZH = 2

-- fcitx5 的 sourceID（macism + currentSourceID 共用）
local FCITX5_SRC = "org.fcitx.inputmethod.Fcitx5.zhHans"

local function isUsingFcitx5()
  return hs.keycodes.currentSourceID() == FCITX5_SRC
end

local function realSource()
  local out = hs.execute("'" .. FCITX .. "'", true)
  return out and tonumber(out) == 2 and ZH or EN
end

local _toggled = 0

local function toggle()
  _toggled = hs.timer.secondsSinceEpoch()

  -- 如果当前输入源是 ABC（非 fcitx5），切到 fcitx5（macism 自带等待）
  if not isUsingFcitx5() then
    hs.execute("macism " .. FCITX5_SRC .. " 150", true)
    hs.alert.show("中文", 0.4)
    return
  end

  -- 已在 fcitx5 中，正常切换中英文
  local now = realSource()
  if now == ZH then
    hs.execute("'" .. FCITX .. "' -c", true)
    hs.alert.show("英文", 0.4)
  else
    hs.execute("'" .. FCITX .. "' -o", true)
    hs.alert.show("中文", 0.4)
  end
end

-- ============================================================
-- 中文状态进入以下 App 时弹提醒
-- ============================================================
local WARN_APPS = {
  ["com.apple.Terminal"] = true,
  ["com.googlecode.iterm2"] = true,
  ["org.alacritty"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["com.cmuxterm.app"] = true,
  ["com.microsoft.VSCode"] = true,
  ["com.jetbrains.intellij"] = true,
  ["com.jetbrains.intellij.ce"] = true,
  ["md.obsidian"] = true,
  ["com.raycast.macos"] = true,
  ["com.raycast-x.macos"] = true,
  ["org.vim.MacVim"] = true,
}

local function warnEN(id)
  if not WARN_APPS[id] then return end
  if hs.timer.secondsSinceEpoch() - _toggled < 2 then return end
  -- 当前输入源不是 fcitx5（如 ABC）→ 不警告，因为 fcitx5 未激活
  if not isUsingFcitx5() then return end
  if realSource() == ZH then
    hs.alert.show("⚠️ 中文输入中", 1.0)
  end
end

_WarnWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated and app then
    warnEN(app:bundleID())
  end
end)
_WarnWatcher:start()

-- 启动时对当前前台应用做一次初始检查
do
  local frontApp = hs.application.frontmostApplication()
  if frontApp then warnEN(frontApp:bundleID()) end
end

-- 已移除 hs.window.filter 订阅，避免与 hs.application.watcher 双重触发

-- ============================================================
-- CapsLock (Hyper) 单独按下 → 切换中英文
-- ============================================================
local pressed = false
local used    = false

_InputTap = hs.eventtap.new(
  {hs.eventtap.event.types.flagsChanged,
   hs.eventtap.event.types.keyDown,
   hs.eventtap.event.types.leftMouseDown,
   hs.eventtap.event.types.rightMouseDown,
   hs.eventtap.event.types.otherMouseDown},
  function(event)
    local etype = event:getType()
    local f = event:getFlags()
    local hyper = f.ctrl and f.alt and f.cmd

    if etype == hs.eventtap.event.types.flagsChanged then
      if hyper and not pressed then
        -- Hyper 刚刚按下
        pressed, used = true, false
      elseif hyper and pressed then
        -- Hyper 保持期间修饰键发生了变化（如加了 Shift）→ 视为组合键
        used = true
      elseif not hyper and pressed then
        -- Hyper 释放
        pressed = false
        if not used then toggle() end
      end
    elseif pressed then
      -- 任何非修饰键事件（按键、鼠标点击）在 Hyper 按住期间 → 视为组合键
      used = true
    end
    return false
  end
)
_InputTap:start()
