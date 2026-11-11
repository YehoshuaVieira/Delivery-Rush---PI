-- Trilha no chão até o destino do pedido (como nos jogos LEGO): setas seguindo as ruas, da moto até a marca,
-- e uma placa no ar sobre o próximo cruzamento onde a rota vira.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local UI = require(Modules:WaitForChild("UIKit"))
local RoadGraph = require(Modules:WaitForChild("RoadGraph"))

local areasFolder = Workspace:WaitForChild("Map"):WaitForChild("Areas")
local motosFolder = Workspace:WaitForChild("Motos")

local SPACING = 7 -- studs entre uma seta e outra
local AHEAD = 280 -- quanto da trilha aparece à frente da moto
local SIZE = 5
local TRAIL_TEX = "rbxassetid://136164699652579" -- chevron branca com contorno escuro (o contorno não é tingido)
local HEIGHT = 0.4 -- acima da faixa central, do buraco e das manchas
local OFF_ROUTE = 24 -- a moto se afastou isso da trilha: recalcula a rota
local COUNT = math.ceil(AHEAD / SPACING) + 1

local TURN_SHOW = 140 -- a placa aparece quando a conversão está a menos disto...
local TURN_HIDE = 4 -- ...e some quando a moto chega nela
local TURN_ANGLE = math.rad(30) -- desvio mínimo para contar como conversão
local TURN_MIN_LEG = 10 -- trechos menores que isto (ajuste até a marca) não contam
local TURN_HEIGHT = 10.5 -- acima dos carros

------------------------------------------------------------------ rota (módulo RoadGraph, o mesmo do prazo no servidor)
local graph = nil

local function allowedAreas()
	if player:GetAttribute("GameMode") == "Survival" then
		return { [GameConfig.Survival.AreaId] = true }
	end
	return AreaConfig.ParseUnlocked(player:GetAttribute("UnlockedAreas"))
end

local function ensureGraph()
	graph = RoadGraph.Get(areasFolder, allowedAreas())
end

local function route(from: Vector3, to: Vector3)
	return graph and RoadGraph.Route(graph, from, to)
end

------------------------------------------------------------------ trilha
local path = nil -- { Points, Dist (acumulada), Total }
local target, color, radius = nil, Color3.new(1, 1, 1), 16
local dirty = false
local lastRoute = 0

local function getRoot(): BasePart?
	local moto = motosFolder:FindFirstChild("Moto_" .. player.UserId)
	return moto and moto.PrimaryPart
end

local function setPath(points)
	if not points or #points < 2 then
		path = nil
		return
	end
	local dist = { 0 }
	for i = 2, #points do
		dist[i] = dist[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	path = { Points = points, Dist = dist, Total = dist[#dist] }
end

local function recompute()
	dirty = false
	local root = getRoot()
	if not target or not root then
		path = nil
		return
	end
	ensureGraph()
	lastRoute = os.clock()
	setPath(route(root.Position, target))
end

-- ponto e direção a d studs do começo da trilha
local function pointAt(d: number): (Vector3, Vector3)
	local pts, dist = path.Points, path.Dist
	for i = 2, #pts do
		if d <= dist[i] or i == #pts then
			local a, b = pts[i - 1], pts[i]
			local len = dist[i] - dist[i - 1]
			local dir = len > 0 and (b - a) / len or Vector3.zAxis
			return a + dir * math.clamp(d - dist[i - 1], 0, len), dir
		end
	end
	return pts[#pts], Vector3.zAxis
end

-- quanto da trilha a moto já percorreu e a distância dela até a trilha
local function progressOf(pos: Vector3): (number, number)
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local pts, dist = path.Points, path.Dist
	local bestD, bestOff = 0, math.huge
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local ab = b - a
		local len = ab.Magnitude
		local t = len > 0 and math.clamp((flat - a):Dot(ab) / (len * len), 0, 1) or 0
		local off = (a + ab * t - flat).Magnitude
		if off < bestOff then
			bestOff, bestD = off, dist[i - 1] + len * t
		end
	end
	return bestD, bestOff
end

local folder = Instance.new("Folder")
folder.Name = "RouteGuide"
folder.Parent = Workspace

local arrows = {}
for i = 1, COUNT do
	local part = Instance.new("Part")
	part.Name = "Seta"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(SIZE, 0.05, SIZE)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = part
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = TRAIL_TEX
	image.Rotation = 90 -- no topo da peça o "para cima" da imagem fica de lado; assim aponta para a frente
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = gui
	arrows[i] = { Part = part, Image = image, Shown = false }
end

------------------------------------------------------------------ placa de conversão
local sign = Instance.new("Part")
sign.Name = "PlacaConversao"
sign.Anchored = true
sign.CanCollide = false
sign.CanQuery = false
sign.CanTouch = false
sign.CastShadow = false
sign.Transparency = 1
sign.Size = Vector3.new(12, 9, 0.05)
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.Brightness = 1.6
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 30
signGui.Parent = sign
local plate = Instance.new("Frame")
plate.AnchorPoint = Vector2.new(0.5, 0.5)
plate.Position = UDim2.fromScale(0.5, 0.5)
plate.Size = UDim2.fromScale(1, 1)
plate.BackgroundColor3 = UI.Color.Panel
plate.Parent = signGui
local plateCorner = Instance.new("UICorner")
plateCorner.CornerRadius = UDim.new(0, 36)
plateCorner.Parent = plate
local plateStroke = Instance.new("UIStroke")
plateStroke.Thickness = 10
plateStroke.Parent = plate
local plateScale = Instance.new("UIScale")
plateScale.Parent = plate
local chevrons = {}
for i = 1, 2 do
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = TRAIL_TEX
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Size = UDim2.fromScale(0.42, 0.56)
	image.Parent = plate
	chevrons[i] = image
end
local signLabel = Instance.new("TextLabel")
signLabel.BackgroundTransparency = 1
signLabel.AnchorPoint = Vector2.new(0.5, 1)
signLabel.Position = UDim2.new(0.5, 0, 1, -16)
signLabel.Size = UDim2.new(1, -40, 0, 62)
signLabel.FontFace = UI.Font.Title
signLabel.TextScaled = true
signLabel.TextColor3 = UI.Color.Text
signLabel.Parent = plate

-- próxima conversão à frente da moto: ponto, direção de chegada, lado (1 = direita) e distância
local function nextTurn(progress: number)
	local pts, dist = path.Points, path.Dist
	for i = 2, #pts - 1 do
		local ahead = dist[i] - progress
		if ahead > TURN_SHOW then
			return nil
		end
		if ahead > TURN_HIDE then
			local inDir = Vector3.new(pts[i].X - pts[i - 1].X, 0, pts[i].Z - pts[i - 1].Z)
			local outDir = Vector3.new(pts[i + 1].X - pts[i].X, 0, pts[i + 1].Z - pts[i].Z)
			if inDir.Magnitude >= TURN_MIN_LEG and outDir.Magnitude >= TURN_MIN_LEG then
				inDir, outDir = inDir.Unit, outDir.Unit
				if math.acos(math.clamp(inDir:Dot(outDir), -1, 1)) >= TURN_ANGLE then
					return pts[i], inDir, inDir:Cross(outDir).Y < 0 and 1 or -1, ahead
				end
			end
		end
	end
	return nil
end

local turnKey, turnShownAt = nil, 0
local function hideSign()
	turnKey = nil
	sign.Parent = nil
end

-- placa virada para quem chega, com "»" para o lado da conversão; entra crescendo e flutua
local function updateSign(progress: number, now: number)
	local at, inDir, side, ahead = nextTurn(progress)
	if not at then
		hideSign()
		return
	end
	local key = string.format("%d,%d", math.floor(at.X), math.floor(at.Z))
	if key ~= turnKey then
		turnKey, turnShownAt = key, now
		local right = side > 0
		for i, image in ipairs(chevrons) do
			local x = i == 1 and 0.37 or 0.6
			image.Rotation = right and 90 or -90
			image.Position = UDim2.fromScale(right and x or 1 - x, 0.4)
		end
		signLabel.Text = right and "DIREITA" or "ESQUERDA"
	end
	local still = UI.ReducedMotion()
	local pop = still and 1 or math.clamp((now - turnShownAt) / 0.25, 0, 1)
	plateScale.Scale = 0.6 + 0.4 * (1 - (1 - pop) ^ 3)
	local fade = math.clamp((ahead - TURN_HIDE) / 10, 0, 1)
	plate.BackgroundTransparency = 1 - 0.9 * fade
	plateStroke.Color = color
	plateStroke.Transparency = 1 - fade
	signLabel.TextTransparency = 1 - fade
	for i, image in ipairs(chevrons) do
		local wave = still and 1 or 0.5 + 0.5 * math.sin(now * 7 - i * 1.4)
		image.ImageColor3 = color
		image.ImageTransparency = 1 - fade * (0.55 + 0.45 * wave)
	end
	local bob = still and 0 or math.sin(now * 3) * 0.35
	local pos = Vector3.new(at.X, TURN_HEIGHT + bob, at.Z)
	sign.CFrame = CFrame.lookAt(pos, pos - inDir)
	sign.Parent = folder
end

local function show(arrow, on: boolean)
	if arrow.Shown ~= on then
		arrow.Shown = on
		arrow.Part.Parent = on and folder or nil
	end
end

local function onTarget()
	local t = player:GetAttribute("RouteTarget")
	color = player:GetAttribute("RouteColor") or color
	radius = player:GetAttribute("RouteRadius") or radius
	if typeof(t) ~= "Vector3" then
		target = nil
		dirty = true
	elseif not target or (t - target).Magnitude > 1 then
		target = t
		dirty = true
	end
end
player:GetAttributeChangedSignal("RouteTarget"):Connect(onTarget)
player:GetAttributeChangedSignal("GameMode"):Connect(function()
	dirty = true
end)
player:GetAttributeChangedSignal("UnlockedAreas"):Connect(function()
	dirty = true
end)
onTarget()

RunService.RenderStepped:Connect(function()
	local root = getRoot()
	if dirty or (target and root and not path and os.clock() - lastRoute > 1) then
		recompute()
	end
	if not path or not root or not target then
		for _, arrow in ipairs(arrows) do
			show(arrow, false)
		end
		hideSign()
		return
	end
	local progress, off = progressOf(root.Position)
	if off > OFF_ROUTE and os.clock() - lastRoute > 0.6 then
		recompute() -- pegou outro caminho: a trilha sai de onde a moto está
		if not path then
			hideSign()
			return
		end
		progress = progressOf(root.Position)
	end
	updateSign(progress, os.clock())
	-- as setas ficam presas ao chão (múltiplos de SPACING) e uma onda de brilho corre até o destino
	local first = (math.floor(progress / SPACING) + 1) * SPACING
	local stop = path.Total - radius * 1.7
	local now = os.clock()
	for i, arrow in ipairs(arrows) do
		local d = first + (i - 1) * SPACING
		local ahead = d - progress
		if d <= stop and ahead <= AHEAD then
			local pos, dir = pointAt(d)
			local at = Vector3.new(pos.X, HEIGHT, pos.Z)
			arrow.Part.CFrame = CFrame.lookAt(at, at + dir)
			local fade = math.clamp(ahead / 12, 0, 1) * math.clamp((AHEAD - ahead) / 60, 0, 1)
			local wave = 0.5 + 0.5 * math.sin(d / 9 - now * 6)
			arrow.Image.ImageColor3 = color
			arrow.Image.ImageTransparency = 1 - fade * (0.65 + 0.35 * wave)
			show(arrow, true)
		else
			show(arrow, false)
		end
	end
end)
