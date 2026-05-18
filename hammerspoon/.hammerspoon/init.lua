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

local function toggle()
  local now = realSource()
  _Current = (now == EN_ID) and EN or ZH

  hs.eventtap.keyStroke({"ctrl"}, "space")

  _Current = (_Current == EN) and ZH or EN
  hs.alert.show(_Current, 0.4)
end

-- ============================================================
-- 规则：App 聚焦时自动切换（静默）
-- ============================================================
local EN_APPS = {
  ["com.apple.Terminal"] = true,
  ["com.googlecode.iterm2"] = true,
  ["org.alacritty"] = true,
  ["com.microsoft.VSCode"] = true,
  ["com.jetbrains.intellij"] = true,
  ["com.jetbrains.intellij.ce"] = true,
  ["md.obsidian"] = true,
  ["com.raycast.macos"] = true,
  ["org.vim.MacVim"] = true,
}

local ZH_APPS = {
  ["com.tencent.xinWeChat"] = true,
  ["com.apple.Notes"] = true,
  ["com.apple.mail"] = true,
}

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(_, app)
  if not app then return end
  local id = app:bundleID()
  local now = realSource()
  if EN_APPS[id] and now ~= EN_ID then
    _Current = EN
    hs.eventtap.keyStroke({"ctrl"}, "space")
  elseif ZH_APPS[id] and now ~= ZH_ID then
    _Current = ZH
    hs.eventtap.keyStroke({"ctrl"}, "space")
  end
end)

-- ============================================================
-- ESC → 英文（不消费事件，透传给应用）
-- ============================================================
_ESCTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
  if event:getKeyCode() ~= 53 then return false end
  local app = hs.application.frontmostApplication()
  if app and EN_APPS[app:bundleID()] then return false end
  if realSource() ~= EN_ID then
    _Current = EN
    hs.eventtap.keyStroke({"ctrl"}, "space")
  end
  return false
end)
_ESCTap:start()

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
