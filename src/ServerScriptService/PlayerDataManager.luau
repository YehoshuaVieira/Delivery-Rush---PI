-- Carrega e salva os dados do jogador no DataStore (trava de sessão, retry, autosave e BindToClose).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local AreaConfig = require(Modules.AreaConfig)

local PlayerDataManager = {}

local DATA_VERSION = 1
local KEY_PREFIX = "Player_"

local SESSION_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false))
local LOCK_TIMEOUT = 300
local LOCK_RETRIES = 5
local LOCK_WAIT = 4

local sessions = {}

local loadedEvent = Instance.new("BindableEvent")
PlayerDataManager.PlayerLoaded = loadedEvent.Event

local store = nil
local dataStoreEnabled = true

local function disableDataStore(reason: string)
	if dataStoreEnabled then
		dataStoreEnabled = false
		warn("[PlayerDataManager] DataStore indisponível -> jogando SEM salvar. Motivo: " .. reason
			.. "\n  -> No Studio: publique o place e ative Game Settings > Security > 'Enable Studio Access to API Services'.")
	end
end

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.DataStoreName)
	end)
	if ok then
		store = result
	else
		disableDataStore(tostring(result))
	end
end

local function defaultData()
	return {
		Version = DATA_VERSION,
		Money = GameConfig.Data.StartingMoney,
		MotoLevel = 0,
		UnlockedAreas = { 1 },
		TotalDeliveries = 0,
		TotalEarned = 0,
		SurvivalBest = 0,
		Stars = 0, -- moeda das missões do dia (MissionManager), gasta na Garagem (CosmeticManager)
		Missions = { Day = -1, List = {} },
		Cosmetics = { Owned = {}, Equipped = {} },
	}
end

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

-- Corrige dados antigos/corrompidos: preenche campos faltando e limita valores.
local function reconcile(data)
	local default = defaultData()
	if type(data) ~= "table" then
		return default
	end
	for key, value in pairs(default) do
		if typeof(data[key]) ~= typeof(value) then
			data[key] = value
		end
	end
	data.Money = math.max(0, math.floor(data.Money))
	data.MotoLevel = math.clamp(math.floor(data.MotoLevel), 0, UpgradeConfig.MaxLevel)
	data.TotalDeliveries = math.max(0, math.floor(data.TotalDeliveries))
	data.SurvivalBest = math.max(0, math.floor(data.SurvivalBest))
	data.Stars = math.max(0, math.floor(data.Stars))
	if type(data.Cosmetics.Owned) ~= "table" or type(data.Cosmetics.Equipped) ~= "table" then
		data.Cosmetics = default.Cosmetics
	end

	local set = { [1] = true }
	for _, id in ipairs(data.UnlockedAreas) do
		if type(id) == "number" and AreaConfig.Get(id) then
			set[id] = true
		end
	end
	local list = {}
	for id in pairs(set) do
		table.insert(list, id)
	end
	table.sort(list)
	data.UnlockedAreas = list
	data.Version = DATA_VERSION
	return data
end

-- Erros que indicam que o DataStore simplesmente não está disponível neste ambiente (Studio)
local function isEnvironmentError(err): boolean
	local msg = string.lower(tostring(err))
	return msg:find("studioaccesstoapisnotallowed") ~= nil
		or msg:find("studio access to apis is not allowed") ~= nil
		or msg:find("must publish") ~= nil
		or msg:find("403") ~= nil
end

-- Executa fn com retry + backoff exponencial (1s, 2s, 4s...)
local function withRetry(label: string, maxAttempts: number, fn)
	local lastErr
	for attempt = 1, maxAttempts do
		if not dataStoreEnabled then
			return false, "DataStore desabilitado"
		end
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if isEnvironmentError(result) then
			disableDataStore(tostring(result))
			return false, result
		end
		warn(string.format("[PlayerDataManager] %s falhou (tentativa %d/%d): %s", label, attempt, maxAttempts, tostring(result)))
		if attempt < maxAttempts then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastErr
end

-- Atualiza o que o cliente enxerga (Attributes + leaderstats)
local function replicate(player: Player, data)
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("MotoLevel", data.MotoLevel)
	player:SetAttribute("TotalDeliveries", data.TotalDeliveries)
	player:SetAttribute("UnlockedAreas", table.concat(data.UnlockedAreas, ","))
	player:SetAttribute("SurvivalBest", data.SurvivalBest)
	player:SetAttribute("Stars", data.Stars)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Dinheiro.Value = data.Money
		leaderstats.Entregas.Value = data.TotalDeliveries
	end
end

-- release = true: é o último save desta sessão (saída/fechamento) => libera a trava
local function savePlayer(player: Player, maxAttempts: number?, release: boolean?): boolean
	local session = sessions[player]
	if not session or not session.CanSave or not dataStoreEnabled or not store then
		return false
	end
	local snapshot = deepCopy(session.Data)

	local lostLock = false
	local ok = withRetry("Save " .. player.UserId, maxAttempts or GameConfig.Data.MaxRetries, function()
		store:UpdateAsync(KEY_PREFIX .. player.UserId, function(current)
			local lock = type(current) == "table" and current.SessionLock
			if type(lock) == "table" and lock.Id ~= SESSION_ID then
				lostLock = true
				return nil
			end
			snapshot.SessionLock = (not release) and { Id = SESSION_ID, Time = os.time() } or nil
			return snapshot
		end)
	end)
	if lostLock then
		session.CanSave = false
		warn("[PlayerDataManager] " .. player.Name .. " está em outro servidor; este servidor não salva mais os dados dele.")
		return false
	end
	return ok
end

-- Carrega os dados JÁ pegando a trava de sessão (UpdateAsync = leitura + escrita atômica)
local function loadWithLock(player: Player)
	local key = KEY_PREFIX .. player.UserId
	for attempt = 1, LOCK_RETRIES do
		local lockedByOther = false
		local ok, result = withRetry("Load " .. player.UserId, GameConfig.Data.MaxRetries, function()
			return store:UpdateAsync(key, function(current)
				local lock = type(current) == "table" and current.SessionLock
				local fresh = type(lock) == "table" and lock.Id ~= SESSION_ID and os.time() - (tonumber(lock.Time) or 0) < LOCK_TIMEOUT
				if fresh and attempt < LOCK_RETRIES then
					lockedByOther = true
					return nil
				end
				current = type(current) == "table" and current or defaultData()
				current.SessionLock = { Id = SESSION_ID, Time = os.time() }
				return current
			end)
		end)
		if not ok then
			return false, nil
		end
		if not lockedByOther then
			return true, result
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(LOCK_WAIT)
	end
	return false, nil
end

-- Libera a trava sem salvar (usado no modo teste, que não salva nada)
local function releaseLock(player: Player)
	pcall(function()
		store:UpdateAsync(KEY_PREFIX .. player.UserId, function(current)
			local lock = type(current) == "table" and current.SessionLock
			if type(lock) == "table" and lock.Id == SESSION_ID then
				current.SessionLock = nil
				return current
			end
			return nil
		end)
	end)
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Dinheiro"
	money.Parent = leaderstats
	local deliveries = Instance.new("IntValue")
	deliveries.Name = "Entregas"
	deliveries.Parent = leaderstats
	leaderstats.Parent = player

	local data, canSave = nil, false
	if dataStoreEnabled and store then
		local ok, result = loadWithLock(player)
		if ok then
			data = reconcile(result)
			data.SessionLock = nil
			canSave = true
		else
			data = defaultData()
			if dataStoreEnabled then
				warn("[PlayerDataManager] Não foi possível carregar os dados de " .. player.Name .. ". Jogando com dados temporários (não serão salvos).")
			end
		end
	else
		data = defaultData()
	end

	if not player.Parent then
		-- saiu durante a carga: devolve a trava para ele poder entrar de novo na hora
		if canSave then
			task.spawn(releaseLock, player)
		end
		return
	end

	local testMoney = GameConfig.Data.DinheiroDeTeste
	if RunService:IsStudio() and type(testMoney) == "number" then
		data.Money = math.max(0, math.floor(testMoney))
		if type(GameConfig.Data.EstrelasDeTeste) == "number" then
			data.Stars = math.max(0, math.floor(GameConfig.Data.EstrelasDeTeste))
		end
		if canSave then
			task.spawn(releaseLock, player)
		end
		canSave = false
		warn(string.format("[PlayerDataManager] MODO TESTE: %s começou com $%d (nada será salvo nesta sessão).", player.Name, data.Money))
	end

	sessions[player] = { Data = data, CanSave = canSave }
	replicate(player, data)
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("DataSaving", canSave)
	loadedEvent:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	savePlayer(player, nil, true)
	sessions[player] = nil
end

function PlayerDataManager.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- Os dados deste jogador estão sendo salvos? (falso no modo teste, sem DataStore ou sem a trava)
function PlayerDataManager.IsSaving(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.CanSave == true
end

-- Somente leitura por convenção (use as funções abaixo para alterar)
function PlayerDataManager.GetData(player: Player)
	local session = sessions[player]
	return session and session.Data
end

function PlayerDataManager.AddMoney(player: Player, amount: number)
	local session = sessions[player]
	if not session or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end
	amount = math.floor(amount)
	session.Data.Money += amount
	session.Data.TotalEarned += amount
	replicate(player, session.Data)
end

-- Debita se tiver saldo. Sem yield entre checar e debitar => sem race condition.
function PlayerDataManager.TrySpend(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or type(amount) ~= "number" or amount < 0 or amount ~= amount then
		return false
	end
	if session.Data.Money < amount then
		return false
	end
	session.Data.Money -= amount
	replicate(player, session.Data)
	return true
end

-- Cobra uma taxa: tira até 'amount' (nunca deixa negativo). Retorna quanto foi cobrado.
function PlayerDataManager.Charge(player: Player, amount: number): number
	local session = sessions[player]
	if not session or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return 0
	end
	local charged = math.min(math.floor(amount), session.Data.Money)
	if charged <= 0 then
		return 0
	end
	session.Data.Money -= charged
	replicate(player, session.Data)
	return charged
end

function PlayerDataManager.SetMotoLevel(player: Player, level: number)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.MotoLevel = math.clamp(level, 0, UpgradeConfig.MaxLevel)
	replicate(player, session.Data)
end

function PlayerDataManager.GetMotoLevel(player: Player): number
	local session = sessions[player]
	return session and session.Data.MotoLevel or 0
end

function PlayerDataManager.IsAreaUnlocked(player: Player, areaId: number): boolean
	local session = sessions[player]
	if not session then
		return areaId == 1
	end
	return table.find(session.Data.UnlockedAreas, areaId) ~= nil
end

function PlayerDataManager.GetUnlockedAreas(player: Player): { number }
	local session = sessions[player]
	return session and table.clone(session.Data.UnlockedAreas) or { 1 }
end

function PlayerDataManager.UnlockArea(player: Player, areaId: number)
	local session = sessions[player]
	if not session or table.find(session.Data.UnlockedAreas, areaId) then
		return
	end
	table.insert(session.Data.UnlockedAreas, areaId)
	table.sort(session.Data.UnlockedAreas)
	replicate(player, session.Data)
end

-- Guarda o recorde da Sobrevivência se for maior. Retorna (é recorde novo, recorde atual).
function PlayerDataManager.SetSurvivalBest(player: Player, deliveries: number): (boolean, number)
	local session = sessions[player]
	if not session or type(deliveries) ~= "number" then
		return false, 0
	end
	if deliveries > session.Data.SurvivalBest then
		session.Data.SurvivalBest = math.floor(deliveries)
		replicate(player, session.Data)
		return true, session.Data.SurvivalBest
	end
	return false, session.Data.SurvivalBest
end

function PlayerDataManager.AddStars(player: Player, amount: number)
	local session = sessions[player]
	if not session or type(amount) ~= "number" or amount <= 0 then
		return
	end
	session.Data.Stars += math.floor(amount)
	replicate(player, session.Data)
end

function PlayerDataManager.TrySpendStars(player: Player, amount: number): boolean
	local session = sessions[player]
	if not session or type(amount) ~= "number" or amount < 0 or session.Data.Stars < amount then
		return false
	end
	session.Data.Stars -= amount
	replicate(player, session.Data)
	return true
end

-- Tabelas vivas: só o MissionManager mexe nas missões e só o CosmeticManager na garagem
function PlayerDataManager.GetMissions(player: Player)
	local session = sessions[player]
	return session and session.Data.Missions
end

function PlayerDataManager.GetCosmetics(player: Player)
	local session = sessions[player]
	return session and session.Data.Cosmetics
end

function PlayerDataManager.AddDelivery(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.TotalDeliveries += 1
	replicate(player, session.Data)
end

function PlayerDataManager.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player in pairs(sessions) do
				task.spawn(savePlayer, player)
			end
		end
	end)

	game:BindToClose(function()
		if not dataStoreEnabled then
			return
		end
		local pending = 0
		for player in pairs(sessions) do
			pending += 1
			task.spawn(function()
				savePlayer(player, 2, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataManager
