-- ============================================================
-- Hyper (CapsLock) + Tab → 返回上一个桌面空间
-- 记录上一个桌面编号，发送对应的 hyper+数字 快捷键
-- ============================================================

local _currentSpace = hs.spaces.focusedSpace()
local _prevSpace = nil
local _programmatic = false

hs.spaces.watcher.new(function()
    hs.timer.doAfter(0.2, function()
        local newSpace = hs.spaces.focusedSpace()
        if newSpace ~= _currentSpace then
            if not _programmatic then
                _prevSpace = _currentSpace
            end
            _programmatic = false
            _currentSpace = newSpace
        end
    end)
end):start()

local function sendHyperKey(key)
    local down = hs.eventtap.event.newKeyEvent({"ctrl", "alt", "cmd"}, key, true)
    local up   = hs.eventtap.event.newKeyEvent({"ctrl", "alt", "cmd"}, key, false)
    down:post()
    up:post()
end

local tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local f = event:getFlags()
    if f.ctrl and f.alt and f.cmd then
        if event:getKeyCode() == hs.keycodes.map.tab then
            if _prevSpace then
                local uuid = hs.screen.mainScreen():getUUID()
                local spaces = hs.spaces.allSpaces()[uuid]
                if spaces then
                    for i, sid in ipairs(spaces) do
                        if sid == _prevSpace then
                            _programmatic = true
                            _prevSpace = _currentSpace
                            sendHyperKey(tostring(i))
                            break
                        end
                    end
                end
            end
        end
    end
    return false
end)
tap:start()
