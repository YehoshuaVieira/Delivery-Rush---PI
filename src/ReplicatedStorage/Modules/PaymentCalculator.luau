-- pagamento = base da área × multiplicador de velocidade × gorjeta × combo. Só o servidor paga; o cliente usa para estimar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))

local PaymentCalculator = {}

-- Multiplicador pela razão tempo real / ideal, interpolado na SpeedCurve (rápido 2,5x ... atrasado 0,4x, nunca zero).
function PaymentCalculator.GetSpeedMultiplier(realTime: number, idealTime: number): number
	if idealTime <= 0 then
		return 1
	end
	local curve = GameConfig.Payment.SpeedCurve
	local ratio = math.max(realTime, 0) / idealTime

	if ratio <= curve[1].Ratio then
		return curve[1].Multiplier
	end
	if ratio >= curve[#curve].Ratio then
		return curve[#curve].Multiplier
	end
	for i = 1, #curve - 1 do
		local a, b = curve[i], curve[i + 1]
		if ratio <= b.Ratio then
			local t = (ratio - a.Ratio) / (b.Ratio - a.Ratio)
			return a.Multiplier + (b.Multiplier - a.Multiplier) * t
		end
	end
	return curve[#curve].Multiplier
end

-- Bônus de combo (0 = sem bônus). combo = quantas entregas rápidas seguidas (incluindo a atual).
function PaymentCalculator.GetComboBonus(combo: number): number
	local cfg = GameConfig.Payment.Combo
	if combo <= 1 then
		return 0
	end
	return math.min((combo - 1) * cfg.BonusPerCombo, cfg.MaxBonus)
end

-- Tempo ideal (s) para um trajeto com essa distância em linha reta.
function PaymentCalculator.GetIdealTime(straightDistance: number, isSpecial: boolean?): number
	local cfg = GameConfig.Orders
	local t = (straightDistance * cfg.RouteFactor) / cfg.ReferenceSpeed + cfg.ExtraTime
	if isSpecial then
		t *= cfg.SpecialTimeMultiplier
	end
	return t
end

-- Pagamento base do pedido: valor base + bônus de distância, multiplicado pela área de ENTREGA.
function PaymentCalculator.GetBasePay(areaId: number, straightDistance: number, isSpecial: boolean?): number
	local cfg = GameConfig.Orders
	local area = AreaConfig.Get(areaId)
	local areaMultiplier = area and area.PayMultiplier or 1
	local pay = (cfg.BasePay + straightDistance * cfg.PayPerStud) * areaMultiplier
	if isSpecial then
		pay *= cfg.SpecialPayMultiplier
	end
	return math.floor(pay + 0.5)
end

function PaymentCalculator.Compute(basePay: number, idealTime: number, realTime: number, tipFactor: number, combo: number)
	local speedMultiplier = PaymentCalculator.GetSpeedMultiplier(realTime, idealTime)
	local comboBonus = PaymentCalculator.GetComboBonus(combo)
	local total = basePay * speedMultiplier * tipFactor * (1 + comboBonus)
	return {
		Total = math.max(1, math.floor(total + 0.5)),
		BasePay = basePay,
		SpeedMultiplier = speedMultiplier,
		Tip = tipFactor,
		ComboBonus = comboBonus,
		Combo = combo,
		RealTime = realTime,
		IdealTime = idealTime,
	}
end

-- Estimativa usada só na UI (sem gorjeta/combo)
function PaymentCalculator.Estimate(basePay: number, idealTime: number, elapsed: number): (number, number)
	local m = PaymentCalculator.GetSpeedMultiplier(elapsed, idealTime)
	return math.floor(basePay * m + 0.5), m
end

return PaymentCalculator
