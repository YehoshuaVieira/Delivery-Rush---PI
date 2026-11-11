-- Texto para a UI no padrão brasileiro ($3.000, 1:05).

local Format = {}

function Format.Number(n: number): string
	n = math.floor((tonumber(n) or 0) + 0.5)
	local s = tostring(math.abs(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return (n < 0 and "-" or "") .. formatted
end

function Format.Money(n: number): string
	n = tonumber(n) or 0
	if n < 0 then
		return "-$" .. Format.Number(-n)
	end
	return "$" .. Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
