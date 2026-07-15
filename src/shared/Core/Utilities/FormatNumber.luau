--!strict
-- FormatNumber.luau
-- Formats numbers into engineering notation suffixes (e.g. 150K, 1.2T).

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}

local function FormatNumber(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local exp = math.floor(math.log10(value) / 3)
	local suffix = SUFFIXES[exp + 1] or "e" .. tostring(exp * 3)
	local shortValue = value / (10 ^ (exp * 3))
	
	-- Format with 1 decimal place if it has a fractional part, else no decimals
	local formatted = string.format("%.1f", shortValue)
	if string.sub(formatted, -2) == ".0" then
		formatted = string.sub(formatted, 1, -3)
	end
	return formatted .. suffix
end

return FormatNumber
