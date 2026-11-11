-- Eventos para o Analytics do Creator Dashboard (partidas, primeira sessão, habilidades). Uma falha aqui nunca derruba o jogo.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local PATH = "Sobrevivencia"
local FIELD_KEYS = { Enum.AnalyticsCustomFieldKeys.CustomField01.Name, Enum.AnalyticsCustomFieldKeys.CustomField02.Name, Enum.AnalyticsCustomFieldKeys.CustomField03.Name }

-- Funil da primeira sessão: cada passo só conta uma vez e em ordem (só para quem nunca entregou nada)
local ONBOARDING = { "Entrou no jogo", "Começou a partida", "Primeira coleta", "Primeira entrega", "Primeira habilidade" }
local onboardingStep = {} -- [player] = último passo registrado (nil = jogador antigo)

local function fields(values)
	if not values then
		return nil
	end
	local t = {}
	for i, v in ipairs(values) do
		if FIELD_KEYS[i] then
			t[FIELD_KEYS[i]] = tostring(v)
		end
	end
	return t
end

local function send(method: string, ...)
	if RunService:IsStudio() then
		return -- no Studio os eventos não vão para o painel; evita avisos no Output
	end
	local ok, err = pcall(AnalyticsService[method], AnalyticsService, ...)
	if not ok then
		warn("[Analytics] " .. method .. ": " .. tostring(err))
	end
end

function Analytics.StartOnboarding(player: Player, isNew: boolean)
	onboardingStep[player] = isNew and 0 or nil
	Analytics.Onboarding(player, "Entrou no jogo")
end

function Analytics.Onboarding(player: Player, stepName: string)
	local last = onboardingStep[player]
	local step = table.find(ONBOARDING, stepName)
	if last == nil or step ~= last + 1 then
		return
	end
	onboardingStep[player] = step
	send("LogOnboardingFunnelStepEvent", player, step, stepName)
end

function Analytics.RunStarted(player: Player)
	send("LogCustomEvent", player, "PartidaIniciada", 1)
	Analytics.Onboarding(player, "Começou a partida")
end

-- Cada entrega vira um "nível" completo da progressão: o painel mostra até onde os jogadores chegam
function Analytics.Delivered(player: Player, deliveries: number)
	send("LogProgressionCompleteEvent", player, PATH, deliveries, "Entrega " .. deliveries)
	if deliveries == 1 then
		Analytics.Onboarding(player, "Primeira entrega")
	end
end

function Analytics.RunEnded(player: Player, deliveries: number, reason: string, abilityCount: number, newRecord: boolean)
	send("LogProgressionFailEvent", player, PATH, deliveries + 1, "Entrega " .. (deliveries + 1), fields({ reason }))
	send("LogCustomEvent", player, "PartidaEncerrada", deliveries, fields({ reason, abilityCount, newRecord and "recorde" or "-" }))
end

function Analytics.AbilityPicked(player: Player, id: string, rarity: string, auto: boolean)
	send("LogCustomEvent", player, "HabilidadeEscolhida", 1, fields({ id, rarity, auto and "tempo esgotado" or "escolha" }))
	Analytics.Onboarding(player, "Primeira habilidade")
end

function Analytics.Forget(player: Player)
	onboardingStep[player] = nil
end

return Analytics
