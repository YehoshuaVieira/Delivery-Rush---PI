-- Missões do dia da Sobrevivência e quantas estrelas cada uma vale. Ajuste metas, textos e estrelas aqui.

local MissionConfig = {}

MissionConfig.PerDay = 3
MissionConfig.ResetHourUTC = 3 -- 3h UTC = meia-noite em Brasília
MissionConfig.SpareSeconds = 30 -- missão "folga": entregou com pelo menos isto no relógio

-- Text usa %d para a meta. Luck = depende de sorte (chuva, blitz): no máximo uma por dia.
MissionConfig.List = {
	{ Id = "entregas", Text = "Faça %d entregas", Goal = 15, Stars = 1 },
	{ Id = "partida", Text = "Faça %d entregas numa só partida", Goal = 8, Stars = 2 },
	{ Id = "limpas", Text = "Faça %d entregas seguidas sem bater", Goal = 5, Stars = 2 },
	{ Id = "folga", Text = "Entregue %d vezes com 30 s ou mais no relógio", Goal = 6, Stars = 1 },
	{ Id = "partidas", Text = "Jogue %d partidas", Goal = 3, Stars = 1 },
	{ Id = "habilidades", Text = "Escolha %d habilidades", Goal = 4, Stars = 1 },
	{ Id = "chuva", Text = "Faça %d entregas na chuva", Goal = 3, Stars = 2, Luck = true },
	{ Id = "blitz", Text = "Passe por %d blitz sem multa", Goal = 1, Stars = 2, Luck = true },
}

local byId = {}
for _, m in ipairs(MissionConfig.List) do
	byId[m.Id] = m
end

function MissionConfig.Get(id: string)
	return byId[id]
end

-- Dia das missões (vira à meia-noite de Brasília)
function MissionConfig.Day(now: number?): number
	return math.floor(((now or os.time()) - MissionConfig.ResetHourUTC * 3600) / 86400)
end

function MissionConfig.NextReset(now: number?): number
	return (MissionConfig.Day(now) + 1) * 86400 + MissionConfig.ResetHourUTC * 3600
end

-- As mesmas missões o dia todo para o mesmo jogador (sorteio pela data + id)
function MissionConfig.Pick(day: number, userId: number): { string }
	local rng = Random.new(day * 100003 + math.abs(userId) % 100003)
	local pool = table.clone(MissionConfig.List)
	local picked, luck = {}, false
	while #picked < MissionConfig.PerDay and #pool > 0 do
		local m = table.remove(pool, rng:NextInteger(1, #pool))
		if not (m.Luck and luck) then
			luck = luck or m.Luck == true
			table.insert(picked, m.Id)
		end
	end
	return picked
end

return MissionConfig
