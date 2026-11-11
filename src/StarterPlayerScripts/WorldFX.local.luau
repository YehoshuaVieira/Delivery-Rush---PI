-- Vida da cidade no cliente: trânsito, pedestres, cones, perigos e bolas de demolição.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local MotoSignals = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MotoSignals"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local npcMotoAsset = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("NPCMoto")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local RoadMap = require(Modules:WaitForChild("RoadMap"))
local AbilityConfig = require(Modules:WaitForChild("AbilityConfig"))
local RoadGraph = require(Modules:WaitForChild("RoadGraph"))
local SURV = GameConfig.Survival
local SURVIVAL_AREA = AreaConfig.Get(SURV.AreaId).FolderName

local map = Workspace:WaitForChild("Map")
local areasFolder = map:WaitForChild("Areas")
local motosFolder = Workspace:WaitForChild("Motos")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalWorldFX"
fxFolder.Parent = Workspace

local SIDEWALK_W = map:GetAttribute("SidewalkW") or 4

local STOP_AHEAD = 16
local CAR_GAP = 20
local JAM_GAP = 4 -- engarrafamento: carros parados quase colados
local JAM_QUEUE = 10 -- carros em cada mão da fila logo no começo
local JAM_STEP = 16
local HIT_COOLDOWN = 0.8
local DRAW_DISTANCE = 700 -- 450 em aparelho fraco (ver lowEnd)
local MOTO_DETAIL_DISTANCE = 160 -- além disso a moto NPC some com as peças pequenas
local PED_RADIUS = 450
local PEDS_PER_BLOCK = 2
local PED_HIT_RADIUS = 3.2
local RAGDOLL_TIME = 2.6
local CONE_SPAWN_DISTANCE = 450
local CONE_DESPAWN_DISTANCE = 650
local CONE_RESET_TIME = 6
local ON_GROUND_Y = 3.4

-- nível de dificuldade da Sobrevivência (= entregas feitas na partida; 0 fora dela)
local level = 0

local function getChassis()
	local moto = motosFolder:FindFirstChild("Moto_" .. player.UserId)
	return moto and moto.PrimaryPart
end

-- Habilidades (atributos locais do MotoController, relógio os.clock)
local function abilityOn(attr: string): boolean
	return os.clock() < (player:GetAttribute(attr) or 0)
end
-- Câmera Lenta: o mundo anda devagar (a moto do jogador não)
local function worldScale(): number
	return abilityOn("SlowUntil") and AbilityConfig.Get("slowmo").Scale or 1
end

local function part(parent, name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function visualPart(parent, name, size, color, material, shape)
	local p = part(parent, name, size, color, material, shape)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local DARK_GLASS = Color3.fromRGB(40, 50, 60)
local TIRE = Color3.fromRGB(25, 25, 25)
local HEAD = Color3.fromRGB(255, 250, 220)
local TAIL = Color3.fromRGB(220, 30, 30)
local SP, NEON, GLASS = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass
local CYL = Enum.PartType.Cylinder

local VEHICLES = {
	car = {
		Weight = 0.62, Half = Vector3.new(2.3, 2, 4.7),
		Colors = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 90, 200), Color3.fromRGB(230, 230, 230), Color3.fromRGB(30, 30, 30),
			Color3.fromRGB(240, 200, 40), Color3.fromRGB(60, 160, 90), Color3.fromRGB(240, 130, 30), Color3.fromRGB(150, 150, 160) },
		Parts = {
			{ "Body", Vector3.new(4.6, 2, 9.4), CFrame.new(0, 1.6, 0), nil, SP },
			{ "Cabin", Vector3.new(4.2, 1.7, 5), CFrame.new(0, 3.4, 0.6), DARK_GLASS, GLASS },
			{ "Axle", Vector3.new(5, 1.8, 1.8), CFrame.new(0, 0.9, -3), TIRE, SP, CYL },
			{ "Axle", Vector3.new(5, 1.8, 1.8), CFrame.new(0, 0.9, 3), TIRE, SP, CYL },
			{ "Headlights", Vector3.new(3.6, 0.5, 0.2), CFrame.new(0, 1.9, -4.72), HEAD, NEON },
			{ "Taillights", Vector3.new(3.6, 0.5, 0.2), CFrame.new(0, 1.9, 4.72), TAIL, NEON },
		},
	},
	bus = {
		Weight = 0.13, Half = Vector3.new(2.9, 3, 11),
		Colors = { Color3.fromRGB(245, 200, 40), Color3.fromRGB(235, 235, 240), Color3.fromRGB(40, 110, 200), Color3.fromRGB(200, 50, 50) },
		Parts = {
			{ "Body", Vector3.new(5.6, 5, 22), CFrame.new(0, 3.3, 0), nil, SP },
			{ "Windows", Vector3.new(5.7, 1.7, 20.4), CFrame.new(0, 4.4, 0.3), DARK_GLASS, GLASS },
			{ "Windshield", Vector3.new(5.2, 2.6, 0.2), CFrame.new(0, 4, -11.02), DARK_GLASS, GLASS },
			{ "Axle", Vector3.new(6, 2.2, 2.2), CFrame.new(0, 1.1, -7), TIRE, SP, CYL },
			{ "Axle", Vector3.new(6, 2.2, 2.2), CFrame.new(0, 1.1, 7), TIRE, SP, CYL },
			{ "Stripe", Vector3.new(5.7, 0.5, 22.05), CFrame.new(0, 2.2, 0), Color3.fromRGB(234, 29, 44), SP },
			{ "Headlights", Vector3.new(4.6, 0.6, 0.2), CFrame.new(0, 1.8, -11.02), HEAD, NEON },
			{ "Taillights", Vector3.new(4.6, 0.6, 0.2), CFrame.new(0, 1.8, 11.02), TAIL, NEON },
		},
	},
	moto = {
		Weight = 0.25, Half = Vector3.new(1.3, 3, 4),
		Colors = { Color3.fromRGB(234, 29, 44), Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 160, 90), Color3.fromRGB(30, 30, 35) },
		Parts = {
			{ "Torso", Vector3.new(1.6, 1.9, 0.95), CFrame.new(0, 5.3, 1.0) * CFrame.Angles(math.rad(-18), 0, 0), nil, SP },
			{ "Helmet", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 6.85, 0.65), Color3.fromRGB(234, 29, 44), SP, Enum.PartType.Ball },
			{ "Visor", Vector3.new(1.1, 0.5, 0.2), CFrame.new(0, 6.9, -0.08), Color3.fromRGB(25, 30, 40), GLASS },
			{ "LArm", Vector3.new(0.55, 1.7, 0.6), CFrame.new(-1.0, 5.4, 0.1) * CFrame.Angles(math.rad(-65), 0, 0), nil, SP },
			{ "RArm", Vector3.new(0.55, 1.7, 0.6), CFrame.new(1.0, 5.4, 0.1) * CFrame.Angles(math.rad(-65), 0, 0), nil, SP },
			{ "LLeg", Vector3.new(0.7, 0.7, 1.8), CFrame.new(-0.6, 4.3, 0.4), Color3.fromRGB(35, 40, 60), SP },
			{ "RLeg", Vector3.new(0.7, 0.7, 1.8), CFrame.new(0.6, 4.3, 0.4), Color3.fromRGB(35, 40, 60), SP },
		},
		Mesh = true,
	},
}
local VEHICLE_ORDER = { "car", "bus", "moto" }

local npcMeshOffsets = {}
do
	local cf, size = npcMotoAsset:GetBoundingBox()
	local ground = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	for _, p in ipairs(npcMotoAsset:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(npcMeshOffsets, { Part = p, Offset = ground:ToObjectSpace(p.CFrame) })
		end
	end
end

local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local LIFT = CFrame.new(0, 0.2, 0)
local function assetVariant(model: Model)
	local pivot = model:GetPivot()
	local meshes = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(meshes, { Part = p, Offset = LIFT * pivot:ToObjectSpace(p.CFrame) })
		end
	end
	local _, size = model:GetBoundingBox()
	return { Name = model.Name, Meshes = meshes, Half = size / 2 }
end
do
	local cars = assetsFolder:FindFirstChild("Cars")
	local list = {}
	for _, m in ipairs(cars and cars:GetChildren() or {}) do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	if #list > 0 then
		VEHICLES.car.Variants = {}
		for _, m in ipairs(list) do
			table.insert(VEHICLES.car.Variants, assetVariant(m))
		end
	end
	local bus = assetsFolder:FindFirstChild("Bus")
	if bus then
		VEHICLES.bus.Variants = { assetVariant(bus) }
	end
end

local pools = {}

local function newVehicleModel(kind: string, variant: number?)
	local def = VEHICLES[kind]
	local model = Instance.new("Model")
	model.Name = "Traffic_" .. kind
	local parts, offsets = {}, {}
	local v = variant and def.Variants and def.Variants[variant]
	if v then
		for _, m in ipairs(v.Meshes) do
			local clone = m.Part:Clone()
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Parent = model
			table.insert(parts, clone)
			table.insert(offsets, m.Offset)
		end
		return { Model = model, Parts = parts, Offsets = offsets, Kind = kind, Key = kind .. variant, Mesh = true }
	end
	for _, d in ipairs(def.Parts) do
		table.insert(parts, visualPart(model, d[1], d[2], d[4] or Color3.new(1, 1, 1), d[5], d[6]))
		table.insert(offsets, d[3])
	end
	if def.Mesh then
		for _, m in ipairs(npcMeshOffsets) do
			local clone = m.Part:Clone()
			-- só visual (a batida é calculada no script): sem colisão, consulta e toque, mais leve para mover
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Parent = model
			table.insert(parts, clone)
			table.insert(offsets, m.Offset)
		end
	end
	-- moto NPC: as peças pequenas (viseira, braços, pernas e detalhes) somem de longe e não são movidas
	local detail = nil
	if kind == "moto" then
		detail = {}
		for i, p in ipairs(parts) do
			if (i >= 3 and i <= #def.Parts) or (i > #def.Parts and math.max(p.Size.X, p.Size.Y, p.Size.Z) < 1.5) then
				detail[i] = true
			end
		end
	end
	return { Model = model, Parts = parts, Offsets = offsets, Kind = kind, Key = kind .. "0", Mesh = false, Detail = detail, Far = false }
end

local function acquireVehicle(kind: string, color: Color3, variant: number?)
	local key = kind .. (variant or 0)
	local pool = pools[key]
	local entry = (pool and table.remove(pool)) or newVehicleModel(kind, variant)
	if not entry.Mesh then
		entry.Parts[1].Color = color
		if kind == "moto" then
			entry.Parts[4].Color = color
			entry.Parts[5].Color = color
		end
	end
	entry.Model.Parent = fxFolder
	return entry
end

local function releaseVehicle(entry)
	entry.Model.Parent = nil
	pools[entry.Key] = pools[entry.Key] or {}
	table.insert(pools[entry.Key], entry)
end

local function pickKind(): string
	local r = math.random()
	local acc = 0
	for _, kind in ipairs(VEHICLE_ORDER) do
		acc += VEHICLES[kind].Weight
		if r < acc then
			return kind
		end
	end
	return "car"
end

local routes = {}

local function poseAt(route, s: number): CFrame
	local L, r = route.Length, route.Lane
	local arc = math.pi * r
	s = s % route.Total
	local d, right = route.Dir, route.Right
	if s < L then
		local pos = route.A + d * s + right * r
		return CFrame.lookAt(pos, pos + d)
	elseif s < L + arc then
		local t = (s - L) / r
		local pos = route.B + right * r * math.cos(t) + d * r * math.sin(t)
		return CFrame.lookAt(pos, pos + (-right * math.sin(t) + d * math.cos(t)))
	elseif s < 2 * L + arc then
		local pos = route.B - d * (s - L - arc) - right * r
		return CFrame.lookAt(pos, pos - d)
	else
		local t = (s - 2 * L - arc) / r
		local pos = route.A - right * r * math.cos(t) - d * r * math.sin(t)
		return CFrame.lookAt(pos, pos + (right * math.sin(t) - d * math.cos(t)))
	end
end

local function newCar(route, s: number, kind: string, extra: boolean)
	local def = VEHICLES[kind]
	local variant = def.Variants and math.random(1, #def.Variants) or nil
	return {
		S = s, CFrame = poseAt(route, s), Kind = kind, Variant = variant,
		Half = variant and def.Variants[variant].Half or def.Half,
		Color = def.Colors[math.random(1, #def.Colors)], Entry = nil, Extra = extra, Id = math.random(0, 5),
	}
end

-- veículos extras da Sobrevivência: mais motos no meio
local function pickExtraKind(): string
	local r = math.random()
	return r < 0.5 and "car" or (r < 0.6 and "bus" or "moto")
end

-- Trânsito da rota conforme o nível: mais veículos e mais rápidos (só no bairro da Sobrevivência)
local function applyRouteDifficulty(route, avoid: Vector3?)
	local inArea = route.AreaName == SURVIVAL_AREA and level > 0
	route.Speed = route.BaseSpeed * (inArea and math.min(SURV.MaxTrafficSpeed, 1 + level * SURV.TrafficSpeedPerLevel) or 1)
	local mult = inArea and math.min(SURV.MaxTraffic, 1 + level * SURV.TrafficPerLevel) or 1
	local capacity = math.floor(route.Total / (CAR_GAP + 16))
	local want = math.max(route.BaseCount, math.min(math.floor(route.BaseCount * mult + 0.5), capacity))
	local cars = route.Cars
	for i = #cars, 1, -1 do
		if #cars <= want then
			break
		end
		local car = cars[i]
		if car.Extra then
			if car.Entry then
				releaseVehicle(car.Entry)
			end
			table.remove(cars, i)
		end
	end
	-- o extra entra no meio do maior vão (a lista segue ordenada por S) e longe da moto, para não "brotar" na frente
	while #cars < want and #cars > 0 do
		local n = #cars
		local bestI, bestGap = nil, 0
		for i, car in ipairs(cars) do
			local gap = n == 1 and route.Total or (cars[(i % n) + 1].S - car.S) % route.Total
			if gap > bestGap and (not avoid or (poseAt(route, car.S + gap / 2).Position - avoid).Magnitude > 160) then
				bestI, bestGap = i, gap
			end
		end
		if not bestI or bestGap < 2 * (CAR_GAP + 12) then
			break
		end
		table.insert(cars, bestI + 1, newCar(route, (cars[bestI].S + bestGap / 2) % route.Total, pickExtraKind(), true))
	end
end

local function addRoute(routeFolder: Instance)
	local a, b = routeFolder:GetAttribute("A"), routeFolder:GetAttribute("B")
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return
	end
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local lane = routeFolder:GetAttribute("Lane") or 8
	local areaFolder = routeFolder.Parent and routeFolder.Parent.Parent and routeFolder.Parent.Parent.Parent
	local speed = routeFolder:GetAttribute("Speed") or 30
	local count = routeFolder:GetAttribute("Cars") or 10
	local route = {
		A = a, B = b, Dir = dir, Right = dir:Cross(Vector3.yAxis), Lane = lane,
		Length = length, Total = 2 * length + 2 * math.pi * lane,
		Speed = speed, BaseSpeed = speed, BaseCount = count, Cars = {},
		AreaName = areaFolder and areaFolder.Name or "",
	}
	local serverTime = Workspace:GetServerTimeNow()
	for i = 1, count do
		local s = (serverTime * route.Speed + (i - 1) * route.Total / count) % route.Total
		table.insert(route.Cars, newCar(route, s, pickKind(), false))
	end
	table.insert(routes, route)
	if level > 0 then
		applyRouteDifficulty(route, getChassis() and getChassis().Position)
	end
end

local zones = {}
local ZONE_CELL = 128
local zoneGrid = {}
local zoneStamp = 0
local function cellKey(cx: number, cz: number): number
	return (cx + 2000) * 10000 + (cz + 2000)
end

local function newZone(kind: string, center: Vector3, axis: Vector3, halfLength: number, halfWidth: number, limit: number?)
	local zone = {
		Kind = kind, Center = center, Axis = axis, Side = axis:Cross(Vector3.yAxis), Limit = limit,
		HalfLength = halfLength + 1.4, HalfWidth = halfWidth + 0.6,
		LastHit = 0, Stamp = 0, Cells = {},
	}
	table.insert(zones, zone)
	local r = math.max(zone.HalfLength, zone.HalfWidth) + 2
	for cx = math.floor((center.X - r) / ZONE_CELL), math.floor((center.X + r) / ZONE_CELL) do
		for cz = math.floor((center.Z - r) / ZONE_CELL), math.floor((center.Z + r) / ZONE_CELL) do
			local key = cellKey(cx, cz)
			zoneGrid[key] = zoneGrid[key] or {}
			table.insert(zoneGrid[key], zone)
			table.insert(zone.Cells, key)
		end
	end
	return zone
end

local function removeZone(zone)
	for _, key in ipairs(zone.Cells) do
		local cell = zoneGrid[key]
		local i = cell and table.find(cell, zone)
		if i then
			table.remove(cell, i)
		end
	end
	local i = table.find(zones, zone)
	if i then
		table.remove(zones, i)
	end
end

-- Obra, desvio e carro parado (gravados pelo MapBuilder.Passagem): só servem para não empilhar perigos ao lado
local function addBlocker(folder: Instance)
	local c = folder:GetAttribute("Center")
	if folder.Name == "Blocker" and typeof(c) == "Vector3" then
		newZone("blocker", c, Vector3.xAxis, folder:GetAttribute("HalfLength") or 2, folder:GetAttribute("HalfWidth") or 2)
	end
end

local function addZone(folder: Instance)
	local kind
	if folder.Name == "SpikeStrip" then
		kind = "spike"
	elseif folder.Name == "Hazard" then
		kind = folder:GetAttribute("Type")
	end
	local center, axis = folder:GetAttribute("Center"), folder:GetAttribute("Axis")
	if not kind or typeof(center) ~= "Vector3" or typeof(axis) ~= "Vector3" then
		return
	end
	newZone(kind, center, axis, folder:GetAttribute("HalfLength") or 2, folder:GetAttribute("HalfWidth") or 8, folder:GetAttribute("Limit"))
end

-- zonas nas células do trajeto entre dois frames (sem repetir)
local function zonesNear(a: Vector3, b: Vector3)
	local x0, x1 = math.min(a.X, b.X), math.max(a.X, b.X)
	local z0, z1 = math.min(a.Z, b.Z), math.max(a.Z, b.Z)
	if x1 - x0 > 400 or z1 - z0 > 400 then
		x0, x1, z0, z1 = b.X, b.X, b.Z, b.Z
	end
	zoneStamp += 1
	local list = {}
	for cx = math.floor(x0 / ZONE_CELL), math.floor(x1 / ZONE_CELL) do
		for cz = math.floor(z0 / ZONE_CELL), math.floor(z1 / ZONE_CELL) do
			local cell = zoneGrid[cellKey(cx, cz)]
			if cell then
				for _, zone in ipairs(cell) do
					if zone.Stamp ~= zoneStamp then
						zone.Stamp = zoneStamp
						table.insert(list, zone)
					end
				end
			end
		end
	end
	return list
end

local function inside(zone, pos: Vector3): boolean
	local d = Vector3.new(pos.X - zone.Center.X, 0, pos.Z - zone.Center.Z)
	return math.abs(d:Dot(zone.Axis)) <= zone.HalfLength and math.abs(d:Dot(zone.Side)) <= zone.HalfWidth
end

local lastZonePos = nil
local function checkZones(pos: Vector3?)
	if not pos then
		lastZonePos = nil
		return
	end
	local from = lastZonePos or pos
	lastZonePos = pos
	if pos.Y > ON_GROUND_Y then
		return
	end
	local now = os.clock()
	local travel = (pos - from).Magnitude
	local steps = math.clamp(math.ceil(travel / 1.5), 1, 60)
	for _, zone in ipairs(zonesNear(from, pos)) do
		if zone.Kind ~= "blocker" and now - zone.LastHit > 2 and (zone.Center - pos).Magnitude < 40 + travel then
			for k = 1, steps do
				if inside(zone, from:Lerp(pos, k / steps)) then
					zone.LastHit = now
					if zone.Kind == "spike" then
						MotoSignals.FlatTire:Fire()
					else
						MotoSignals.Hazard:Fire(zone.Kind, zone.Limit)
					end
					break
				end
			end
		end
	end
end

local coneSpots = {}
local function addConeGroup(group: Instance)
	if group.Name ~= "ConeGroup" then
		return
	end
	for k = 1, 5 do
		local p = group:GetAttribute("P" .. k)
		if typeof(p) == "Vector3" then
			table.insert(coneSpots, { Home = CFrame.new(p.X, 0, p.Z), Cone = nil })
		end
	end
end

local CONE_PROPS = PhysicalProperties.new(0.15, 0.5, 0.2)
local function buildCone(home: CFrame)
	local model = Instance.new("Model")
	model.Name = "Cone"
	local base = part(model, "Base", Vector3.new(2.2, 0.3, 2.2), Color3.fromRGB(40, 40, 45))
	base.CFrame = home * CFrame.new(0, 0.15, 0)
	base.CustomPhysicalProperties = CONE_PROPS
	for _, def in ipairs({
		{ 1.4, 1.7, 0.3, Color3.fromRGB(255, 120, 20) },
		{ 0.5, 1.3, 1.7, Color3.fromRGB(248, 248, 248) },
		{ 1.1, 0.9, 2.2, Color3.fromRGB(255, 120, 20) },
	}) do
		local h, d, y = def[1], def[2], def[3]
		local p = part(model, "Body", Vector3.new(h, d, d), def[4], SP, CYL)
		p.CFrame = home * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		p.CustomPhysicalProperties = CONE_PROPS
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = p
		weld.Parent = p
	end
	model.PrimaryPart = base
	model.Parent = fxFolder
	return { Model = model, Root = base, Knocked = false, KnockedAt = 0 }
end

local SKIN = { Color3.fromRGB(255, 220, 180), Color3.fromRGB(230, 180, 140), Color3.fromRGB(180, 125, 85), Color3.fromRGB(120, 80, 55) }
local SHIRT = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(250, 250, 250), Color3.fromRGB(60, 170, 90),
	Color3.fromRGB(250, 200, 50), Color3.fromRGB(150, 80, 200), Color3.fromRGB(40, 40, 45), Color3.fromRGB(255, 140, 180) }
local PANTS = { Color3.fromRGB(40, 60, 110), Color3.fromRGB(30, 30, 35), Color3.fromRGB(120, 100, 80), Color3.fromRGB(90, 90, 95) }

local pedPool = {}
local blocksWithPeds = {}
local allPeds = {}

local function newPedModel()
	local model = Instance.new("Model")
	model.Name = "Pedestre"
	local white = Color3.new(1, 1, 1)
	return { Model = model, P = {
		Torso = visualPart(model, "Torso", Vector3.new(1.6, 1.8, 0.9), white),
		Head = visualPart(model, "Head", Vector3.new(1.1, 1.1, 1.1), white),
		LArm = visualPart(model, "LArm", Vector3.new(0.6, 1.7, 0.7), white),
		RArm = visualPart(model, "RArm", Vector3.new(0.6, 1.7, 0.7), white),
		LLeg = visualPart(model, "LLeg", Vector3.new(0.75, 2, 0.8), white),
		RLeg = visualPart(model, "RLeg", Vector3.new(0.75, 2, 0.8), white),
	} }
end

local function acquirePed()
	local entry = table.remove(pedPool) or newPedModel()
	local skin, shirt, pants = SKIN[math.random(#SKIN)], SHIRT[math.random(#SHIRT)], PANTS[math.random(#PANTS)]
	entry.P.Head.Color = skin
	entry.P.Torso.Color = shirt
	entry.P.LArm.Color = shirt
	entry.P.RArm.Color = shirt
	entry.P.LLeg.Color = pants
	entry.P.RLeg.Color = pants
	entry.Model.Parent = fxFolder
	return entry
end

local pedRects = {}
local function loadRects(areaFolder: Instance)
	local text = areaFolder:GetAttribute("BlockRects")
	if type(text) ~= "string" then
		return
	end
	for x0, z0, x1, z1 in string.gmatch(text, "(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)") do
		local r = { x0 = tonumber(x0), z0 = tonumber(z0), x1 = tonumber(x1), z1 = tonumber(z1) }
		r.Center = Vector3.new((r.x0 + r.x1) / 2, 0, (r.z0 + r.z1) / 2)
		r.Key = areaFolder.Name .. ":" .. x0 .. ":" .. z0
		local inset = SIDEWALK_W / 2
		r.W = (r.x1 - r.x0) - inset * 2
		r.D = (r.z1 - r.z0) - inset * 2
		r.Perimeter = 2 * (r.W + r.D)
		table.insert(pedRects, r)
	end
end

-- posição na calçada (perímetro do quarteirão, recuado meia calçada)
local function ringPose(r, s: number, dirSign: number): CFrame
	local inset = SIDEWALK_W / 2
	local x0, z0, x1, z1 = r.x0 + inset, r.z0 + inset, r.x1 - inset, r.z1 - inset
	local w, d = r.W, r.D
	s = s % r.Perimeter
	local pos, forward
	if s < w then
		pos, forward = Vector3.new(x0 + s, 0, z0), Vector3.new(1, 0, 0)
	elseif s < w + d then
		pos, forward = Vector3.new(x1, 0, z0 + (s - w)), Vector3.new(0, 0, 1)
	elseif s < 2 * w + d then
		pos, forward = Vector3.new(x1 - (s - w - d), 0, z1), Vector3.new(-1, 0, 0)
	else
		pos, forward = Vector3.new(x0, 0, z1 - (s - 2 * w - d)), Vector3.new(0, 0, -1)
	end
	local world = Vector3.new(pos.X, 0.3, pos.Z)
	return CFrame.lookAt(world, world + forward * dirSign)
end

local function blockCentersNear(pos: Vector3)
	local list = {}
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, r in ipairs(pedRects) do
		if (r.Center - flat).Magnitude < PED_RADIUS then
			list[r.Key] = r
		end
	end
	return list
end

local function releasePed(ped)
	ped.Entry.Model.Parent = nil
	table.insert(pedPool, ped.Entry)
	allPeds[ped] = nil
end

-- pedestres por quarteirão (sobem com o nível da Sobrevivência)
local function pedTarget(rect): number
	local per = math.min(SURV.MaxPeds, PEDS_PER_BLOCK + level * SURV.PedsPerLevel)
	return math.clamp(math.round(per * rect.Perimeter / 500), 1, math.ceil(4 * per / PEDS_PER_BLOCK))
end

local function refreshPedBlocks(pos: Vector3)
	local wanted = blockCentersNear(pos)
	for key, peds in pairs(blocksWithPeds) do
		if not wanted[key] then
			for _, ped in ipairs(peds) do
				releasePed(ped)
			end
			blocksWithPeds[key] = nil
		end
	end
	for key, rect in pairs(wanted) do
		local peds = blocksWithPeds[key]
		if not peds then
			peds = { Lost = 0 }
			blocksWithPeds[key] = peds
		end
		local target = pedTarget(rect) - peds.Lost -- atropelados só voltam quando o quarteirão sai e volta
		while #peds < target do
			local ped = {
				Entry = acquirePed(), Rect = rect, S = math.random() * rect.Perimeter,
				Dir = (math.random() < 0.5) and -1 or 1, Speed = 4 + math.random() * 3, Phase = math.random() * 6,
			}
			table.insert(peds, ped)
			allPeds[ped] = true
		end
		while #peds > math.max(target, 0) do
			releasePed(table.remove(peds))
		end
	end
end

local balls = {}
local lastBallHit = 0

local function addBall(folder: Instance)
	if folder.Name ~= "WreckingBall" then
		return
	end
	local pivot, side = folder:GetAttribute("Pivot"), folder:GetAttribute("Side")
	if typeof(pivot) ~= "Vector3" or typeof(side) ~= "Vector3" then
		return
	end
	local radius = folder:GetAttribute("Radius") or 3.6
	local length = folder:GetAttribute("Length") or 22
	local model = Instance.new("Model")
	model.Name = "WreckingBall"
	local ball = visualPart(model, "Ball", Vector3.new(radius * 2, radius * 2, radius * 2), Color3.fromRGB(45, 45, 50), Enum.Material.Metal, Enum.PartType.Ball)
	local chain = visualPart(model, "Chain", Vector3.new(0.35, 0.35, length), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	local rest = pivot - Vector3.yAxis * length
	ball.CFrame = CFrame.new(rest)
	chain.CFrame = CFrame.lookAt((pivot + rest) / 2, rest)
	model.Parent = fxFolder
	table.insert(balls, {
		Pivot = pivot, Side = side, Length = length, Radius = radius, Ball = ball, Chain = chain,
		Amplitude = folder:GetAttribute("Amplitude") or 0.8, Period = folder:GetAttribute("Period") or 3.2,
		Phase = folder:GetAttribute("Phase") or 0,
	})
end

local function watchArea(areaFolder: Instance)
	task.spawn(function()
		local obstacles = areaFolder:WaitForChild("Obstacles", 30)
		if not obstacles then
			return
		end
		local function watch(name, handler)
			local f = obstacles:WaitForChild(name, 30)
			if f then
				for _, child in ipairs(f:GetChildren()) do
					handler(child)
				end
				f.ChildAdded:Connect(handler)
			end
		end
		task.spawn(watch, "TrafficRoutes", addRoute)
		task.spawn(watch, "ConeSpots", addConeGroup)
		task.spawn(watch, "Espinhos", addZone)
		task.spawn(watch, "Perigos", addZone)
		task.spawn(watch, "Becos", addZone)
		task.spawn(watch, "Bolas", addBall)
		task.spawn(watch, "Bloqueios", addBlocker)
	end)
end
for _, a in ipairs(areasFolder:GetChildren()) do
	watchArea(a)
	loadRects(a)
end
areasFolder.ChildAdded:Connect(function(a)
	watchArea(a)
	loadRects(a)
end)

local lastHit = 0
local moveParts, moveCFrames = {}, {}
local moveCount = 0
local function push(p, cf)
	moveCount += 1
	moveParts[moveCount] = p
	moveCFrames[moveCount] = cf
end

-- Desenho por distância: perto, todo quadro; longe ou atrás da câmera, de vez em quando. Só o REDESENHO fica
-- menos frequente: a posição de cada carro/pedestre é calculada todo quadro (batida, Sirene etc. iguais).
local frameNo = 0
local camLook = Vector3.zAxis
local function drawThisFrame(pos: Vector3, camPos: Vector3, id: number): boolean
	local rel = pos - camPos
	if rel:Dot(camLook) < -40 then
		return (frameNo + id) % 6 == 0
	end
	local d2 = rel.X * rel.X + rel.Z * rel.Z
	if d2 < 220 * 220 then
		return true
	elseif d2 < 420 * 420 then
		return (frameNo + id) % 2 == 0
	end
	return (frameNo + id) % 3 == 0
end

-- aparelho fraco (qualidade gráfica baixa escolhida pelo jogador, ou celular): carros e pedestres somem mais perto
local function lowEnd(): boolean
	local ok, q = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if ok and q and q ~= Enum.SavedQualitySetting.Automatic then
		return q.Value <= 4
	end
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

-- distância (no plano) de um ponto até a reta da rota
local function routeDistance(route, p: Vector3): number
	local rel = Vector3.new(p.X - route.A.X, 0, p.Z - route.A.Z)
	local t = math.clamp(rel:Dot(route.Dir), 0, route.Length)
	return (rel - route.Dir * t).Magnitude
end

local function updateTraffic(dt: number, scale: number, motoPos: Vector3?, motoVel: Vector3, camPos: Vector3)
	local now = os.clock()
	-- O carro NÃO para pela moto: se ela estiver na frente dele, ele acerta. Só espera enquanto o jogador
	-- escolhe uma habilidade, ou quando a Sirene está ligada.
	local waiting = player:GetAttribute("PickingAbility") == true
	local ghost = abilityOn("GhostUntil")
	local sirenRadius = abilityOn("SirenUntil") and AbilityConfig.Get("siren").Radius or 0
	for _, route in ipairs(routes) do
		local cars = route.Cars
		local n = #cars
		local step = route.Speed * dt * scale
		local jammed = route.JamUntil ~= nil and now < route.JamUntil
		local gap = jammed and JAM_GAP or CAR_GAP
		local far = not jammed and routeDistance(route, camPos) > DRAW_DISTANCE + 150 and (not motoPos or routeDistance(route, motoPos) > 150)
		if far then
			for _, car in ipairs(cars) do
				car.S = (car.S + step) % route.Total
				if car.Entry then
					releaseVehicle(car.Entry)
					car.Entry = nil
				end
			end
			continue
		end
		local motoNear = motoPos and routeDistance(route, motoPos) < 60
		for i, car in ipairs(cars) do
			local cf = car.CFrame
			local half = car.Half
			local blocked = car.HoldUntil ~= nil and now < car.HoldUntil
			if n > 1 then
				local ahead = cars[(i % n) + 1]
				if (ahead.S - car.S) % route.Total < gap + half.Z + ahead.Half.Z then
					blocked = true
				end
			end
			local motoDist = motoNear and (motoPos - cf.Position).Magnitude or math.huge
			if motoDist < 50 then
				local rel = cf:PointToObjectSpace(motoPos)
				local inFront = -rel.Z > 0 and -rel.Z < half.Z + STOP_AHEAD and math.abs(rel.X) < 5
				if (waiting and inFront) or motoDist < sirenRadius then
					blocked = true
				end
				if not waiting and not ghost and math.abs(rel.X) < half.X + 1.4 and math.abs(rel.Z) < half.Z + 2
					and math.abs(rel.Y) < 6 and now - lastHit > HIT_COOLDOWN then
					local carSpeed = blocked and 0 or route.Speed * scale
					if -rel.Z > 0 and carSpeed > 2 and carSpeed > motoVel:Dot(cf.LookVector) + 2 then
						-- o carro alcançou a moto (parada, atravessando ou mais lenta): ele acerta e freia um pouco
						lastHit = now
						car.HoldUntil = now + 1.2
						blocked = true
						local away = cf.RightVector * (rel.X >= 0 and 1 or -1)
						MotoSignals.Bump:Fire("car", cf.LookVector * math.clamp(carSpeed * 0.9, 18, 40) + away * 8)
					elseif motoVel:Dot(cf.Position - motoPos) > 1 then
						-- a moto foi contra o carro
						lastHit = now
						MotoSignals.Bump:Fire("car")
					end
				end
			end
			if not blocked then
				car.S = (car.S + step) % route.Total
			end
			-- carro desenhado ou perto da moto: pose todo quadro; longe de tudo: só a cada 4 quadros (decide quando aparece)
			if car.Entry or motoDist < 120 or (frameNo + (car.Id or 0)) % 4 == 0 then
				car.CFrame = poseAt(route, car.S)
			end

			local pos = car.CFrame.Position
			local dist = (pos - camPos).Magnitude
			if dist < DRAW_DISTANCE then
				local fresh = car.Entry == nil
				if fresh then
					car.Entry = acquireVehicle(car.Kind, car.Color, car.Variant)
				end
				if fresh or motoDist < 80 or drawThisFrame(pos, camPos, car.Id or 0) then
					local entry = car.Entry
					local ccf = car.CFrame
					local detail = entry.Detail
					local far = detail ~= nil and dist > MOTO_DETAIL_DISTANCE
					if detail and far ~= entry.Far then
						entry.Far = far
						for i in pairs(detail) do
							entry.Parts[i].LocalTransparencyModifier = far and 1 or 0
						end
					end
					for k, p in ipairs(entry.Parts) do
						if not (far and detail[k]) then
							push(p, ccf * entry.Offsets[k])
						end
					end
				end
			elseif car.Entry and dist > DRAW_DISTANCE + 100 then
				releaseVehicle(car.Entry)
				car.Entry = nil
			end
		end
	end
end

local ballClock = nil -- relógio das bolas (anda mais devagar na Câmera Lenta)
local function updateBalls(dt: number, motoPos: Vector3?, camPos: Vector3)
	ballClock = (ballClock or Workspace:GetServerTimeNow()) + dt
	local t = ballClock
	local now = os.clock()
	for _, b in ipairs(balls) do
		if (b.Pivot - camPos).Magnitude < DRAW_DISTANCE then
			local angle = b.Amplitude * math.sin(2 * math.pi * t / b.Period + b.Phase)
			local pos = b.Pivot + b.Side * (b.Length * math.sin(angle)) - Vector3.yAxis * (b.Length * math.cos(angle))
			push(b.Ball, CFrame.new(pos))
			push(b.Chain, CFrame.lookAt((b.Pivot + pos) / 2, pos))
			if motoPos and now - lastBallHit > 1 and ((motoPos + Vector3.new(0, 2, 0)) - pos).Magnitude < b.Radius + 2.4 then
				lastBallHit = now
				MotoSignals.Bump:Fire("ball")
			end
		end
	end
end

-- pose de caminhada (6 peças); apply = push (em lote) ou atribuir direto
local function posePed(P, cf: CFrame, swing: number, apply)
	apply(P.Torso, cf * CFrame.new(0, 2.9, 0))
	apply(P.Head, cf * CFrame.new(0, 4.35, 0))
	apply(P.LArm, cf * CFrame.new(-1.1, 3.75, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.8, 0))
	apply(P.RArm, cf * CFrame.new(1.1, 3.75, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.8, 0))
	apply(P.LLeg, cf * CFrame.new(-0.4, 2, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0))
	apply(P.RLeg, cf * CFrame.new(0.4, 2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0))
end
local function setDirect(p, cf)
	p.CFrame = cf
end

local knocked = {}
local lastPedHit = 0
local function knockPed(ped, motoVel: Vector3)
	allPeds[ped] = nil
	local list = ped.Rect and blocksWithPeds[ped.Rect.Key]
	local idx = list and table.find(list, ped)
	if idx then
		table.remove(list, idx)
		list.Lost += 1
	end
	local P = ped.Entry.P
	local torso = P.Torso
	for name, part in pairs(P) do
		part.Anchored = false
		part.CanCollide = name == "Torso"
		part.CollisionGroup = "Riders"
		if part ~= torso then
			local w = Instance.new("WeldConstraint")
			w.Name = "RagdollWeld"
			w.Part0 = torso
			w.Part1 = part
			w.Parent = part
		end
	end
	local flat = Vector3.new(motoVel.X, 0, motoVel.Z)
	local dir = flat.Magnitude > 1 and flat.Unit or Vector3.new(0, 0, -1)
	local speed = flat.Magnitude
	torso.AssemblyLinearVelocity = dir * (speed * 0.8 + 12) + Vector3.new(0, 22 + speed * 0.25, 0)
	torso.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-6, 6), math.random(-12, 12))
	local stars = Instance.new("BillboardGui")
	stars.Name = "Tonto"
	stars.Size = UDim2.fromOffset(60, 40)
	stars.StudsOffset = Vector3.new(0, 1.6, 0)
	stars.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = "💫"
	label.Parent = stars
	stars.Adornee = P.Head
	stars.Parent = P.Head
	table.insert(knocked, { Entry = ped.Entry, T = 0, Stars = stars })
end

local function updateKnocked(dt: number)
	for i = #knocked, 1, -1 do
		local k = knocked[i]
		k.T += dt
		if k.T > RAGDOLL_TIME then
			local alpha = math.clamp((k.T - RAGDOLL_TIME) / 0.6, 0, 1)
			for _, part in pairs(k.Entry.P) do
				part.Transparency = alpha
			end
			if alpha >= 1 then
				for _, part in pairs(k.Entry.P) do
					local w = part:FindFirstChild("RagdollWeld")
					if w then
						w:Destroy()
					end
					part.Anchored = true
					part.CanCollide = false
					part.CollisionGroup = "Default"
					part.Transparency = 0
				end
				k.Stars:Destroy()
				k.Entry.Model.Parent = nil
				table.insert(pedPool, k.Entry)
				table.remove(knocked, i)
			end
		end
	end
end

local function updatePeds(dt: number, motoPos: Vector3?, motoVel: Vector3, camPos: Vector3)
	local t = os.clock()
	local canHit = motoPos ~= nil and motoVel.Magnitude > 6 and t - lastPedHit > 0.3
	local sirenRadius = motoPos and abilityOn("SirenUntil") and AbilityConfig.Get("siren").Radius or 0
	for ped in pairs(allPeds) do
		-- Sirene: quem está perto para e espera a moto passar
		local frozen = ped.Pos ~= nil and sirenRadius > 0 and (ped.Pos - motoPos).Magnitude < sirenRadius
		if not frozen then
			ped.S += ped.Speed * dt
		end
		local cf
		if ped.Cross then
			-- atravessando a rua: vai e volta entre as calçadas
			local c = ped.Cross
			local t = ped.S % (2 * c.Length)
			local back = t > c.Length
			local pos = c.A + c.Dir * (back and 2 * c.Length - t or t)
			cf = CFrame.lookAt(pos, pos + c.Dir * (back and -1 or 1))
		else
			cf = ringPose(ped.Rect, ped.S * ped.Dir, ped.Dir)
		end
		ped.Pos = cf.Position
		local swing = frozen and 0 or math.sin(ped.S * 1.6 + ped.Phase) * 0.6
		local P = ped.Entry.P
		local hit = false
		if canHit then
			local d = cf.Position - motoPos
			hit = d.X * d.X + d.Z * d.Z < PED_HIT_RADIUS * PED_HIT_RADIUS and math.abs(d.Y) < 5
		end
		if hit then
			lastPedHit = t
			canHit = false
			posePed(P, cf, swing, setDirect)
			knockPed(ped, motoVel)
			MotoSignals.Bump:Fire("ped")
			Remotes.ReportIncident:FireServer("pedestrian")
		else
			local near = motoPos ~= nil and (cf.Position - motoPos).Magnitude < 60
			ped.Id = ped.Id or math.random(0, 5)
			if not ped.Drawn or near or drawThisFrame(cf.Position, camPos, ped.Id) then
				ped.Drawn = true
				posePed(P, cf, swing, push)
			end
		end
	end
end

local function updateCones(motoPos: Vector3?)
	if not motoPos then
		return
	end
	local now = os.clock()
	for _, spot in ipairs(coneSpots) do
		local dist = (spot.Home.Position - motoPos).Magnitude
		local cone = spot.Cone
		if not cone then
			if dist < CONE_SPAWN_DISTANCE then
				spot.Cone = buildCone(spot.Home)
			end
		elseif dist > CONE_DESPAWN_DISTANCE then
			cone.Model:Destroy()
			spot.Cone = nil
		else
			local root = cone.Root
			if not cone.Knocked then
				if (root.Position - motoPos).Magnitude < 9 and root.AssemblyLinearVelocity.Magnitude > 4 then
					cone.Knocked = true
					cone.KnockedAt = now
					MotoSignals.Bump:Fire("cone")
				end
			elseif now - cone.KnockedAt > CONE_RESET_TIME and dist > 40 then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				cone.Model:PivotTo(spot.Home * CFrame.new(0, 0.15, 0))
				cone.Knocked = false
			end
		end
	end
end

-- Câmera Lenta: cores puxadas para o azul e menos saturadas enquanto dura
local slowLook = Instance.new("ColorCorrectionEffect")
slowLook.Name = "CameraLenta"
slowLook.Enabled = false
slowLook.Parent = game:GetService("Lighting")
local slowK = 0
local function updateSlowLook(dt: number, scale: number)
	local target = scale < 1 and 1 or 0
	if slowK == target and slowLook.Enabled == (target > 0) then
		return -- parado: não mexe em propriedade nenhuma a cada quadro
	end
	local k = slowK + (target - slowK) * math.clamp(dt * 6, 0, 1)
	if math.abs(k - target) < 0.01 then
		k = target
	end
	slowK = k
	slowLook.Enabled = k > 0
	slowLook.Saturation = -0.45 * k
	slowLook.Contrast = 0.08 * k
	slowLook.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 222, 255), k)
end

local slowTimer = 0
local qualityTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local chassis = getChassis()
	local motoPos = chassis and chassis.Position or nil
	local motoVel = chassis and chassis.AssemblyLinearVelocity or Vector3.zero
	local camCF = Workspace.CurrentCamera.CFrame
	local camPos = camCF.Position
	camLook = camCF.LookVector
	frameNo += 1
	local scale = worldScale()
	updateSlowLook(dt, scale)

	checkZones(motoPos)

	table.clear(moveParts)
	table.clear(moveCFrames)
	moveCount = 0
	updateTraffic(dt, scale, motoPos, motoVel, camPos)
	updatePeds(dt * scale, motoPos, motoVel, camPos)
	updateKnocked(dt)
	updateBalls(dt * scale, motoPos, camPos)
	if moveCount > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	slowTimer += dt
	if slowTimer >= 0.25 then
		slowTimer = 0
		updateCones(motoPos)
		refreshPedBlocks(motoPos or camPos)
	end
	qualityTimer -= dt
	if qualityTimer <= 0 then
		qualityTimer = 5
		local low = lowEnd()
		DRAW_DISTANCE = low and 450 or 700
		PED_RADIUS = low and 300 or 450
	end
end)

------------------------------------------------------------------ Sobrevivência: obstáculos no caminho
local hazardTemplates = assetsFolder:WaitForChild("SurvivalHazards", 10)
local HAZARD_KINDS = { { "oil", 0.3 }, { "pothole", 0.3 }, { "mud", 0.25 }, { "spike", 0.15 } }
local dynamicHazards = {}
local crossers = {}

local function clearLegStuff()
	for _, h in ipairs(dynamicHazards) do
		removeZone(h.Zone)
		h.Model:Destroy()
	end
	table.clear(dynamicHazards)
	for _, ped in ipairs(crossers) do
		if allPeds[ped] then -- atropelado já está com o ragdoll
			releasePed(ped)
		end
	end
	table.clear(crossers)
end

local function pickHazard(): string
	local r = math.random()
	for _, k in ipairs(HAZARD_KINDS) do
		r -= k[2]
		if r <= 0 then
			return k[1]
		end
	end
	return "oil"
end

local AXES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }

-- Trecho de rua perto de p (fora de cruzamentos): centro, direção da rua, direção transversal e largura
local function roadSpotNear(p: Vector3)
	local q = Vector3.new(p.X, 0, p.Z)
	if RoadMap.IsOffRoad(q) then
		local found = nil
		for dist = 4, 160, 4 do
			for _, dir in ipairs(AXES) do
				if not RoadMap.IsOffRoad(q + dir * dist) then
					found = q + dir * dist
					break
				end
			end
			if found then
				break
			end
		end
		if not found then
			return nil
		end
		q = found
	end
	local function reach(dir: Vector3): number
		local d = 0
		while d < 60 and not RoadMap.IsOffRoad(q + dir * (d + 2)) do
			d += 2
		end
		return d
	end
	local ax, bx, az, bz = reach(-Vector3.xAxis), reach(Vector3.xAxis), reach(-Vector3.zAxis), reach(Vector3.zAxis)
	local along, across, a, b
	if ax + bx > az + bz then
		along, across, a, b = Vector3.xAxis, Vector3.zAxis, az, bz
	else
		along, across, a, b = Vector3.zAxis, Vector3.xAxis, ax, bx
	end
	local width = a + b
	if width < 16 or width > 50 or math.min(ax + bx, az + bz) >= 60 then
		return nil -- cruzamento ou fora do mapa
	end
	return q + across * ((b - a) / 2), along, across, width
end

-- A rua precisa continuar com uma faixa livre (sem subir na calçada) depois de um perigo novo
local PASSAGE_GAP = 9
local STEER_ROOM = 8
local BLOCKING = { spike = true, oil = true, mud = true, pothole = true, water = true, blocker = true }

local function largestGap(intervals, half: number): number
	table.sort(intervals, function(a, b)
		return a[1] < b[1]
	end)
	local cursor, best = -half + 1, 0
	for _, iv in ipairs(intervals) do
		if iv[1] > cursor then
			best = math.max(best, iv[1] - cursor)
		end
		cursor = math.max(cursor, iv[2])
	end
	return math.max(best, (half - 1) - cursor)
end

local function extent(zone, dir: Vector3): number
	return math.abs(zone.Axis:Dot(dir)) * zone.HalfLength + math.abs(zone.Side:Dot(dir)) * zone.HalfWidth
end

-- center = meio da rua; v = deslocamento lateral do perigo; uh/vh = metade do tamanho ao longo/atravessando
local function keepsPassage(center: Vector3, along: Vector3, across: Vector3, width: number, v: number, uh: number, vh: number): boolean
	local half = width / 2
	local intervals = { { v - vh, v + vh } }
	local reach = Vector3.new(45, 0, 45)
	for _, zone in ipairs(zonesNear(center - reach, center + reach)) do
		if BLOCKING[zone.Kind] then
			local d = Vector3.new(zone.Center.X - center.X, 0, zone.Center.Z - center.Z)
			local zu, zv = d:Dot(along), d:Dot(across)
			local zvh = extent(zone, across)
			if math.abs(zu) <= extent(zone, along) + uh + STEER_ROOM and math.abs(zv) <= half + zvh then
				table.insert(intervals, { zv - zvh, zv + zvh })
			end
		end
	end
	return largestGap(intervals, half) >= PASSAGE_GAP
end

local function spawnHazard(kind: string, pos: Vector3, axis: Vector3)
	local template = hazardTemplates and hazardTemplates:FindFirstChild(kind)
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(CFrame.fromMatrix(pos, axis, Vector3.yAxis))
	model.Parent = fxFolder
	local zone = newZone(kind, pos, axis, template:GetAttribute("HalfLength") or 2, template:GetAttribute("HalfWidth") or 6)
	table.insert(dynamicHazards, { Model = model, Zone = zone })
end

local function spawnCrosser(center: Vector3, across: Vector3, width: number)
	local half = width / 2 + 1.5
	local ped = {
		Entry = acquirePed(), Cross = { A = center - across * half + Vector3.new(0, 0.3, 0), Dir = across, Length = half * 2 },
		S = math.random() * half * 2, Speed = 3.5 + math.random() * 2, Phase = math.random() * 6, Dir = 1,
	}
	allPeds[ped] = true
	table.insert(crossers, ped)
end

------------------------------------------------------------------ Sobrevivência: eventos do pedido (sorteados no servidor)
local function insertCar(route, car)
	local cars = route.Cars
	local at = #cars + 1
	for i, c in ipairs(cars) do
		if c.S > car.S then
			at = i
			break
		end
	end
	table.insert(cars, at, car)
end

local function carNear(route, s: number)
	for _, c in ipairs(route.Cars) do
		local d = math.abs(c.S - s)
		if math.min(d, route.Total - d) < JAM_STEP - 2 then
			return c
		end
	end
	return nil
end

-- Engarrafamento: as duas mãos param no trecho [t - fila, t] da rua. O 1º carro de cada fila segura os
-- de trás e no meio sobra o corredor para a moto. Carros novos da fila só nascem longe da moto.
local function jamRoute(route, t: number, untilClock: number, motoPos: Vector3?)
	local L, arc = route.Length, math.pi * route.Lane
	local queue = math.clamp(math.floor((L - 60) / JAM_STEP), 0, JAM_QUEUE)
	if queue < 3 then
		return
	end
	local span = (queue - 1) * JAM_STEP
	t = math.clamp(t, span + 30, L - 30)
	route.JamUntil = untilClock
	for lane = 1, 2 do
		-- mão A->B: frente da fila em t (a fila volta para A); mão B->A: frente em t - span (a fila volta para B)
		local head = lane == 1 and t or L + arc + (L - (t - span))
		for k = 0, queue - 1 do
			local s = head - k * JAM_STEP
			local existing = carNear(route, s)
			if existing then
				if k == 0 then
					existing.HoldUntil = untilClock
				end
			elseif k == 0 or not motoPos or (poseAt(route, s).Position - motoPos).Magnitude > 120 then
				local car = newCar(route, s, k == 0 and "car" or pickKind(), true)
				if k == 0 then
					car.HoldUntil = untilClock
				end
				insertCar(route, car)
			end
		end
	end
end

-- Para as (até 2) ruas com trânsito que o caminho até o restaurante mais percorre, depois dos 150 studs iniciais
local function jamLeg(from: Vector3, to: Vector3, untilClock: number)
	local points = RoadGraph.Route(RoadGraph.Get(areasFolder, { [SURV.AreaId] = true }), from, to)
	if not points then
		return
	end
	local samples = {}
	local walked = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local len = (b - a).Magnitude
		if len > 0 then
			local dir = (b - a) / len
			for d = 0, len, 15 do
				if walked + d > 150 then
					table.insert(samples, { Pos = a + dir * d, Dir = dir })
				end
			end
		end
		walked += len
	end
	local candidates = {}
	for _, route in ipairs(routes) do
		if route.AreaName == SURVIVAL_AREA then
			local hits = {}
			for _, s in ipairs(samples) do
				if math.abs(s.Dir:Dot(route.Dir)) > 0.9 and routeDistance(route, s.Pos) < 6 then
					table.insert(hits, s.Pos)
				end
			end
			if #hits >= 4 then
				table.insert(candidates, { Route = route, Hits = hits })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return #a.Hits > #b.Hits
	end)
	local chassis = getChassis()
	for i = 1, math.min(2, #candidates) do
		local c = candidates[i]
		local mid = c.Hits[math.ceil(#c.Hits / 2)]
		local t = Vector3.new(mid.X - c.Route.A.X, 0, mid.Z - c.Route.A.Z):Dot(c.Route.Dir)
		jamRoute(c.Route, t + (JAM_QUEUE - 1) * JAM_STEP / 2, untilClock, chassis and chassis.Position)
	end
end

-- Blitz: viatura com giroflex encostada à direita de quem vem (o meio fica livre para a trilha), cones
-- antes dela e placa com o limite. Quem confere a velocidade é o servidor (SurvivalManager); aqui é só o visual.
local BLITZ_RED, BLITZ_BLUE = Color3.fromRGB(255, 40, 50), Color3.fromRGB(40, 110, 255)
local function spawnBlitz(pos: Vector3, dir: Vector3)
	local center = Vector3.new(pos.X, 0, pos.Z)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local right = dir:Cross(Vector3.yAxis)
	local carPos = center + right * 15 -- meio na calçada, sem encostar no trânsito da faixa
	local model = Instance.new("Model")
	model.Name = "Blitz"

	local sedan = assetsFolder:FindFirstChild("Cars") and assetsFolder.Cars:FindFirstChild("Sedan")
	local roof = 4.5
	if sedan then
		local car = sedan:Clone()
		for _, p in ipairs(car:GetDescendants()) do
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(240, 242, 245)
				p.Material = SP
				p.Anchored = true
				p.CanQuery = false
				p.CanTouch = false
			end
		end
		local _, size = car:GetBoundingBox()
		roof = size.Y
		car:PivotTo(CFrame.lookAt(carPos, carPos - dir)) -- de frente para quem vem
		car.Parent = model
	else
		local body = visualPart(model, "Body", Vector3.new(4.6, 3.6, 9.4), Color3.fromRGB(240, 242, 245))
		body.CFrame = CFrame.lookAt(carPos + Vector3.new(0, 1.8, 0), carPos + Vector3.new(0, 1.8, 0) - dir)
		body.CanCollide = true
		roof = 3.6
	end

	local top = CFrame.lookAt(carPos, carPos - dir) * CFrame.new(0, roof + 0.2, 0)
	local base = visualPart(model, "Giroflex", Vector3.new(4.4, 0.3, 1.1), Color3.fromRGB(30, 32, 36))
	base.CFrame = top
	local red = visualPart(model, "Vermelho", Vector3.new(2, 0.55, 1), BLITZ_RED, NEON)
	red.CFrame = top * CFrame.new(-1.05, 0.4, 0)
	local blue = visualPart(model, "Azul", Vector3.new(2, 0.55, 1), BLITZ_BLUE, NEON)
	blue.CFrame = top * CFrame.new(1.05, 0.4, 0)
	local glow = Instance.new("PointLight")
	glow.Range = 26
	glow.Brightness = 3
	glow.Parent = base

	-- placa na calçada, 45 studs antes, de frente para quem vem
	local signPos = center + right * 17.5 - dir * 45
	local pole = visualPart(model, "Poste", Vector3.new(0.35, 5.2, 0.35), Color3.fromRGB(60, 62, 68))
	pole.CFrame = CFrame.new(signPos + Vector3.new(0, 2.6, 0))
	local board = visualPart(model, "Placa", Vector3.new(7, 3.4, 0.3), Color3.fromRGB(22, 24, 29))
	board.CFrame = CFrame.lookAt(signPos + Vector3.new(0, 6.4, 0), signPos + Vector3.new(0, 6.4, 0) - dir)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	for i, line in ipairs({
		{ "BLITZ", Color3.fromRGB(255, 176, 32), Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold) },
		{ string.format("MÁX %d km/h", SURV.Events.BlitzLimitKmh), Color3.fromRGB(245, 246, 247), Font.fromName("BuilderSans", Enum.FontWeight.Bold) },
	}) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0.5)
		label.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		label.TextScaled = true
		label.Text = line[1]
		label.TextColor3 = line[2]
		label.FontFace = line[3]
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.1, 0)
		pad.PaddingBottom = UDim.new(0.1, 0)
		pad.Parent = label
	end

	-- cones no canto da faixa, chegando até a viatura
	for k = 1, 5 do
		local cone = buildCone(CFrame.new(center + right * 12.8 - dir * (3 + k * 6)))
		cone.Model.Parent = model
	end
	model.Parent = fxFolder

	local zone = newZone("blocker", center + right * 14 - dir * 15, dir, 22, 3)
	table.insert(dynamicHazards, { Model = model, Zone = zone })
	task.spawn(function()
		local on = false
		while model.Parent do
			on = not on
			red.Color = on and BLITZ_RED or Color3.fromRGB(70, 14, 18)
			blue.Color = on and Color3.fromRGB(14, 26, 70) or BLITZ_BLUE
			glow.Color = on and BLITZ_RED or BLITZ_BLUE
			task.wait(0.22)
		end
	end)
end

-- A cada trecho do pedido (até o restaurante, depois até o cliente) espalha perigos e travessias pelo caminho
local function spawnLeg(from: Vector3, to: Vector3, event)
	clearLegStuff()
	local keepClear = nil -- nada de perigo em cima da blitz
	if type(event) == "table" and event.Kind == "blitz" and typeof(event.Pos) == "Vector3" and typeof(event.Dir) == "Vector3" then
		spawnBlitz(event.Pos, event.Dir)
		keepClear = Vector3.new(event.Pos.X, 0, event.Pos.Z)
	end
	if level <= 0 then
		return
	end
	local hazards = math.min(SURV.MaxHazards, math.floor(level * SURV.HazardsPerLevel))
	local walkers = math.min(SURV.MaxCrossers, math.floor(level * SURV.CrossersPerLevel))
	-- no máximo 1 coisa a cada "spacing" studs do trecho (encolhe a cada entrega), mantendo a proporção perigos/travessias
	local spacing = math.max(SURV.MinSpacing, SURV.StartSpacing - level * SURV.SpacingPerLevel)
	local room = math.floor(Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude / spacing)
	local total = math.min(hazards + walkers, room)
	local kinds = {}
	local hazardCount = math.floor(total * hazards / math.max(1, hazards + walkers) + 0.5)
	for i = 1, total do
		table.insert(kinds, math.random(1, i), i <= hazardCount and "hazard" or "walker")
	end
	local spots = {}
	local tries = 0
	local minGap = spacing * 0.75
	while #spots < total and tries < total * 8 do
		tries += 1
		local p = from:Lerp(to, 0.1 + math.random() * 0.85) + Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
		local center, along, across, width = roadSpotNear(p)
		if center and (center - Vector3.new(from.X, 0, from.Z)).Magnitude > 70 and (center - Vector3.new(to.X, 0, to.Z)).Magnitude > 30
			and (not keepClear or (center - keepClear).Magnitude > 60) then
			local free = true
			for _, s in ipairs(spots) do
				if (s - center).Magnitude < minGap then
					free = false
					break
				end
			end
			if free then
				if kinds[#spots + 1] == "hazard" then
					-- numa das duas mãos da rua, só se a outra continuar livre (senão tenta a outra mão)
					local kind = pickHazard()
					local template = hazardTemplates and hazardTemplates:FindFirstChild(kind)
					local uh = template and template:GetAttribute("HalfLength") or 3
					local vh = template and template:GetAttribute("HalfWidth") or 7
					local first = math.random() < 0.5 and -1 or 1
					for _, sign in ipairs({ first, -first }) do
						local lane = sign * width / 4
						if keepsPassage(center, along, across, width, lane, uh + 1.4, vh + 0.6) then
							table.insert(spots, center)
							spawnHazard(kind, center + across * lane, along)
							break
						end
					end
				else
					table.insert(spots, center)
					spawnCrosser(center, across, width)
				end
			end
		end
	end
end

local function refreshDifficulty()
	local newLevel = player:GetAttribute("GameMode") == "Survival" and (player:GetAttribute("SurvivalLevel") or 0) or 0
	if newLevel == level then
		return
	end
	level = newLevel
	local chassis = getChassis()
	local avoid = chassis and chassis.Position or Workspace.CurrentCamera.CFrame.Position
	for _, route in ipairs(routes) do
		applyRouteDifficulty(route, avoid)
	end
	if level == 0 then
		clearLegStuff()
	end
end
player:GetAttributeChangedSignal("SurvivalLevel"):Connect(refreshDifficulty)
player:GetAttributeChangedSignal("GameMode"):Connect(refreshDifficulty)
refreshDifficulty()

Remotes.OrderAccepted.OnClientEvent:Connect(function(order)
	if order.Survival then
		local chassis = getChassis()
		local from = chassis and chassis.Position or order.RestaurantPosition
		spawnLeg(from, order.RestaurantPosition)
		local ev = order.Event
		if type(ev) == "table" and ev.Kind == "jam" and type(ev.Until) == "number" then
			jamLeg(from, order.RestaurantPosition, os.clock() + math.max(0, ev.Until - Workspace:GetServerTimeNow()))
		end
	end
end)
Remotes.OrderPickedUp.OnClientEvent:Connect(function(order)
	if order.Survival then
		spawnLeg(order.RestaurantPosition, order.CustomerPosition, order.Event)
	end
end)
