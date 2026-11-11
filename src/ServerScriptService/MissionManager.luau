-- Missões do dia: as mesmas o dia todo para cada jogador, progresso contado só no servidor e estrelas ao concluir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MissionConfig = require(Modules.MissionConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MissionManager = {}

local function valid(list): boolean
	if type(list) ~= "table" or #list == 0 then
		return false
	end
	for _, m in ipairs(list) do
		if type(m) ~= "table" or not MissionConfig.Get(m.Id) or type(m.Progress) ~= "number" then
			return false
		end
	end
	return true
end

-- Garante as missões de hoje (quando o dia vira, sorteia as novas)
local function ensureToday(player: Player)
	local missions = PlayerDataManager.GetMissions(player)
	if not missions then
		return nil
	end
	local day = MissionConfig.Day()
	if missions.Day ~= day or not valid(missions.List) then
		missions.Day = day
		missions.List = {}
		for _, id in ipairs(MissionConfig.Pick(day, player.UserId)) do
			table.insert(missions.List, { Id = id, Progress = 0, Done = false })
		end
	end
	return missions
end

-- O cliente lê as missões no atributo "Missions" (JSON) e a hora da troca em "MissionsReset"
local function publish(player: Player)
	local missions = ensureToday(player)
	if not missions then
		return
	end
	local list = {}
	for _, m in ipairs(missions.List) do
		local cfg = MissionConfig.Get(m.Id)
		table.insert(list, {
			Id = m.Id, Text = string.format(cfg.Text, cfg.Goal), Progress = math.min(m.Progress, cfg.Goal),
			Goal = cfg.Goal, Stars = cfg.Stars, Done = m.Done == true,
		})
	end
	player:SetAttribute("Missions", HttpService:JSONEncode(list))
	player:SetAttribute("MissionsReset", MissionConfig.NextReset())
end

-- Soma amount no progresso das missões do tipo id; com best = true guarda só o maior valor (ex.: recorde do dia)
function MissionManager.Progress(player: Player, id: string, amount: number, best: boolean?)
	local missions = ensureToday(player)
	if not missions then
		return
	end
	local changed = false
	for _, m in ipairs(missions.List) do
		local cfg = MissionConfig.Get(m.Id)
		if m.Id == id and not m.Done then
			local value = math.min(cfg.Goal, best and math.max(m.Progress, amount) or m.Progress + amount)
			if value ~= m.Progress then
				m.Progress = value
				changed = true
				if value >= cfg.Goal then
					m.Done = true
					PlayerDataManager.AddStars(player, cfg.Stars)
					Remotes.SurvivalUpdate:FireClient(player, { Type = "Mission", Text = string.format(cfg.Text, cfg.Goal), Stars = cfg.Stars })
				end
			end
		end
	end
	if changed then
		publish(player)
	end
end

function MissionManager.Init()
	PlayerDataManager.PlayerLoaded:Connect(publish)
	-- só no Studio: ServerStorage.TesteMissoes:Fire(jogador, "entregas", 5) avança uma missão sem precisar jogar
	if RunService:IsStudio() then
		local hook = Instance.new("BindableEvent")
		hook.Name = "TesteMissoes"
		hook.Parent = ServerStorage
		hook.Event:Connect(MissionManager.Progress)
	end
	-- o dia virou com o jogador online: missões novas
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local missions = PlayerDataManager.GetMissions(player)
				if missions and missions.Day ~= MissionConfig.Day() then
					publish(player)
				end
			end
		end
	end)
end

return MissionManager
