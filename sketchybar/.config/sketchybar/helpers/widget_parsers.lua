local M = {}

local UINT64_SIGNED_MAX = "9223372036854775807"
local UINT64_MODULUS = "18446744073709551616"

local function subtract_decimal(left, right)
	local result, borrow = {}, 0
	local offset = #left - #right
	for i = #left, 1, -1 do
		local right_index = i - offset
		local digit = tonumber(left:sub(i, i)) - borrow
		if right_index > 0 then
			digit = digit - tonumber(right:sub(right_index, right_index))
		end
		if digit < 0 then
			digit = digit + 10
			borrow = 1
		else
			borrow = 0
		end
		table.insert(result, 1, tostring(digit))
	end
	local normalized = table.concat(result):gsub("^0+", "")
	return normalized ~= "" and normalized or "0"
end

-- ioreg renders negative battery telemetry as wrapped uint64 values.
function M.parse_ioreg_integer(value)
	if not value then
		return nil
	end
	if value:sub(1, 1) == "-" then
		return tonumber(value)
	end
	if #value > #UINT64_SIGNED_MAX
		or (#value == #UINT64_SIGNED_MAX and value > UINT64_SIGNED_MAX)
	then
		return -tonumber(subtract_decimal(UINT64_MODULUS, value))
	end
	return tonumber(value)
end

function M.network_kind(port, iface)
	port = (port or ""):lower()
	if port:find("wi%-fi") or port:find("airport") then
		return "wifi"
	end
	if port:find("iphone") or port:find("mobile") or port:find("cellular") then
		return "hotspot"
	end
	if port:find("ethernet")
		or port:find("lan")
		or port:find("usb")
		or port:find("thunderbolt")
	then
		return "ethernet"
	end
	if iface == "en0" then
		return "wifi"
	end
	if iface and (iface:match("^en%d+$") or iface:match("^bridge%d+$")) then
		return "ethernet"
	end
	return "unknown"
end

return M
