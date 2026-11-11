-- Pedidos 100% no servidor: oferece, detecta coleta/entrega pela posição e paga.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local AreaConfig = require(Modules.AreaConfig)
local PaymentCalculator = require(Modules.PaymentCalculator)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CFG = GameConfig.Orders
local UPDATE_INTERVAL = 0.1

local OrderManager = {}

local rng = Random.new()
local nextOrderId = 0

local points = {}
local states = {}

-- Lê os pontos (Pads) de cada área no Workspace: Map/Areas/<FolderName>/Restaurants|Customers/<Model>/Pad
local function loadPoints()
	local areasFolder = Workspace:WaitForChild("Map"):WaitForChild("Areas")
	for _, area in ipairs(AreaConfig.Areas) do
		local entry = { Restaurants = {}, Customers = {} }
		local folder = areasFolder:FindFirstChild(area.FolderName)
		if folder then
			local restaurants = folder:FindFirstChild("Restaurants")
			local customers = folder:FindFirstChild("Customers")
			for _, model in ipairs(restaurants and restaurants:GetChildren() or {}) do
				local padPart = model:FindFirstChild("Pad")
				if padPart then
					table.insert(entry.Restaurants, {
						Name = model:GetAttribute("DisplayName") or model.Name,
						Position = padPart.Position,
					})
				end
			end
			for _, model in ipairs(customers and customers:GetChildren() or {}) do
				local padPart = model:FindFirstChild("Pad")
				if padPart then
					table.insert(entry.Customers, {
						Name = model:GetAttribute("DisplayName") or model.Name,
						PlaceType = model:GetAttribute("PlaceType") or "Casa",
						Position = padPart.Position,
					})
				end
			end
		else
			warn("[OrderManager] Pasta da área não encontrada: " .. area.FolderName)
		end
		points[area.Id] = entry
	end
end

local function countActive(state): number
	local n = 0
	for _ in pairs(state.Active) do
		n += 1
	end
	return n
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Áreas desbloqueadas (dado do servidor) que têm restaurantes e clientes
local function availableAreas(player: Player): { number }
	local list = {}
	for _, id in ipairs(PlayerDataManager.GetUnlockedAreas(player)) do
		local p = points[id]
		if p and #p.Restaurants > 0 and #p.Customers > 0 then
			table.insert(list, id)
		end
	end
	return list
end

-- Tempo ideal e pagamento base a partir de uma posição de partida (só dados do servidor)
local function computeRoute(order, fromPos: Vector3)
	local toRestaurant = AntiExploit.FlatDistance(fromPos, order.RestaurantPosition)
	local toCustomer = AntiExploit.FlatDistance(order.RestaurantPosition, order.CustomerPosition)
	order.StraightDistance = toRestaurant + toCustomer
	order.IdealTime = PaymentCalculator.GetIdealTime(order.StraightDistance, order.IsSpecial)
	order.BasePay = PaymentCalculator.GetBasePay(order.AreaId, order.StraightDistance, order.IsSpecial)
end

-- Sorteio com peso: áreas mais caras (id maior) aparecem mais (a área recém-comprada "rende")
local function weightedArea(areas: { number }): number
	local total = 0
	for _, id in ipairs(areas) do
		total += 1 + (id - 1) * CFG.NewerAreaWeight
	end
	local r = rng:NextNumber() * total
	for _, id in ipairs(areas) do
		r -= 1 + (id - 1) * CFG.NewerAreaWeight
		if r <= 0 then
			return id
		end
	end
	return areas[#areas]
end

-- Sorteia um pedido nas áreas liberadas do jogador (ou só nas áreas em onlyAreas)
local function generateOrder(player: Player, onlyAreas: { number }?)
	local areas = availableAreas(player)
	if onlyAreas then
		areas = {}
		for _, id in ipairs(onlyAreas) do
			local p = points[id]
			if p and #p.Restaurants > 0 and #p.Customers > 0 then
				table.insert(areas, id)
			end
		end
	end
	if #areas == 0 then
		return nil
	end
	local playerPos = AntiExploit.GetRootPosition(player)
	local customerArea = weightedArea(areas)
	local restaurantArea = customerArea
	if rng:NextNumber() > CFG.SameAreaChance then
		restaurantArea = pick(areas)
	end

	local restaurantList = points[restaurantArea].Restaurants
	local restaurant = pick(restaurantList)
	if playerPos then
		local best = AntiExploit.FlatDistance(playerPos, restaurant.Position)
		for _ = 2, CFG.RestaurantCandidates do
			local candidate = pick(restaurantList)
			local d = AntiExploit.FlatDistance(playerPos, candidate.Position)
			if d < best then
				restaurant, best = candidate, d
			end
		end
	end

	local customerList = points[customerArea].Customers
	local valid = {}
	for _, c in ipairs(customerList) do
		local d = AntiExploit.FlatDistance(restaurant.Position, c.Position)
		if d >= CFG.MinDeliveryDistance and d <= CFG.MaxDeliveryDistance then
			table.insert(valid, c)
		end
	end
	local customer
	if #valid > 0 then
		customer = pick(valid)
	else
		local target = (CFG.MinDeliveryDistance + CFG.MaxDeliveryDistance) / 2
		local bestScore = math.huge
		for _, c in ipairs(customerList) do
			local score = math.abs(AntiExploit.FlatDistance(restaurant.Position, c.Position) - target)
			if score < bestScore then
				customer, bestScore = c, score
			end
		end
	end

	nextOrderId += 1
	local order = {
		Id = nextOrderId,
		Status = "Offered",
		RestaurantName = restaurant.Name,
		RestaurantPosition = restaurant.Position,
		RestaurantAreaId = restaurantArea,
		CustomerName = customer.Name,
		CustomerPlace = customer.PlaceType,
		CustomerPosition = customer.Position,
		AreaId = customerArea,
		IsSpecial = rng:NextNumber() < CFG.SpecialChance,
	}
	computeRoute(order, AntiExploit.GetRootPosition(player) or restaurant.Position)
	return order
end

-- Só o que a UI precisa. Nada disso volta para o servidor como "verdade".
local function toClient(order)
	local area = AreaConfig.Get(order.AreaId)
	local restaurantArea = AreaConfig.Get(order.RestaurantAreaId)
	return {
		Id = order.Id,
		Status = order.Status,
		RestaurantName = order.RestaurantName,
		RestaurantPosition = order.RestaurantPosition,
		RestaurantAreaName = restaurantArea and restaurantArea.Name or "?",
		CustomerName = order.CustomerName,
		CustomerPlace = order.CustomerPlace,
		CustomerPosition = order.CustomerPosition,
		AreaId = order.AreaId,
		AreaName = area and area.Name or "?",
		IsSpecial = order.IsSpecial,
		StraightDistance = order.StraightDistance,
		IdealTime = order.IdealTime,
		BasePay = order.BasePay,
		AcceptedServerTime = order.AcceptedServerTime,
		PointRadius = CFG.PointRadius,
	}
end

local function offerOrder(player: Player, state)
	local order = generateOrder(player)
	if not order then
		state.NextOfferAt = os.clock() + CFG.OfferDelay
		return
	end
	state.Offer = order
	Remotes.OrderOffered:FireClient(player, toClient(order))
end

local function acceptOrder(player: Player, orderId: number)
	local state = states[player]
	if not state then
		return
	end
	local offer = state.Offer
	if not offer or offer.Id ~= orderId then
		return
	end
	if countActive(state) >= CFG.MaxActiveOrders then
		return
	end
	local pos = AntiExploit.GetRootPosition(player)
	if not pos then
		return
	end

	computeRoute(offer, pos)
	offer.Status = "ToRestaurant"
	offer.AcceptedAt = os.clock()
	offer.AcceptedServerTime = Workspace:GetServerTimeNow()
	state.Offer = nil
	state.Active[offer.Id] = offer
	Remotes.OrderAccepted:FireClient(player, toClient(offer))
end

local function declineOffer(player: Player)
	local state = states[player]
	if not state or not state.Offer then
		return
	end
	state.Offer = nil
	state.NextOfferAt = os.clock() + CFG.DeclineCooldown
end

local function cancelOrder(player: Player, orderId: number, reason: string)
	local state = states[player]
	local order = state and state.Active[orderId]
	if not order then
		return
	end
	state.Active[orderId] = nil
	state.Combo = 0
	state.NextOfferAt = os.clock() + CFG.DeclineCooldown
	Remotes.OrderCancelled:FireClient(player, orderId, reason)
end

local function pickUp(player: Player, order)
	order.Status = "ToCustomer"
	order.PickedUpAt = os.clock()
	Remotes.OrderPickedUp:FireClient(player, toClient(order))
end

-- Paga a entrega: tempo medido só com o relógio do servidor e validado pelo AntiExploit antes de pagar.
local function deliver(player: Player, state, order)
	local now = os.clock()
	local realTime = now - order.AcceptedAt
	state.Active[order.Id] = nil
	state.NextOfferAt = now + CFG.OfferDelay

	local ok, reason = AntiExploit.ValidateDelivery(player, order, realTime)
	if not ok then
		state.Combo = 0
		warn(string.format("[OrderManager] Entrega de %s rejeitada: %s", player.Name, tostring(reason)))
		Remotes.OrderCancelled:FireClient(player, order.Id, "Entrega invalidada: " .. tostring(reason))
		return
	end

	local speedMultiplier = PaymentCalculator.GetSpeedMultiplier(realTime, order.IdealTime)
	if speedMultiplier >= GameConfig.Payment.Combo.MinSpeedMultiplier then
		state.Combo += 1
	else
		state.Combo = 0
	end

	local tip = rng:NextNumber(GameConfig.Payment.TipMin, GameConfig.Payment.TipMax)
	local result = PaymentCalculator.Compute(order.BasePay, order.IdealTime, realTime, tip, state.Combo)

	PlayerDataManager.AddMoney(player, result.Total)
	PlayerDataManager.AddDelivery(player)

	result.OrderId = order.Id
	result.IsSpecial = order.IsSpecial
	result.CustomerName = order.CustomerName
	Remotes.OrderDelivered:FireClient(player, result)
end

local function update()
	local now = os.clock()
	for player, state in pairs(states) do
		-- só o Modo História usa este fluxo de ofertas (a Sobrevivência tem o SurvivalManager)
		if player.Parent and player:GetAttribute("GameMode") == "Story" then
			if not state.Offer and countActive(state) < CFG.MaxActiveOrders and now >= state.NextOfferAt then
				offerOrder(player, state)
			end

			local pos = AntiExploit.GetRootPosition(player)
			if pos then
				for _, order in pairs(state.Active) do
					if order.Status == "ToRestaurant" then
						if AntiExploit.FlatDistance(pos, order.RestaurantPosition) <= CFG.PointRadius then
							pickUp(player, order)
						end
					elseif order.Status == "ToCustomer" then
						if AntiExploit.FlatDistance(pos, order.CustomerPosition) <= CFG.PointRadius then
							deliver(player, state, order)
						end
					end
				end
			end
		end
	end
end

OrderManager.GenerateOrder = generateOrder
OrderManager.ToClient = toClient

function OrderManager.Init()
	loadPoints()

	PlayerDataManager.PlayerLoaded:Connect(function(player: Player)
		states[player] = {
			Offer = nil,
			Active = {},
			Combo = 0,
			NextOfferAt = os.clock() + CFG.OfferDelay + 1,
		}
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Remotes.RequestAcceptOrder.OnServerEvent:Connect(function(player, orderId)
		if typeof(orderId) ~= "number" then
			return
		end
		if not AntiExploit.CheckRateLimit(player, "OrderAction", GameConfig.RateLimits.OrderAction) then
			return
		end
		acceptOrder(player, orderId)
	end)

	Remotes.RequestDeclineOrder.OnServerEvent:Connect(function(player)
		if not AntiExploit.CheckRateLimit(player, "OrderAction", GameConfig.RateLimits.OrderAction) then
			return
		end
		declineOffer(player)
	end)

	Remotes.RequestCancelOrder.OnServerEvent:Connect(function(player, orderId)
		if typeof(orderId) ~= "number" then
			return
		end
		if not AntiExploit.CheckRateLimit(player, "OrderAction", GameConfig.RateLimits.OrderAction) then
			return
		end
		cancelOrder(player, orderId, "Você cancelou o pedido.")
	end)

	-- O HUD pede o estado atual ao iniciar (ex.: se abriu depois da oferta ter sido enviada)
	Remotes.GetOrderState.OnServerInvoke = function(player)
		if not AntiExploit.CheckRateLimit(player, "GetState", GameConfig.RateLimits.GetState) then
			return nil
		end
		local state = states[player]
		if not state then
			return nil
		end
		local active = {}
		for _, order in pairs(state.Active) do
			table.insert(active, toClient(order))
		end
		return {
			Offer = state.Offer and toClient(state.Offer) or nil,
			Active = active,
			Combo = state.Combo,
		}
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= UPDATE_INTERVAL then
			accumulator = 0
			update()
		end
	end)
end

return OrderManager
