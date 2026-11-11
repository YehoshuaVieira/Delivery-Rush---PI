-- Chuva no cliente: riscos na tela, gotas na frente da câmera, céu carregado e som. Quem decide o clima é o servidor (Workspace.Clima).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")

local RAIN_TEX = "rbxassetid://122472984511594" -- risco vertical (gota)
local SCREEN_TEX = "rbxassetid://80979806840954" -- ladrilho de riscos para a tela
local FADE = 4 -- segundos para a chuva entrar ou sair

-- aparelho fraco: menos gotas
local function rainRate(): number
	local ok, q = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local low = (ok and q ~= Enum.SavedQualitySetting.Automatic and q.Value <= 4)
		or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	return low and 450 or 1100
end

local box = Instance.new("Part")
box.Name = "Chuva"
box.Anchored = true
box.CanCollide = false
box.CanQuery = false
box.CanTouch = false
box.CastShadow = false
box.Transparency = 1
box.Size = Vector3.new(80, 1, 80)
box.Parent = Workspace

local drops = Instance.new("ParticleEmitter")
drops.Texture = RAIN_TEX
drops.Rate = 0
drops.Lifetime = NumberRange.new(0.4, 0.5)
drops.Speed = NumberRange.new(120, 140)
drops.EmissionDirection = Enum.NormalId.Bottom
drops.Shape = Enum.ParticleEmitterShape.Box
drops.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
drops.Orientation = Enum.ParticleOrientation.FacingCamera -- VelocityParallel deixa a gota de lado (some)
drops.Size = NumberSequence.new(0.5)
drops.Squash = NumberSequence.new(2.2) -- estica na vertical: vira risco de chuva
drops.Transparency = NumberSequence.new(0.3)
drops.Color = ColorSequence.new(Color3.fromRGB(205, 218, 232))
drops.LightEmission = 0.3
drops.LightInfluence = 0.6
drops.Acceleration = Vector3.new(6, 0, 3) -- um pouco de vento
drops.Parent = box

-- céu e cor: guardamos o que havia para voltar igual quando a chuva para
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
local base = {
	Density = atmosphere and atmosphere.Density or 0.3,
	Haze = atmosphere and atmosphere.Haze or 0,
	Color = atmosphere and atmosphere.Color or Color3.new(1, 1, 1),
	Rays = sunRays and sunRays.Intensity or 0,
}
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "Chuva"
grade.Enabled = false
grade.Parent = Lighting
local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
if not clouds then
	clouds = Instance.new("Clouds")
	clouds.Cover = 0
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(150, 155, 165)
	clouds.Parent = Workspace.Terrain
end

-- Riscos na tela: duas camadas rolando em velocidades diferentes. O Roblox corta partículas em
-- qualidade gráfica baixa, então é esta camada que garante a chuva visível em qualquer aparelho.
local screen = Instance.new("ScreenGui")
screen.Name = "ChuvaTela"
screen.DisplayOrder = -1
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local layers = {}
for _, def in ipairs({ { Tile = 300, Speed = 1500, Alpha = 0.5 }, { Tile = 190, Speed = 1000, Alpha = 0.32 } }) do
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = SCREEN_TEX
	image.ImageTransparency = 1
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(def.Tile, def.Tile)
	image.Size = UDim2.new(1, def.Tile * 2, 1, def.Tile * 2)
	image.Parent = screen
	table.insert(layers, { Image = image, Tile = def.Tile, Speed = def.Speed, Alpha = def.Alpha })
end
local SLANT = 0.12 -- a mesma inclinação dos riscos da textura

local sound = nil
local source = ReplicatedStorage:WaitForChild("Sounds"):FindFirstChild("Rain")
if source then
	sound = source:Clone()
	sound.Volume = 0
	sound.SoundGroup = SoundService:FindFirstChild("Ambiente")
	sound.Parent = SoundService
end

local k = 0 -- 0 = sol, 1 = chuva forte
local lastCam = nil
local rate = rainRate()
local rateTimer = 0

local function apply()
	local on = k > 0.001
	drops.Rate = rate * k
	screen.Enabled = on
	for _, layer in ipairs(layers) do
		layer.Image.ImageTransparency = 1 - layer.Alpha * k
	end
	grade.Enabled = on
	grade.Saturation = -0.25 * k
	grade.Brightness = -0.05 * k
	grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 215, 232), k)
	if atmosphere then
		atmosphere.Density = base.Density + 0.14 * k
		atmosphere.Haze = base.Haze + 2 * k
		atmosphere.Color = base.Color:Lerp(Color3.fromRGB(185, 192, 202), k)
	end
	if sunRays then
		sunRays.Intensity = base.Rays * (1 - k)
	end
	clouds.Cover = 0.85 * k
	if sound then
		sound.Volume = (source:GetAttribute("Gain") or 0.35) * k
		if on and not sound.IsPlaying then
			sound:Play()
		elseif not on and sound.IsPlaying then
			sound:Stop()
		end
	end
end
apply()

RunService.RenderStepped:Connect(function(dt)
	local target = Workspace:GetAttribute("Clima") == "Chuva" and 1 or 0
	if k ~= target then
		k = math.clamp(k + math.sign(target - k) * dt / FADE, 0, 1)
		apply()
	end
	if k <= 0 then
		lastCam = nil
		return
	end
	rateTimer -= dt
	if rateTimer <= 0 then
		rateTimer = 5
		rate = rainRate()
		drops.Rate = rate * k
	end
	local t = os.clock()
	for _, layer in ipairs(layers) do
		local fall = (t * layer.Speed) % layer.Tile
		local drift = (t * layer.Speed * SLANT) % layer.Tile
		layer.Image.Position = UDim2.fromOffset(drift - layer.Tile, fall - layer.Tile)
	end
	-- a caixa de gotas fica na frente da câmera, adiantada pelo movimento (de moto as gotas não ficam para trás)
	local camCF = Workspace.CurrentCamera.CFrame
	local camPos = camCF.Position
	local vel = lastCam and (camPos - lastCam) / math.max(dt, 1 / 240) or Vector3.zero
	lastCam = camPos
	local look = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.zero
	local ahead = Vector3.new(vel.X, 0, vel.Z) * 0.45
	box.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0) + look * 22 + ahead)
end)
