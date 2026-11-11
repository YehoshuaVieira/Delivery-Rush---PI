-- Habilidades da Sobrevivência: a cada N entregas o jogador escolhe 1 entre 3 cartas (estilo Hades / Vampire Survivors).

local AbilityConfig = {}

AbilityConfig.EveryDeliveries = 5 -- uma escolha a cada 5 entregas
AbilityConfig.Choices = 3 -- cartas por escolha
AbilityConfig.PickTimeout = 30 -- s; depois disso a primeira carta é escolhida sozinha
AbilityConfig.PadPick = { "X", "Y", "B" } -- botões do controle para as cartas 1, 2 e 3

-- Peso = chance relativa de aparecer numa escolha
AbilityConfig.Rarity = {
	Comum = { Order = 1, Weight = 1.0, Color = Color3.fromRGB(190, 196, 204) },
	Raro = { Order = 2, Weight = 0.6, Color = Color3.fromRGB(77, 163, 255) },
	["Épico"] = { Order = 3, Weight = 0.35, Color = Color3.fromRGB(181, 124, 255) },
	["Lendário"] = { Order = 4, Weight = 0.18, Color = Color3.fromRGB(255, 176, 32) },
}

AbilityConfig.List = {
	{
		Id = "shield", Name = "Campo de Proteção", Rarity = "Raro", Icon = "escudo", Kind = "Passiva",
		Tagline = "Escudo contra obstáculos",
		Description = "Um escudo bloqueia o próximo impacto: carro, pedestre, bola, buraco, lama, óleo ou pregos. Recarrega 45 s depois de quebrar.",
		Cooldown = 45,
	},
	{
		Id = "nitro", Name = "Nitro de Emergência", Rarity = "Comum", Icon = "chama", Kind = "Automática",
		Tagline = "Aceleração especial",
		Description = "Quando o relógio chegar a 12 s, você ganha um turbo de 4 s automaticamente. Uma vez por pedido.",
		Duration = 4, TriggerAt = 12,
	},
	{
		Id = "magnet", Name = "Entregador Magnético", Rarity = "Comum", Icon = "ima", Kind = "Passiva",
		Tagline = "Alcance ampliado",
		Description = "Coleta e entrega com 75% a mais de alcance: o anel no chão fica maior e você não precisa frear em cima.",
		RadiusMultiplier = 1.75,
	},
	{
		Id = "ghost", Name = "Modo Fantasma", Rarity = "Raro", Icon = "fantasma", Kind = "Ativa", Key = "F", Pad = "LB",
		Tagline = "Passagem temporária",
		Description = "Aperte F: por 3 s você atravessa carros, pedestres e perigos do chão sem bater. Recarga de 35 s.",
		Duration = 3, Cooldown = 35,
	},
	{
		Id = "perfect", Name = "Entrega Perfeita", Rarity = "Raro", Icon = "estrela", Kind = "Passiva",
		Tagline = "Recompensa por sequência",
		Description = "A cada 3 entregas seguidas sem bater em nada, a 3ª entrega soma +8 s a mais no relógio.",
		Streak = 3, Bonus = 8,
	},
	{
		Id = "jump", Name = "Salto Extremo", Rarity = "Épico", Icon = "salto", Kind = "Ativa", Key = "Espaço", Pad = "Y",
		Tagline = "Salto especial",
		Description = "Aperte ESPAÇO para saltar por cima de carros, pregos, buracos e poças. Recarga de 18 s.",
		Cooldown = 18, Impulse = 46,
	},
	{
		Id = "second", Name = "Segunda Chance", Rarity = "Lendário", Icon = "relogio", Kind = "Automática",
		Tagline = "Imunidade ao fim do relógio",
		Description = "Uma vez por partida: quando o relógio zerar, você ganha +15 s em vez de perder a corrida.",
		Bonus = 15,
	},
	{
		Id = "tires", Name = "Pneus Reforçados", Rarity = "Comum", Icon = "pneu", Kind = "Passiva",
		Tagline = "À prova de pregos e buracos",
		Description = "Pregos não furam mais o seu pneu, e buracos não te freiam nem te jogam para cima.",
	},
	{
		Id = "grip", Name = "Tração Total", Rarity = "Comum", Icon = "tracao", Kind = "Passiva",
		Tagline = "Sem derrapar",
		Description = "Óleo e água não te fazem derrapar, e a lama tira só 15% da velocidade (em vez de 55%).",
		MudFactor = 0.85,
	},
	{
		Id = "bumper", Name = "Para-choque Reforçado", Rarity = "Comum", Icon = "parachoque", Kind = "Passiva",
		Tagline = "Batidas mais leves",
		Description = "Batidas tiram só 30% da velocidade: você não volta para trás nem fica tonto. Carros te empurram pela metade.",
		KeepSpeed = 0.7, PushFactor = 0.5,
	},
	{
		Id = "launch", Name = "Saída Rápida", Rarity = "Raro", Icon = "avanco", Kind = "Automática",
		Tagline = "Turbo no começo de cada trecho",
		Description = "Turbo automático de 2,5 s quando um pedido novo começa e quando você pega a comida no restaurante.",
		Duration = 2.5,
	},
	{
		Id = "overtime", Name = "Hora Extra", Rarity = "Épico", Icon = "ampulheta", Kind = "Passiva",
		Tagline = "Mais tempo em toda entrega",
		Description = "Toda entrega soma +3 s a mais no relógio.",
		Bonus = 3,
	},
	{
		Id = "siren", Name = "Sirene", Rarity = "Épico", Icon = "sirene", Kind = "Ativa", Key = "Q", Pad = "RB",
		Tagline = "Abram caminho!",
		Description = "Aperte Q: por 4 s os carros e pedestres a até 50 studs de você param e deixam você passar. Recarga de 25 s.",
		Duration = 4, Cooldown = 25, Radius = 50,
	},
	{
		Id = "slowmo", Name = "Câmera Lenta", Rarity = "Lendário", Icon = "caracol", Kind = "Ativa", Key = "E", Pad = "A",
		Tagline = "Tempo de reação",
		Description = "Aperte E: por 5 s o trânsito, os pedestres e as bolas de demolição andam a 30% da velocidade. Você continua normal. Recarga de 35 s.",
		Duration = 5, Cooldown = 35, Scale = 0.3,
	},
}

AbilityConfig.ById = {}
for _, a in ipairs(AbilityConfig.List) do
	AbilityConfig.ById[a.Id] = a
end

function AbilityConfig.Get(id: string)
	return AbilityConfig.ById[id]
end

-- Atributo "Abilities" do jogador ("shield,jump") -> { shield = true, jump = true }
function AbilityConfig.Parse(text: string?)
	local set = {}
	if type(text) == "string" then
		for id in string.gmatch(text, "[%w_]+") do
			set[id] = true
		end
	end
	return set
end

return AbilityConfig
