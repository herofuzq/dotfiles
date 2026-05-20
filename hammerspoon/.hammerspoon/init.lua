-- ============================================================
-- 输入法切换 - fcitx5-remote
-- 1 = 英文, 2 = 中文
-- ============================================================
local FCITX = "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-remote"
local EN = 1
local ZH = 2

_Current = EN

local function fcitx(cmd)
  hs.execute("'" .. FCITX .. "' " .. cmd, true)
end

local function realSource()
  local out = hs.execute("'" .. FCITX .. "'", true)
  return out and out:match("2") and ZH or EN
end

local _toggled = 0

local function toggle()
  _toggled = hs.timer.secondsSinceEpoch()
  local now = realSource()

  if now == ZH then
    fcitx("-c")
    _Current = EN
    hs.alert.show("英文", 0.4)
  else
    fcitx("-o")
    _Current = ZH
    hs.alert.show("中文", 0.4)
  end
end

-- ============================================================
-- 终端/IDE 类 App → 自动切英文
-- ============================================================
local AUTO_EN = {
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

local function autoEN(id)
  if not AUTO_EN[id] then return end
  if hs.timer.secondsSinceEpoch() - _toggled < 2 then return end
  if realSource() == ZH then
    hs.alert.show("⚠️ 中文输入中", 1.0)
  end
end

_AutoWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated then
    autoEN(app:bundleID())
  end
end)
_AutoWatcher:start()

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(_, app)
  if app then autoEN(app:bundleID()) end
end)

-- ============================================================
-- CapsLock (Hyper) 单独按下 → 切换中英文
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
