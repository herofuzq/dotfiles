-- ============================================================
-- 输入法自动切换
-- macism 读状态 + Ctrl+Space 切输入法
-- ============================================================
local MACISM = "/opt/homebrew/bin/macism"
local EN_ID  = "com.apple.keylayout.ABC"
local ZH_ID  = "im.rime.inputmethod.Squirrel.Hans"
local EN = "ABC"
local ZH = "鼠须管"

_Current = EN

local function realSource()
  local out = hs.execute(MACISM, true)
  if out then out = out:match("^%s*(.-)%s*$") end
  return out
end

local _toggled = 0

local function toggle()
  _toggled = hs.timer.secondsSinceEpoch()
  local now = realSource()
  _Current = (now == EN_ID) and EN or ZH

  hs.eventtap.keyStroke({"ctrl"}, "space")

  _Current = (_Current == EN) and ZH or EN
  hs.alert.show(_Current, 0.4)
end

-- ============================================================
-- 中文状态进入以下 App 时弹提醒
-- ============================================================
local WARN_APPS = {
  ["com.apple.Terminal"] = true,
  ["com.googlecode.iterm2"] = true,
  ["org.alacritty"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["com.microsoft.VSCode"] = true,
  ["com.jetbrains.intellij"] = true,
  ["com.jetbrains.intellij.ce"] = true,
  ["md.obsidian"] = true,
  ["com.raycast.macos"] = true,
  ["com.raycast-x.macos"] = true,
  ["org.vim.MacVim"] = true,
}

local function warnIfNeeded(id)
  if not WARN_APPS[id] then return end
  if hs.timer.secondsSinceEpoch() - _toggled < 2 then return end
  if realSource() ~= EN_ID then
    hs.alert.show("⚠️ 中文输入中", 1.0)
  end
end

_WarnWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated then
    warnIfNeeded(app:bundleID())
  end
end)
_WarnWatcher:start()

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(_, app)
  if app then warnIfNeeded(app:bundleID()) end
end)

-- ============================================================
-- CapsLock (Hyper) 单独按下 → 切换中英文（弹通知）
-- ============================================================
local pressed = false
local used    = false

_InputTap = hs.eventtap.new(
  {hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown},
  function(event)
    local f = event:getFlags()
    local hyper = f.ctrl and f.alt and f.cmd

    if event:getType() == hs.eventtap.event.types.flagsChanged then
      if hyper and not pressed then
        pressed, used = true, false
      elseif not hyper and pressed then
        pressed = false
        if not used then toggle() end
      end
    elseif event:getType() == hs.eventtap.event.types.keyDown and pressed then
      used = true
    end
    return false
  end
)
_InputTap:start()
