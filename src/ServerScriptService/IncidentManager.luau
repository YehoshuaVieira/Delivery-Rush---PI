-- Taxas de incidentes avisados pelo cliente (batida, pneu, radar, atropelamento) e cobrança fora da rua.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local Format = require(Modules.Format)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)
local MotoManager = require(script.Parent.MotoManager)
local RoadMap = require(Modules.RoadMap)
local OFFROAD = GameConfig.OffRoad

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FEES = GameConfig.Fees

local IncidentManager = {}

local spikeCenters = {}
local radarCenters = {}

local function loadSpikes()
	local areas = Workspace:WaitForChild("Map"):WaitForChild("Areas")
	for _, area in ipairs(areas:GetChildren()) do
		local obstacles = area:FindFirstChild("Obstacles")
		local folder = obstacles and obstacles:FindFirstChild("Espinhos")
		for _, s in ipairs(folder and folder:GetChildren() or {}) do
			if s.Name == "SpikeStrip" then
				table.insert(spikeCenters, {
					Center = s:GetAttribute("Center"),
					Radius = (s:GetAttribute("HalfWidth") or 8) + 25,
				})
			end
		end
		local hazards = obstacles and obstacles:FindFirstChild("Perigos")
		for _, h in ipairs(hazards and hazards:GetChildren() or {}) do
			if h.Name == "Hazard" and h:GetAttribute("Type") == "radar" then
				table.insert(radarCenters, h:GetAttribute("Center"))
			end
		end
	end
end

local function nearSpike(pos: Vector3): boolean
	for _, s in ipairs(spikeCenters) do
		if AntiExploit.FlatDistance(pos, s.Center) <= s.Radius then
			return true
		end
	end
	return false
end

-- Taxas e multas só existem no Modo História (na Sobrevivência não há dinheiro)
local function chargesMoney(player: Player): boolean
	return player:GetAttribute("GameMode") == "Story"
end

local function charge(player: Player, amount: number, reason: string)
	local charged = PlayerDataManager.Charge(player, amount)
	if charged > 0 then
		Remotes.Notify:FireClient(player, string.format("%s: -%s", reason, Format.Money(charged)))
	end
end

function IncidentManager.Init()
	loadSpikes()

	Remotes.ReportIncident.OnServerEvent:Connect(function(player: Player, kind)
		if typeof(kind) ~= "string" or not PlayerDataManager.IsLoaded(player) or not chargesMoney(player) then
			return
		end
		if kind == "car" then
			if not AntiExploit.CheckRateLimit(player, "Incident_car", FEES.CarCrashCooldown) then
				return
			end
			charge(player, FEES.CarCrash, "Batida no carro")
		elseif kind == "spike" then
			if not AntiExploit.CheckRateLimit(player, "Incident_spike", GameConfig.Moto.FlatTireTime) then
				return
			end
			local pos = AntiExploit.GetRootPosition(player)
			if not pos or not nearSpike(pos) then
				return
			end
			charge(player, FEES.TireRepair, "Conserto do pneu")
		elseif kind == "radar" then
			if not AntiExploit.CheckRateLimit(player, "Incident_radar", FEES.RadarCooldown) then
				return
			end
			local pos = AntiExploit.GetRootPosition(player)
			local near = false
			for _, center in ipairs(radarCenters) do
				if pos and AntiExploit.FlatDistance(pos, center) <= 45 then
					near = true
					break
				end
			end
			if near then
				charge(player, FEES.Radar, "Multa do radar")
			end
		elseif kind == "pedestrian" then
			if not AntiExploit.CheckRateLimit(player, "Incident_ped", FEES.PedestrianCooldown) then
				return
			end
			local pos = AntiExploit.GetRootPosition(player)
			if not pos or not RoadMap.IsOffRoad(pos, -6) then
				return
			end
			charge(player, FEES.Pedestrian, "Atropelamento")
		end
	end)

	local offTime, onTime, warned, streak = {}, {}, {}, {}
	local intervalText = (tostring(OFFROAD.Interval):gsub("%.", ","))
	local function nextFee(player)
		return OFFROAD.Fee + (streak[player] or 0) * (OFFROAD.FeeIncrease or 0)
	end
	Players.PlayerRemoving:Connect(function(player)
		offTime[player], onTime[player], warned[player], streak[player] = nil, nil, nil, nil
	end)
	task.spawn(function()
		local STEP = 0.2
		while true do
			task.wait(STEP)
			for _, player in ipairs(Players:GetPlayers()) do
				local moto = MotoManager.GetMoto(player)
				local chassis = moto and moto.PrimaryPart
				if chassis and PlayerDataManager.IsLoaded(player) and chargesMoney(player) then
					local pos = chassis.Position
					if pos.Y < 6 and RoadMap.IsOffRoad(pos) then
						offTime[player] = (offTime[player] or 0) + STEP
						onTime[player] = 0
						while offTime[player] >= OFFROAD.Interval do
							offTime[player] -= OFFROAD.Interval
							local fee = nextFee(player)
							local charged = PlayerDataManager.Charge(player, fee)
							-- a taxa só sobe quando algo foi cobrado (sem saldo, continua na base)
							if charged > 0 then
								streak[player] = (streak[player] or 0) + 1
								player:SetAttribute("OffRoadNextFee", nextFee(player))
							end
							if charged > 0 and not warned[player] then
								warned[player] = true
								Remotes.Notify:FireClient(player, string.format("Fora da rua: -%s e a taxa sobe a cada %s s. Volte para o asfalto!", Format.Money(fee), intervalText))
							end
						end
					else
						onTime[player] = (onTime[player] or 0) + STEP
						if onTime[player] >= (OFFROAD.ResetAfter or 3) and (streak[player] or 0) > 0 then
							streak[player] = 0
							offTime[player] = 0
							player:SetAttribute("OffRoadNextFee", nextFee(player))
						end
						if onTime[player] > 5 then
							warned[player] = nil
						end
					end
				end
			end
		end
	end)
end

return IncidentManager
