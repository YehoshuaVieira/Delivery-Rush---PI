-- Cria a moto de cada jogador e mantém o piloto sempre sentado nela (a física da moto é do cliente).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local CosmeticConfig = require(Modules.CosmeticConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MotoManager = {}

local MOTO_GROUP = "Motos"
local RIDER_GROUP = "Riders"
local WORLD_LIMIT = GameConfig.World.Limit

local motos = {}
local overrides = {} -- [player] = nível fixo do modo de jogo (ex.: Sobrevivência)

-- Nível da moto em uso: o fixo do modo, se houver; senão o comprado (salvo)
local function levelOf(player: Player): number
	return overrides[player] or PlayerDataManager.GetMotoLevel(player)
end

local function setupCollisionGroups()
	for _, name in ipairs({ MOTO_GROUP, RIDER_GROUP }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(MOTO_GROUP, MOTO_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(MOTO_GROUP, RIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, RIDER_GROUP, false)
end

local function setGroup(root: Instance, group: string)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

local function getSpawnCFrame(): CFrame
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("MotoSpawns")
	if folder then
		local list = folder:GetChildren()
		if #list > 0 then
			return list[math.random(1, #list)].CFrame
		end
	end
	return CFrame.new(0, 3, 0)
end

local function setOwner(entry, player: Player)
	local chassis = entry.Model.PrimaryPart
	if chassis and chassis:IsDescendantOf(Workspace) then
		pcall(function()
			chassis:SetNetworkOwner(player)
		end)
	end
end

local function seat(entry, humanoid: Humanoid)
	local seatPart = entry.Model:FindFirstChild("Seat")
	if seatPart and humanoid.Health > 0 and seatPart.Occupant == nil then
		seatPart:Sit(humanoid)
	end
end

-- Moto em uso: a escolhida na Garagem (atributo Equip_Moto, posto pelo CosmeticManager) ou a padrão.
-- Sem essas, a do nível: MotoSkins.NivelN (nível 0 = MotoTemplate), ou o maior nível abaixo.
local function templateFor(player: Player, level: number): Model?
	local skins = ServerStorage:FindFirstChild("MotoSkins")
	local chosen = skins and (skins:FindFirstChild(CosmeticConfig.SkinOf(player:GetAttribute("Equip_Moto"))) or skins:FindFirstChild(CosmeticConfig.DefaultSkin))
	if chosen then
		return chosen
	end
	for l = level, 1, -1 do
		local t = skins and skins:FindFirstChild("Nivel" .. l)
		if t then
			return t
		end
	end
	return ServerStorage:FindFirstChild("MotoTemplate")
end

-- Aplica velocidade/aceleração do nível atual (chamado no spawn e após comprar upgrade)
function MotoManager.ApplyStats(player: Player)
	local entry = motos[player]
	if not entry then
		return
	end
	local cfg = UpgradeConfig.Get(levelOf(player))
	entry.Model:SetAttribute("MaxSpeed", cfg.Speed)
	entry.Model:SetAttribute("Acceleration", cfg.Acceleration)
end

function MotoManager.SetLevelOverride(player: Player, level: number?)
	overrides[player] = level
	player:SetAttribute("EffectiveMotoLevel", levelOf(player))
end

function MotoManager.GetMoto(player: Player): Model?
	local entry = motos[player]
	return entry and entry.Model
end

function MotoManager.Despawn(player: Player)
	local entry = motos[player]
	if not entry then
		return
	end
	motos[player] = nil
	for _, connection in ipairs(entry.Connections) do
		connection:Disconnect()
	end
	entry.Model:Destroy()
end

function MotoManager.Spawn(player: Player, cframe: CFrame?)
	MotoManager.Despawn(player)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	local template = templateFor(player, levelOf(player))
	player:SetAttribute("EffectiveMotoLevel", levelOf(player))
	if not template then
		warn("[MotoManager] ServerStorage.MotoTemplate não encontrado!")
		return nil
	end

	local spawnCF = cframe or getSpawnCFrame()
	local moto = template:Clone()
	moto.Name = "Moto_" .. player.UserId
	moto:SetAttribute("OwnerUserId", player.UserId)
	moto:SetAttribute("ResetId", 0)
	moto:SetAttribute("SkinName", template.Name)
	moto:PivotTo(spawnCF)
	moto.PrimaryPart.AlignOrientation.CFrame = spawnCF.Rotation
	setGroup(moto, MOTO_GROUP)
	moto.Parent = Workspace:WaitForChild("Motos")

	local entry = { Model = moto, Connections = {} }
	motos[player] = entry
	MotoManager.ApplyStats(player)

	setGroup(character, RIDER_GROUP)
	table.insert(entry.Connections, character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = RIDER_GROUP
		end
	end))
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	root.CFrame = spawnCF + Vector3.new(0, 3, 0)
	seat(entry, humanoid)
	AntiExploit.ResetTracking(player)
	setOwner(entry, player)
	task.delay(0.25, function()
		if motos[player] == entry then
			setOwner(entry, player)
		end
	end)

	table.insert(entry.Connections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if humanoid.SeatPart ~= nil or humanoid.Health <= 0 then
			return
		end
		task.delay(0.15, function()
			if motos[player] == entry and humanoid.Parent and humanoid.SeatPart == nil and humanoid.Health > 0 then
				seat(entry, humanoid)
				setOwner(entry, player)
			end
		end)
	end))

	table.insert(entry.Connections, humanoid.Died:Connect(function()
		MotoManager.Despawn(player)
	end))

	return moto
end

-- Troca a moto pelo modelo do nível atual (após um upgrade), no mesmo lugar e direção
function MotoManager.RefreshSkin(player: Player)
	local entry = motos[player]
	if not entry then
		return
	end
	local want = templateFor(player, levelOf(player))
	if not want or entry.Model:GetAttribute("SkinName") == want.Name then
		return
	end
	local chassis = entry.Model.PrimaryPart
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local p = Vector3.new(chassis.Position.X, 3, chassis.Position.Z)
	MotoManager.Spawn(player, CFrame.lookAt(p, p + flat.Unit))
end

-- "Desenroscar": coloca a moto em pé no mesmo lugar (ou no spawn se saiu do mapa)
function MotoManager.Reset(player: Player)
	local entry = motos[player]
	if not entry then
		return
	end
	local chassis = entry.Model.PrimaryPart
	local pos = chassis.Position
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end

	local target: CFrame
	if pos.Y < -20 or math.abs(pos.X) > WORLD_LIMIT or math.abs(pos.Z) > WORLD_LIMIT then
		target = getSpawnCFrame()
	else
		local p = Vector3.new(pos.X, 3, pos.Z)
		target = CFrame.lookAt(p, p + flat.Unit)
	end

	chassis.AssemblyLinearVelocity = Vector3.zero
	entry.Model:PivotTo(target)
	chassis.AlignOrientation.CFrame = target.Rotation
	entry.Model:SetAttribute("ResetId", (entry.Model:GetAttribute("ResetId") or 0) + 1)
	AntiExploit.ResetTracking(player)
end

local function onCharacter(player: Player, character: Model)
	AntiExploit.ResetTracking(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	local t0 = os.clock()
	while not character:IsDescendantOf(Workspace) and os.clock() - t0 < 10 do
		task.wait(0.05)
	end
	task.wait(0.3)
	if player.Character ~= character or not player.Parent then
		return
	end
	AntiExploit.ResetTracking(player) -- renascer no spawn não conta como teleporte
	-- no menu não há moto: ela só nasce quando o jogador está numa partida
	if player:GetAttribute("GameMode") == "Survival" or player:GetAttribute("GameMode") == "Story" then
		MotoManager.Spawn(player)
	end
end

function MotoManager.Init()
	setupCollisionGroups()

	PlayerDataManager.PlayerLoaded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			MotoManager.Despawn(player)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MotoManager.Despawn(player)
		overrides[player] = nil
	end)

	Remotes.RequestResetMoto.OnServerEvent:Connect(function(player)
		if not AntiExploit.CheckRateLimit(player, "ResetMoto", GameConfig.RateLimits.ResetMoto) then
			Remotes.Notify:FireClient(player, "Aguarde alguns segundos para resetar de novo.")
			return
		end
		MotoManager.Reset(player)
	end)
end

return MotoManager
