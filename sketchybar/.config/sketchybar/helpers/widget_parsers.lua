-- ========== Widget 数据解析 ==========
-- 处理 widget 从外部命令读取的 raw 输出：
--   - parse_ioreg_integer: ioreg 输出的大整数（UInt64）→ Lua number
--   - subtract_decimal / parse helpers: 各种数值字段的安全解析
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

-- Convert the AppleSmartBattery ioreg snapshot into the state used by the UI.
function M.parse_battery(raw)
	raw = raw or ""
	local cur_raw = raw:match('"CurrentCapacity"%s*=%s*(%d+)')
	local max_raw = raw:match('"MaxCapacity"%s*=%s*(%d+)')
	if not cur_raw or not max_raw then
		return nil
	end

	local function number_field(key)
		return M.parse_ioreg_integer(raw:match('"' .. key .. '"%s*=%s*(-?%d+)'))
	end

	local max_cap = tonumber(max_raw) or 0
	if max_cap <= 0 then
		return nil
	end

	local min_left = number_field("AvgTimeToEmpty")
	if min_left and min_left >= 65535 then
		min_left = nil
	end

	local system_power = number_field("SystemPowerIn")
	local battery_power = number_field("BatteryPower")
	local amperage = number_field("InstantAmperage") or number_field("Amperage")
	local voltage = number_field("Voltage") or number_field("AppleRawBatteryVoltage")
	local current_watts

	if system_power and system_power > 0 then
		current_watts = system_power / 1000
	elseif battery_power and battery_power ~= 0 then
		current_watts = math.abs(battery_power) / 1000
	elseif amperage and voltage and amperage ~= 0 and voltage > 0 then
		current_watts = math.abs(amperage * voltage) / 1000000
	end
	if current_watts and current_watts > 500 then
		current_watts = nil
	end

	return {
		ac = (raw:match('"ExternalConnected"%s*=%s*%w+') or ""):find("Yes") ~= nil,
		charging = (raw:match('"IsCharging"%s*=%s*%w+') or ""):find("Yes") ~= nil,
		current_watts = current_watts,
		min_left = min_left,
		percent = math.floor((tonumber(cur_raw) or 0) * 100 / max_cap + 0.5),
	}
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
