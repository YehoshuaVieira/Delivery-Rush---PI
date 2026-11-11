-- Modo Sobrevivência: pedidos em sequência contra um relógio só (cada entrega soma segundos), no Centro e com a moto fixa. Relógio zerou = fim da partida.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local AbilityConfig = require(Modules.AbilityConfig)
local RoadGraph = require(Modules.RoadGraph)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)
local MotoManager = require(script.Parent.MotoManager)
local OrderManager = require(script.Parent.OrderManager)
local Analytics = require(script.Parent.Analytics)
local MissionManager = require(script.Parent.MissionManager)
local MissionConfig = require(Modules.MissionConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CFG = GameConfig.Survival
local EVENTS = CFG.Events
local RADIUS = GameConfig.Orders.PointRadius
local UPDATE_INTERVAL = 0.1

local SurvivalManager = {}

local runs = {} -- [player] = { Deliveries, StartBest, Clock, Order, NextOrderAt, Abilities, Offer, ... }
local lastFirstOffer = {} -- [player] = 1ª oferta da partida anterior (a próxima partida começa com outra)
local rng = Random.new()

-- Caminho de verdade pelas ruas: moto -> restaurante -> cliente (o mesmo cálculo da trilha no chão)
local function roadDistance(player: Player, order): number
	local graph = RoadGraph.Get(Workspace.Map.Areas, { [CFG.AreaId] = true })
	local start = AntiExploit.GetRootPosition(player)
	local toRestaurant = start and RoadGraph.Length(graph, start, order.RestaurantPosition)
	local toCustomer = RoadGraph.Length(graph, order.RestaurantPosition, order.CustomerPosition)
	if toRestaurant and toCustomer then
		return toRestaurant + toCustomer
	end
	return order.StraightDistance * CFG.RouteFactor -- sem rota (não deveria acontecer): estimativa antiga
end

-- Segundos que a enésima entrega soma ao relógio: começa em BonusStart e cai até BonusMin (+ Hora Extra)
local function bonusFor(run, n: number): number
	local bonus = math.max(CFG.BonusMin, CFG.BonusStart - (n - 1) * CFG.BonusStep)
	if run.Abilities.overtime then
		bonus += AbilityConfig.Get("overtime").Bonus
	end
	return bonus
end

local function setStats(player: Player, deliveries: number)
	player:SetAttribute("SurvivalDeliveries", deliveries)
	player:SetAttribute("SurvivalLevel", deliveries)
end

local function radiusOf(run): number
	return run.Abilities.magnet and RADIUS * AbilityConfig.Get("magnet").RadiusMultiplier or RADIUS
end

-- O cliente usa estes atributos para o Nitro de Emergência e para o HUD
local function publishDeadline(player: Player, order)
	player:SetAttribute("OrderDeadline", order and order.AcceptedServerTime + order.TimeAllowed or nil)
	player:SetAttribute("OrderTimeAllowed", order and order.TimeAllowed or nil)
end

local function toClient(run, order)
	local data = OrderManager.ToClient(order)
	data.Survival = true
	data.TimeAllowed = order.TimeAllowed
	data.DeadlineServerTime = order.AcceptedServerTime + order.TimeAllowed
	data.PointRadius = radiusOf(run)
	data.NextBonus = bonusFor(run, run.Deliveries + 1)
	data.Event = order.Event and { Kind = order.Event.Kind, Pos = order.Event.Pos, Dir = order.Event.Dir, Until = order.Event.Until }
	return data
end

-- Blitz: no meio do trecho restaurante -> cliente, numa reta longa (longe dos cruzamentos)
local function blitzSpot(order)
	local graph = RoadGraph.Get(Workspace.Map.Areas, { [CFG.AreaId] = true })
	local points = RoadGraph.Route(graph, order.RestaurantPosition, order.CustomerPosition)
	if not points then
		return nil
	end
	local total, startAt = 0, {}
	for i = 2, #points do
		startAt[i] = total
		total += (points[i] - points[i - 1]).Magnitude
	end
	local best, bestScore = nil, math.huge
	for i = 2, #points do
		local len = (points[i] - points[i - 1]).Magnitude
		local score = math.abs(startAt[i] + len / 2 - total / 2)
		if len >= 80 and score < bestScore then
			best, bestScore = i, score
		end
	end
	if not best then
		return nil
	end
	local a, b = points[best - 1], points[best]
	return (a + b) / 2, (b - a).Unit
end

-- Evento do pedido: a partir da 4ª entrega, cada vez mais provável. Engarrafamento no caminho até o
-- restaurante (os carros param no cliente) ou blitz no caminho até o cliente (conferida aqui no servidor).
local function rollEvent(run, order)
	local chance = math.min(EVENTS.MaxChance, (run.Deliveries - EVENTS.StartAt + 1) * EVENTS.ChancePerDelivery)
	if chance <= 0 or rng:NextNumber() >= chance then
		return nil
	end
	if rng:NextNumber() < 0.5 then
		local pos, dir = blitzSpot(order)
		if pos then
			return { Kind = "blitz", Pos = pos, Dir = dir }
		end
	end
	return { Kind = "jam", Until = Workspace:GetServerTimeNow() + EVENTS.JamSeconds }
end

-- A moto cruzou a linha da blitz (a viatura fica no meio da rua)? Acima do limite = perde segundos do relógio.
-- Velocidade e posição vistas pelo servidor; vale uma vez por pedido.
local function checkBlitz(player: Player, run, order, pos: Vector3)
	local last = run.LastPos
	run.LastPos = pos
	local ev = order.Event
	if not ev or ev.Kind ~= "blitz" or ev.Done or order.Status ~= "ToCustomer" or not last then
		return
	end
	if ((last - ev.Pos):Dot(ev.Dir) < 0) == ((pos - ev.Pos):Dot(ev.Dir) < 0) then
		return
	end
	if math.abs((pos - ev.Pos):Dot(ev.Dir:Cross(Vector3.yAxis))) > 24 then
		return -- cruzou a mesma reta em outra rua
	end
	ev.Done = true
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	local kmh = math.floor(Vector3.new(v.X, 0, v.Z).Magnitude * GameConfig.Moto.SpeedDisplayFactor + 0.5)
	local fined = kmh > EVENTS.BlitzLimitKmh + 3
	if fined then
		order.TimeAllowed -= EVENTS.BlitzPenalty
		order.Deadline -= EVENTS.BlitzPenalty
		publishDeadline(player, order)
	end
	Remotes.SurvivalUpdate:FireClient(player, {
		Type = "Blitz", OrderId = order.Id, Fined = fined, Kmh = kmh, Limit = EVENTS.BlitzLimitKmh, Penalty = EVENTS.BlitzPenalty,
		TimeAllowed = order.TimeAllowed, DeadlineServerTime = order.AcceptedServerTime + order.TimeAllowed,
	})
	if not fined then
		MissionManager.Progress(player, "blitz", 1)
	end
end

local function publishAbilities(player: Player, run)
	local ids = {}
	for _, a in ipairs(AbilityConfig.List) do
		if run and run.Abilities[a.Id] then
			table.insert(ids, a.Id)
		end
	end
	player:SetAttribute("Abilities", #ids > 0 and table.concat(ids, ",") or nil)
	player:SetAttribute("PerfectStreak", run and run.Abilities.perfect and run.CleanStreak or nil)
	player:SetAttribute("SecondChanceUsed", run and run.SecondUsed or nil)
end

-- Sorteia pedidos até achar um com o caminho dentro da faixa (RouteMin..RouteMax); senão fica com o mais perto dela
local function pickOrder(player: Player)
	local best, bestOff
	for _ = 1, CFG.RouteTries do
		local order = OrderManager.GenerateOrder(player, { CFG.AreaId })
		if not order then
			return nil
		end
		order.RoadDistance = roadDistance(player, order)
		local off = math.max(0, CFG.RouteMin - order.RoadDistance, order.RoadDistance - CFG.RouteMax)
		if not best or off < bestOff then
			best, bestOff = order, off
		end
		if off == 0 then
			break
		end
	end
	return best
end

-- O pedido usa o que sobrou no relógio (ele fica parado entre um pedido e outro)
local function nextOrder(player: Player, run)
	run.NextOrderAt = nil
	local order = AntiExploit.GetRootPosition(player) and pickOrder(player)
	if not order then
		run.NextOrderAt = os.clock() + 1
		return
	end
	order.IsSpecial = false
	order.TimeAllowed = run.Clock
	order.Event = rollEvent(run, order)
	order.Status = "ToRestaurant"
	order.AcceptedAt = os.clock()
	order.AcceptedServerTime = Workspace:GetServerTimeNow()
	order.Deadline = order.AcceptedAt + order.TimeAllowed
	run.Order = order
	run.HitThisOrder = false
	publishDeadline(player, order)
	Remotes.OrderAccepted:FireClient(player, toClient(run, order))
end

local function logRunEnded(player: Player, run, reason: string)
	local abilityCount = 0
	for _ in pairs(run.Abilities) do
		abilityCount += 1
	end
	Analytics.RunEnded(player, run.Deliveries, reason, abilityCount, run.Deliveries > run.StartBest)
end

local function endRun(player: Player, reason: string)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	logRunEnded(player, run, reason)
	-- o resultado vai antes da troca de modo, para o menu já abrir na tela de resultado
	if player.Parent then
		Remotes.SurvivalEnded:FireClient(player, {
			Deliveries = run.Deliveries,
			Best = math.max(run.StartBest, run.Deliveries),
			NewRecord = run.Deliveries > run.StartBest,
			Reason = reason,
		})
	end
	MotoManager.Despawn(player)
	MotoManager.SetLevelOverride(player, nil)
	player:SetAttribute("GameMode", "Menu")
	setStats(player, 0)
	publishDeadline(player, nil)
	publishAbilities(player, nil)
	if player.Parent then
		task.spawn(player.LoadCharacter, player) -- volta ao spawn, onde fica o palco do menu
	end
end

local function startRun(player: Player)
	if runs[player] or not PlayerDataManager.IsLoaded(player) then
		return
	end
	local data = PlayerDataManager.GetData(player)
	local run = {
		Deliveries = 0, StartBest = data and data.SurvivalBest or 0,
		Clock = CFG.StartTime, Abilities = {}, OfferedSets = {}, OfferCount = 0,
		CleanStreak = 0, SecondUsed = false, HitThisOrder = false,
	}
	runs[player] = run
	player:SetAttribute("GameMode", "Survival")
	setStats(player, 0)
	publishAbilities(player, run)
	MotoManager.SetLevelOverride(player, CFG.MotoLevel)
	MotoManager.Spawn(player) -- se o personagem não existir agora, a moto nasce no próximo respawn
	run.NextOrderAt = os.clock() + CFG.BreakTime
	Analytics.RunStarted(player)
	MissionManager.Progress(player, "partidas", 1)
end

------------------------------------------------------------------ habilidades
local function setKey(ids: { string }): string
	local t = table.clone(ids)
	table.sort(t)
	return table.concat(t, ",")
end

-- Sorteia as cartas (raridade pesa) sem repetir um conjunto já oferecido nesta partida
-- nem a 1ª oferta da partida anterior.
local function rollOffer(player: Player, run)
	local pool = {}
	for _, a in ipairs(AbilityConfig.List) do
		if not run.Abilities[a.Id] then
			table.insert(pool, a)
		end
	end
	if #pool == 0 then
		return nil
	end
	local n = math.min(AbilityConfig.Choices, #pool)
	local picked
	for attempt = 1, 16 do
		local candidates = table.clone(pool)
		picked = {}
		for _ = 1, n do
			local total = 0
			for _, a in ipairs(candidates) do
				total += AbilityConfig.Rarity[a.Rarity].Weight
			end
			local r = rng:NextNumber() * total
			local index = #candidates
			for i, a in ipairs(candidates) do
				r -= AbilityConfig.Rarity[a.Rarity].Weight
				if r <= 0 then
					index = i
					break
				end
			end
			table.insert(picked, candidates[index].Id)
			table.remove(candidates, index)
		end
		local key = setKey(picked)
		local repeated = run.OfferedSets[key] or (run.OfferCount == 0 and lastFirstOffer[player] == key)
		if not repeated then
			break
		end
	end
	local key = setKey(picked)
	run.OfferedSets[key] = true
	if run.OfferCount == 0 then
		lastFirstOffer[player] = key
	end
	run.OfferCount += 1
	return picked
end

local function grantAbility(player: Player, run, id: string, auto: boolean?)
	run.Offer = nil
	local ability = AbilityConfig.Get(id)
	if ability then
		run.Abilities[id] = true
		Analytics.AbilityPicked(player, id, ability.Rarity, auto == true)
		MissionManager.Progress(player, "habilidades", 1)
	end
	publishAbilities(player, run)
	run.NextOrderAt = os.clock() + CFG.BreakTime
end

------------------------------------------------------------------ entregas
-- Entrega: tempo medido só com o relógio do servidor e validado pelo AntiExploit.
-- O que sobrou + o bônus da entrega vira o relógio do próximo pedido.
local function deliver(player: Player, run, order)
	local realTime = os.clock() - order.AcceptedAt
	run.Order = nil
	publishDeadline(player, nil)
	local ok, reason = AntiExploit.ValidateDelivery(player, order, realTime)
	if not ok then
		warn(string.format("[Survival] Entrega de %s rejeitada: %s", player.Name, tostring(reason)))
		endRun(player, "invalida")
		return
	end
	run.Deliveries += 1
	setStats(player, run.Deliveries)
	PlayerDataManager.AddDelivery(player)
	PlayerDataManager.SetSurvivalBest(player, run.Deliveries) -- o recorde já fica salvo a cada entrega
	Analytics.Delivered(player, run.Deliveries)

	-- missões do dia
	local timeLeft = math.max(0, order.Deadline - os.clock())
	run.MissionStreak = run.HitThisOrder and 0 or (run.MissionStreak or 0) + 1
	MissionManager.Progress(player, "entregas", 1)
	MissionManager.Progress(player, "partida", run.Deliveries, true)
	MissionManager.Progress(player, "limpas", run.MissionStreak, true)
	if timeLeft >= MissionConfig.SpareSeconds then
		MissionManager.Progress(player, "folga", 1)
	end
	if Workspace:GetAttribute("Clima") == "Chuva" then
		MissionManager.Progress(player, "chuva", 1)
	end

	-- Entrega Perfeita: N entregas seguidas sem bater = segundos extras no relógio
	local perfectBonus = nil
	if run.Abilities.perfect then
		local cfg = AbilityConfig.Get("perfect")
		run.CleanStreak = run.HitThisOrder and 0 or run.CleanStreak + 1
		if run.CleanStreak >= cfg.Streak then
			run.CleanStreak = 0
			perfectBonus = cfg.Bonus
		end
		publishAbilities(player, run)
	end
	local bonus = bonusFor(run, run.Deliveries) + (perfectBonus or 0)
	run.Clock = math.min(CFG.MaxTime, timeLeft + bonus)

	Remotes.OrderDelivered:FireClient(player, {
		OrderId = order.Id,
		Survival = true,
		Deliveries = run.Deliveries,
		RecordBroken = run.StartBest > 0 and run.Deliveries == run.StartBest + 1,
		TimeLeft = timeLeft,
		TimeBonus = bonus,
		Clock = run.Clock,
		RealTime = realTime,
		CustomerName = order.CustomerName,
		PerfectBonus = perfectBonus,
	})

	-- a cada N entregas: escolha de habilidade antes do próximo pedido
	if run.Deliveries % AbilityConfig.EveryDeliveries == 0 then
		local ids = rollOffer(player, run)
		if ids then
			run.Offer = { Ids = ids, ExpiresAt = os.clock() + AbilityConfig.PickTimeout + CFG.BreakTime }
			task.delay(CFG.BreakTime, function()
				if runs[player] == run and run.Offer then
					Remotes.AbilityOffer:FireClient(player, { Ids = ids, Milestone = run.Deliveries, Timeout = AbilityConfig.PickTimeout })
				end
			end)
			return
		end
	end
	run.NextOrderAt = os.clock() + CFG.BreakTime
end

local function update()
	local now = os.clock()
	for player, run in pairs(runs) do
		if not player.Parent then
			runs[player] = nil
			continue
		end
		local order = run.Order
		if order then
			if now > order.Deadline then
				-- Segunda Chance: uma vez por partida o relógio ganha mais alguns segundos
				if run.Abilities.second and not run.SecondUsed then
					run.SecondUsed = true
					local bonus = AbilityConfig.Get("second").Bonus
					order.TimeAllowed += bonus
					order.Deadline += bonus
					publishDeadline(player, order)
					publishAbilities(player, run)
					Remotes.SurvivalUpdate:FireClient(player, {
						Type = "SecondChance", OrderId = order.Id, Bonus = bonus,
						TimeAllowed = order.TimeAllowed, DeadlineServerTime = order.AcceptedServerTime + order.TimeAllowed,
					})
				else
					endRun(player, "tempo")
					continue
				end
			end
			local pos = AntiExploit.GetRootPosition(player)
			if pos then
				checkBlitz(player, run, order, pos)
				local radius = radiusOf(run)
				if order.Status == "ToRestaurant" and AntiExploit.FlatDistance(pos, order.RestaurantPosition) <= radius then
					order.Status = "ToCustomer"
					Remotes.OrderPickedUp:FireClient(player, toClient(run, order))
					Analytics.Onboarding(player, "Primeira coleta")
				elseif order.Status == "ToCustomer" and AntiExploit.FlatDistance(pos, order.CustomerPosition) <= radius then
					deliver(player, run, order)
				end
			end
		elseif run.Offer then
			if now >= run.Offer.ExpiresAt then
				grantAbility(player, run, run.Offer.Ids[1], true) -- tempo esgotado: fica com a primeira carta
			end
		elseif run.NextOrderAt and now >= run.NextOrderAt then
			nextOrder(player, run)
		end
	end
end

function SurvivalManager.IsRunning(player: Player): boolean
	return runs[player] ~= nil
end

function SurvivalManager.Init()
	PlayerDataManager.PlayerLoaded:Connect(function(player: Player)
		player:SetAttribute("GameMode", "Menu")
		setStats(player, 0)
		local data = PlayerDataManager.GetData(player)
		Analytics.StartOnboarding(player, data ~= nil and (data.TotalDeliveries or 0) == 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if runs[player] then
			logRunEnded(player, runs[player], "saiu do jogo")
		end
		runs[player] = nil
		lastFirstOffer[player] = nil
		Analytics.Forget(player)
	end)

	Remotes.RequestStartSurvival.OnServerEvent:Connect(function(player)
		if not AntiExploit.CheckRateLimit(player, "Survival", GameConfig.RateLimits.Survival) then
			return
		end
		startRun(player)
	end)
	Remotes.RequestQuitSurvival.OnServerEvent:Connect(function(player)
		if not AntiExploit.CheckRateLimit(player, "SurvivalQuit", GameConfig.RateLimits.Survival) then
			return
		end
		endRun(player, "desistiu")
	end)
	Remotes.RequestPickAbility.OnServerEvent:Connect(function(player, id)
		local run = runs[player]
		if typeof(id) ~= "string" or not run or not run.Offer or not table.find(run.Offer.Ids, id) then
			return
		end
		grantAbility(player, run, id)
	end)
	-- Batidas avisadas pelo cliente: só zeram a sequência da Entrega Perfeita (não mexem em dinheiro)
	Remotes.ReportIncident.OnServerEvent:Connect(function(player, kind)
		local run = runs[player]
		if run and typeof(kind) == "string" and AntiExploit.CheckRateLimit(player, "SurvivalHit", 0.2) then
			run.HitThisOrder = true
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= UPDATE_INTERVAL then
			accumulator = 0
			update()
		end
	end)
end

return SurvivalManager
