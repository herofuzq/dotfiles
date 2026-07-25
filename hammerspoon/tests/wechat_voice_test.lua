local source = debug.getinfo(1, "S").source:sub(2)
local repo_root = source:match("^(.*)hammerspoon/tests/") or ""
package.path = repo_root .. "hammerspoon/.hammerspoon/?.lua;" .. package.path

local wechat_voice = require("wechat_voice")

assert(
	wechat_voice.isProbeTrigger(
		55,
		{ cmd = true },
		"com.tencent.inputmethod.wetype.pinyin",
		55
	),
	"a plain left Command event in WeChat should start the short voice-window probe"
)
assert(
	not wechat_voice.isProbeTrigger(
		55,
		{ cmd = true, ctrl = true, alt = true },
		"com.tencent.inputmethod.wetype.pinyin",
		55
	),
	"Hyper must not start the voice-window probe"
)
assert(
	not wechat_voice.isProbeTrigger(55, { cmd = true }, "com.apple.keylayout.ABC", 55),
	"Command in ABC must not start the voice-window probe"
)
assert(
	not wechat_voice.isProbeTrigger(
		54,
		{ cmd = true },
		"com.tencent.inputmethod.wetype.pinyin",
		55
	),
	"only the observed left Command event should start the probe"
)

local voice_window = {
	kCGWindowOwnerName = "微信输入法",
	kCGWindowIsOnscreen = true,
	kCGWindowLayer = 2147483629,
	kCGWindowBounds = { Width = 200, Height = 130, X = 860, Y = 980 },
}
assert(
	wechat_voice.isVoiceWindow(voice_window),
	"the observed WeChat 200x130 overlay should identify active voice input"
)
voice_window.kCGWindowBounds.Width = 220
assert(
	not wechat_voice.isVoiceWindow(voice_window),
	"other WeChat input-method overlays must not be treated as voice input"
)
assert(
	wechat_voice.probeAction(false, true) == "start",
	"the voice overlay appearing should start voice mode"
)
assert(
	wechat_voice.probeAction(true, false) == "finish",
	"the voice overlay disappearing should finish voice mode"
)
assert(
	wechat_voice.probeAction(true, true) == nil,
	"an unchanged voice overlay must not retrigger voice mode"
)
assert(
	wechat_voice.shouldShowHud(true, false, false),
	"active voice input should keep the HUD visible after switching to ABC"
)
assert(
	not wechat_voice.shouldShowHud(false, false, false),
	"the regular HUD should remain hidden in ABC"
)

print("wechat_voice_test: ok")
