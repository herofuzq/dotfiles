package.path = "sketchybar/.config/sketchybar/?.lua;sketchybar/.config/sketchybar/?/init.lua;" .. package.path

local textwidth = require("helpers.textwidth")
local within = textwidth.chars_within_width

-- 纯 ASCII：1 字符 = 1 宽度
assert(within("hello", 14) == 5) -- 全放得下
assert(within("abcdefghijklmnop", 14) == 14) -- 16 个字母截到 14
assert(within("", 14) == 0)

-- 纯中文：1 字符 = 2 宽度，14 宽度 = 7 个汉字
assert(within("未播放", 14) == 3)
assert(within("一二三四五六七八九十", 14) == 7)

-- 中英混排：晴(2)天(2)空格(1)Sunny(5) = 10 宽度，再加空格(1)day(3) 共 14 宽度全放得下
assert(within("晴天 Sunny day", 14) == 12)
-- 追加一个字母就超预算：12 个字符处截断
assert(within("晴天 Sunny days", 14) == 12)

-- 边界：宽度 13 时下一个汉字放不下，整体跳过（不留半格）
assert(within("aaaaaaaaaaaaa中", 14) == 13) -- 13 个 a + 中(2) 超 14，截到 13

-- 全角符号算宽字符
assert(within("ａｂｃｄｅｆｇｈ", 14) == 7) -- 全角小写字母 U+FF41.. 属 0xFF00-0xFF60

-- 日文假名、韩文音节按宽字符
assert(within("あいうえおかきくけこ", 14) == 7) -- 0x3042.. 落在 0x2E80-0xA4CF
assert(within("가나다라마바사아자차", 14) == 7) -- 0xAC00-0xD7A3

-- CJK 扩展 B（4 字节 UTF-8）按宽字符
assert(within("𠀀𠀁𠀂𠀃𠀄𠀅𠀆𠀇", 14) == 7) -- U+20000..

-- 预算为 1 时汉字放不下，返回 0
assert(within("中", 1) == 0)
assert(within("a", 1) == 1)

-- 残缺 UTF-8 不报错
assert(within("\228\184", 14) >= 0)

print("textwidth_test: ok")
