-- 显示宽度工具：汉字/全角算 2 宽度，其余算 1。
-- 用于按"视觉宽度"而非字符数截断文本（SketchyBar 的 max_chars 只数字符个数）。
-- 手工 UTF-8 解码，不依赖 utf8 标准库，对残缺字节流也不会报错。
local M = {}

-- 常见宽字符区间（East Asian Wide / Fullwidth 的近似集合）
local function is_wide(cp)
	return (cp >= 0x1100 and cp <= 0x115F) -- Hangul Jamo
		or cp == 0x2329
		or cp == 0x232A
		or (cp >= 0x2E80 and cp <= 0xA4CF) -- CJK 部首/假名/汉字/注音等
		or (cp >= 0xAC00 and cp <= 0xD7A3) -- Hangul Syllables
		or (cp >= 0xF900 and cp <= 0xFAFF) -- CJK 兼容汉字
		or (cp >= 0xFE30 and cp <= 0xFE4F) -- CJK 兼容形式
		or (cp >= 0xFF00 and cp <= 0xFF60) -- 全角 ASCII/半角片假名边界
		or (cp >= 0xFFE0 and cp <= 0xFFE6) -- 全角符号
		or (cp >= 0x20000 and cp <= 0x3FFFD) -- CJK 扩展 B 及以后
end

-- 返回不超过 width_budget 显示宽度的最大字符数。
-- 宽字符放不下时整体跳过（不留半格）；全部放得下则返回总字符数。
function M.chars_within_width(s, width_budget)
	local width = 0
	local count = 0
	local i = 1
	local len = #s
	while i <= len do
		local b = s:byte(i)
		local cp, size
		if b < 0x80 then
			cp, size = b, 1
		elseif b < 0xE0 then
			cp, size = (b & 0x1F) << 6, 2
			if i + 1 <= len then cp = cp | (s:byte(i + 1) & 0x3F) end
		elseif b < 0xF0 then
			cp, size = (b & 0x0F) << 12, 3
			if i + 1 <= len then cp = cp | ((s:byte(i + 1) & 0x3F) << 6) end
			if i + 2 <= len then cp = cp | (s:byte(i + 2) & 0x3F) end
		else
			cp, size = (b & 0x07) << 18, 4
			if i + 1 <= len then cp = cp | ((s:byte(i + 1) & 0x3F) << 12) end
			if i + 2 <= len then cp = cp | ((s:byte(i + 2) & 0x3F) << 6) end
			if i + 3 <= len then cp = cp | (s:byte(i + 3) & 0x3F) end
		end
		local w = is_wide(cp) and 2 or 1
		if width + w > width_budget then
			break
		end
		width = width + w
		count = count + 1
		i = i + size
	end
	return count
end

return M
