-- Sons locais: motor, ambiente e um som próprio para cada evento (volumes normalizados na biblioteca Sounds).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local MotoSignals = require(Modules:WaitForChild("MotoSignals"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local library = ReplicatedStorage:WaitForChild("Sounds")
local motosFolder = Workspace:WaitForChild("Motos")

local TOP_SPEED = UpgradeConfig.Get(UpgradeConfig.MaxLevel).Speed

-- Grupos: o compressor nos efeitos segura os picos (nada "estoura" quando vários sons batem juntos)
local function group(name: string, volume: number, compress: boolean)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	if compress and not g:FindFirstChildOfClass("CompressorSoundEffect") then
		local c = Instance.new("CompressorSoundEffect")
		c.Threshold = -18
		c.Ratio = 3.5
		c.Attack = 0.008
		c.Release = 0.18
		c.GainMakeup = 2
		c.Parent = g
	end
	g.Parent = SoundService
	return g
end
local SFX = group("Efeitos", 0.9, true)
local UI_GROUP = group("Interface", 0.8, false)
local ENGINE_GROUP = group("Motor", 0.75, false)
local AMBIENT_GROUP = group("Ambiente", 0.7, false)

local function gainOf(source: Sound): number
	return source:GetAttribute("Gain") or source.Volume
end

-- Toca uma cópia do som da biblioteca (podem tocar vários ao mesmo tempo).
-- opts: Volume (0..1 sobre o ganho normalizado), Pitch, Delay, Group
local function play(name: string, opts)
	opts = opts or {}
	local source = library:FindFirstChild(name)
	if not source then
		return
	end
	local function go()
		local s = source:Clone()
		local start = source:GetAttribute("Start") or 0
		local stop = source:GetAttribute("Stop")
		s.Volume = gainOf(source) * (opts.Volume or 1)
		s.PlaybackSpeed = (opts.Pitch or 1) * (1 + (math.random() - 0.5) * 0.06)
		s.SoundGroup = opts.Group or SFX
		s.Looped = false
		s.TimePosition = start
		s.Parent = SoundService
		s:Play()
		local length = ((stop or (source.TimeLength > 0 and source.TimeLength or 3)) - start) / s.PlaybackSpeed
		if stop then
			-- recorte: some suave no fim do trecho
			task.delay(math.max(0, length - 0.08), function()
				if s.Parent then
					TweenService:Create(s, TweenInfo.new(0.08), { Volume = 0 }):Play()
				end
			end)
		end
		task.delay(length + 0.2, function()
			s:Destroy()
		end)
	end
	if opts.Delay and opts.Delay > 0 then
		task.delay(opts.Delay, go)
	else
		go()
	end
end

local function loop(name: string, parent: Instance, g: SoundGroup)
	local source = library:FindFirstChild(name)
	if not source then
		return nil
	end
	local s = source:Clone()
	s.Looped = true
	s.SoundGroup = g
	s.Parent = parent
	return s
end

local ambience = loop("CityAmbience", SoundService, AMBIENT_GROUP)
if ambience then
	ambience.Volume = 0.16
	ambience:Play()
end

------------------------------------------------------------------ impactos da moto
local function speedNow(): number
	return player:GetAttribute("DisplaySpeed") or 0
end

MotoSignals.Impact.Event:Connect(function(kind: string, intensity: number)
	local k = 0.45 + 0.55 * intensity
	if kind == "car" then
		play("HitCar", { Volume = k })
	elseif kind == "ped" then
		play("BodyThump", { Volume = k })
		play("Oof", { Volume = 0.9, Delay = 0.05 })
	elseif kind == "ball" then
		play("HitHeavy", { Volume = 0.9 })
	elseif kind == "cone" then
		play("Cone", { Volume = 0.5 + 0.5 * intensity, Pitch = 1.05 })
	elseif kind == "pothole" then
		play("Thud", { Volume = k, Pitch = 0.72 })
	elseif kind == "bump" then
		-- roda da frente e roda de trás passando pela lombada: o intervalo depende da velocidade
		local gap = math.clamp(4.5 / math.max(speedNow(), 1), 0.06, 0.22)
		play("Thud", { Volume = intensity, Pitch = 0.8 })
		play("Thud", { Volume = intensity * 0.8, Pitch = 0.74, Delay = gap })
	elseif kind == "mud" then
		play("Mud", { Volume = k })
	elseif kind == "water" then
		play("Water", { Volume = k })
	elseif kind == "oil" then
		play("Skid", { Volume = k })
	elseif kind == "spike" then
		play("TirePop", { Volume = 1 })
		play("Thud", { Volume = 0.5, Pitch = 0.6, Delay = 0.05 })
	elseif kind == "shield" then
		play("Shield", { Volume = 1, Pitch = 1.15 })
	elseif kind == "ghost" then
		play("Ghost", { Volume = 1 })
	elseif kind == "jump" then
		play("Jump", { Volume = 1, Pitch = 0.9 })
		play("Turbo", { Volume = 0.45, Pitch = 1.25 })
	elseif kind == "siren" then
		play("Siren", { Volume = 1 })
	elseif kind == "slowmo" then
		play("SlowMo", { Volume = 1, Pitch = 0.85 })
	end
end)

-- turbo (do grau ou do Nitro de Emergência)
local wasBoosting = false
player:GetAttributeChangedSignal("Boosting"):Connect(function()
	local boosting = player:GetAttribute("Boosting") == true
	if boosting and not wasBoosting then
		play("Turbo", { Volume = 0.9 })
	end
	wasBoosting = boosting
end)

------------------------------------------------------------------ pedido e partida
-- prazo do pedido atual (Sobrevivência), para o tique-taque dos últimos segundos
local deadline = nil
local lastTick = nil
local function trackOrder(order)
	if order and order.Survival and order.DeadlineServerTime then
		deadline = order.DeadlineServerTime
		lastTick = nil
	end
end

Remotes.OrderAccepted.OnClientEvent:Connect(trackOrder)
Remotes.OrderPickedUp.OnClientEvent:Connect(function(order)
	trackOrder(order)
	play("Pickup", { Group = UI_GROUP })
end)
Remotes.OrderDelivered.OnClientEvent:Connect(function(result)
	deadline = nil
	play("Cash", { Group = UI_GROUP })
	if result and result.PerfectBonus then
		play("AbilityPick", { Group = UI_GROUP, Pitch = 1.2, Delay = 0.35 })
	end
end)
Remotes.SurvivalUpdate.OnClientEvent:Connect(function(data)
	if data and data.DeadlineServerTime then
		deadline = data.DeadlineServerTime
		lastTick = nil
		play("Shield", { Group = UI_GROUP, Pitch = 0.9 })
	end
end)
Remotes.SurvivalEnded.OnClientEvent:Connect(function(result)
	deadline = nil
	if result and result.Reason == "tempo" then
		play("TimeUp", { Group = UI_GROUP })
	end
	if result and result.NewRecord then
		play("Record", { Group = UI_GROUP, Delay = result.Reason == "tempo" and 1.2 or 0.2 })
	end
end)
Remotes.AbilityOffer.OnClientEvent:Connect(function()
	play("AbilityOffer", { Group = UI_GROUP })
end)
local abilityCount = 0
player:GetAttributeChangedSignal("Abilities"):Connect(function()
	local text = player:GetAttribute("Abilities")
	local count = 0
	for _ in string.gmatch(text or "", "[%w_]+") do
		count += 1
	end
	if count > abilityCount then
		play("AbilityPick", { Group = UI_GROUP })
	end
	abilityCount = count
end)

------------------------------------------------------------------ motor e tique-taque
local engine = nil
local engineMoto = nil
RunService.Heartbeat:Connect(function(dt)
	local moto = motosFolder:FindFirstChild("Moto_" .. player.UserId)
	if moto ~= engineMoto then
		engineMoto = moto
		if engine then
			engine:Destroy()
			engine = nil
		end
		if moto and moto.PrimaryPart then
			engine = loop("EngineIdle", moto.PrimaryPart, ENGINE_GROUP)
			if engine then
				engine.RollOffMaxDistance = 150
				engine:Play()
			end
		end
	end
	if engine then
		local ratio = math.clamp(speedNow() / TOP_SPEED, 0, 1.4)
		local target = 0.8 + ratio * 1.3 + (player:GetAttribute("Boosting") and 0.25 or 0)
		engine.PlaybackSpeed += (target - engine.PlaybackSpeed) * math.clamp(dt * 6, 0, 1)
		engine.Volume = 0.26 + ratio * 0.2
	end

	-- últimos 5 s do prazo: um tique por segundo, cada vez mais agudo
	if deadline and player:GetAttribute("GameMode") == "Survival" then
		local left = deadline - Workspace:GetServerTimeNow()
		if left > 0 and left <= 5 then
			local second = math.ceil(left)
			if second ~= lastTick then
				lastTick = second
				play("Tick", { Group = UI_GROUP, Pitch = 1 + (5 - second) * 0.08, Volume = 0.8 + (5 - second) * 0.05 })
			end
		end
	end
end)
