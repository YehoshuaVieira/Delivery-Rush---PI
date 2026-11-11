-- Parâmetros gerais do jogo. Upgrades e bairros ficam em UpgradeConfig e AreaConfig.

local GameConfig = {}

GameConfig.Orders = {
	MaxActiveOrders = 1,
	OfferDelay = 2, -- s até a próxima oferta
	DeclineCooldown = 3, -- s extras depois de recusar/cancelar

	BasePay = 60, -- $ base na Área 1, antes dos multiplicadores
	PayPerStud = 0.05, -- $ extra por stud de trajeto

	MinDeliveryDistance = 600,
	MaxDeliveryDistance = 1600,
	RestaurantCandidates = 3, -- sorteia N restaurantes e usa o mais perto do jogador
	NewerAreaWeight = 0.5, -- peso no sorteio = 1 + (id - 1) * isto

	ReferenceSpeed = 40, -- studs/s do nível 0 (fixo: moto melhor entrega mais rápido e ganha mais)
	RouteFactor = 1.35, -- as ruas não são linha reta
	ExtraTime = 6, -- s de tolerância no prazo

	PointRadius = 16, -- raio (studs) para coletar/entregar
	SameAreaChance = 0.8,
	SpecialChance = 0.1,
	SpecialPayMultiplier = 2,
	SpecialTimeMultiplier = 0.75,
}

-- Modo Sobrevivência: pedidos em sequência contra um relógio só; o relógio zerou = fim da partida.
GameConfig.Survival = {
	MotoLevel = 3, -- moto fixa do modo (nível 3 = 152 km/h)
	AreaId = 1, -- só o Centro
	-- relógio da partida: começa com StartTime e cada entrega soma um bônus que diminui até BonusMin
	StartTime = 60,
	BonusStart = 30, -- s somados na 1ª entrega...
	BonusStep = 1, -- ...1 s a menos a cada entrega...
	BonusMin = 15, -- ...até este mínimo (por volta da 16ª entrega)
	MaxTime = 120, -- teto do relógio
	-- tamanho dos pedidos pelo caminho das ruas (moto -> restaurante -> cliente): com bônus fixo, todo
	-- pedido precisa ter um tamanho parecido (cerca de 20 a 35 s de moto)
	RouteMin = 1100,
	RouteMax = 2000,
	RouteTries = 12,
	RouteFactor = 1.35, -- só se não achar rota: estimativa pela linha reta
	BreakTime = 1.5, -- s entre uma entrega e o próximo pedido

	-- dificuldade por entrega feita (aplicada no cliente, no WorldFX)
	TrafficPerLevel = 0.12, -- +12% de veículos por entrega...
	MaxTraffic = 3, -- ...até 3x (por volta da 17ª entrega)
	TrafficSpeedPerLevel = 0.025, -- trânsito mais rápido...
	MaxTrafficSpeed = 1.4, -- ...até 1,4x
	PedsPerLevel = 0.3, -- pedestres por quarteirão: 2 + isto × entregas...
	MaxPeds = 6, -- ...até este
	CrossersPerLevel = 0.6, -- pedestres atravessando a rua no caminho do pedido
	MaxCrossers = 14,
	HazardsPerLevel = 1.5, -- óleo/buraco/lama/pregos no caminho de cada trecho
	MaxHazards = 24,
	-- espaço mínimo (studs do trecho) por perigo/travessia: encolhe a cada entrega, então o caminho
	-- continua enchendo mesmo depois que o número sorteado passa do que cabe no trecho
	StartSpacing = 90,
	SpacingPerLevel = 3.5,
	MinSpacing = 30,

	-- eventos no caminho do pedido (sorteados no servidor a cada pedido)
	Events = {
		StartAt = 3, -- a partir da 4ª entrega...
		ChancePerDelivery = 0.05, -- ...a chance sobe 5% por entrega...
		MaxChance = 0.4, -- ...até 40% dos pedidos
		JamSeconds = 25, -- engarrafamento: carros parados nas ruas do caminho
		BlitzLimitKmh = 60, -- blitz: limite na barreira...
		BlitzPenalty = 3, -- ...passou acima = perde estes segundos do relógio
	},
}

GameConfig.Payment = {
	SpeedCurve = { -- tempo real / tempo ideal -> multiplicador (interpolado entre os pontos)
		{ Ratio = 0.5, Multiplier = 2.5 },
		{ Ratio = 1.0, Multiplier = 1.0 },
		{ Ratio = 2.0, Multiplier = 0.4 },
	},
	TipMin = 0.9,
	TipMax = 1.1,

	Combo = {
		MinSpeedMultiplier = 1.5,
		BonusPerCombo = 0.1,
		MaxBonus = 0.5,
	},
}

GameConfig.Moto = {
	TurnSpeed = 140, -- graus/s
	FullTurnSpeed = 15,
	MinTurnFactor = 0.35,
	BrakeDeceleration = 130,
	CoastDeceleration = 22,
	ReverseSpeedFactor = 0.35,
	LeanAngle = 12,
	BumpMinSpeed = 15,
	BumpBounce = 0.25,
	FlatTireTime = 3, -- s parado com o pneu furado
	FlatTireImmunity = 2,
	SpeedDisplayFactor = 2, -- studs/s -> km/h no HUD
}

GameConfig.Maneuver = {
	GrauMinSpeed = 15,
	GrauAngle = 24,
	GrauChargeTime = 1.2, -- s de grau para encher o turbo
	GrauMaxTime = 3,
	GrauTurnFactor = 0.5,
	MinChargeToBoost = 0.3,
	BoostMultiplier = 1.3, -- o anti-exploit tolera até +35%
	BoostDuration = 2,
	BoostAccelMultiplier = 2,
	JumpMinAirTime = 0.3,
	AirGravityScale = 0.4,
	JumpChargeBonus = 0.5,
	FailSpeedFactor = 0.5,
	Cooldown = 0.8,
}

GameConfig.Fees = {
	CarCrash = 10,
	CarCrashMinSpeed = 12,
	TireRepair = 20,
	CarCrashCooldown = 2.5,
	Radar = 15,
	RadarCooldown = 3,
	Pedestrian = 50,
	PedestrianCooldown = 1.5,
}

GameConfig.OffRoad = {
	SpeedFactor = 0.5,
	Fee = 3, -- 1ª cobrança; as seguintes sobem FeeIncrease (3, 4, 5...)
	FeeIncrease = 1,
	Interval = 1.6, -- s fora da rua por cobrança
	ResetAfter = 3, -- s seguidos no asfalto para a taxa voltar ao início
}

GameConfig.World = {
	Limit = 3450, -- além disso (X/Z) o reset manda para o spawn
	DayNight = { Enabled = true, DayMinutes = 10, NightMinutes = 3, StartHour = 9 },
	-- clima do servidor (todos veem o mesmo): ciclos de sol e, às vezes, chuva
	Weather = {
		Enabled = true,
		SunMinutes = { 4, 7 },
		RainChance = 0.45, -- ao fim de cada período de sol
		RainMinutes = { 2, 4 },
		RainTurn = 0.86, -- chuva: a moto vira 14% menos...
		RainBrake = 0.78, -- ...e freia 22% menos (Tração Total anula)
	},
}

GameConfig.Camera = {
	Distance = 23,
	Height = 9,
	LookAhead = 18,
	YawSmoothing = 8,
	BaseFOV = 70,
	MaxFOV = 100,
}

GameConfig.Data = {
	DataStoreName = "iFoodRoblox_PlayerData_v1", -- NÃO trocar: zera o progresso de todos
	AutosaveInterval = 120,
	MaxRetries = 4,
	StartingMoney = 0,

	DinheiroDeTeste = 50000, -- número = dinheiro de teste no Studio (nada é salvo). Deixe nil.
	EstrelasDeTeste = 20, -- idem para as estrelas da Garagem (só vale junto com o DinheiroDeTeste)
}

GameConfig.AntiExploit = {
	SampleInterval = 0.5,
	Window = 2.5, -- s de janela para medir a velocidade (tolera lag)
	MinWindow = 1.5,
	SpeedTolerance = 1.35,
	SpeedMargin = 10,
	MinTimeSpeedFactor = 1.45,
}

GameConfig.RateLimits = {
	Survival = 1,
	Shop = 0.4,
	OrderAction = 0.4,
	ResetMoto = 3,
	GetState = 0.5,
}

return GameConfig
