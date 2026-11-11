-- Obstáculos das ruas. Cada função recebe um trecho entre dois cruzamentos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.Helpers)
local D = require(script.Parent.Data)

local WATER_TEX = "rbxasset://textures/particles/smoke_main.dds"
local POTHOLE_TEX = "rbxassetid://113658663771953" -- buraco desenhado (o furo ocupa ~59% da imagem)

local SP = H.SP
local LANE = D.ROAD_W / 4
local KMH = 2
local Obstacles = {}

local function segFrame(seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	return CFrame.fromMatrix(seg.Center, side, Vector3.yAxis, -seg.Axis)
end

-- quanto dá para deslocar algo ao longo do trecho sem invadir o cruzamento
local function freeAlong(seg, margin: number): number
	return math.max(0, (seg.Length or 160) / 2 - D.ROAD_W / 2 - (margin or 10))
end

local function hazardData(folder, kind: string, center: Vector3, axis: Vector3, halfLength: number, halfWidth: number)
	local data = Instance.new("Folder")
	data.Name = "Hazard"
	data:SetAttribute("Type", kind)
	data:SetAttribute("Center", Vector3.new(center.X, 0, center.Z))
	data:SetAttribute("Axis", axis)
	data:SetAttribute("HalfLength", halfLength)
	data:SetAttribute("HalfWidth", halfWidth)
	data.Parent = folder
	return data
end

local function flatDisc(parent, name, pos, diameter, y, color, material, transparency)
	local disc = H.deco(parent, name, Vector3.new(0.06, diameter, diameter), CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = transparency or 0
	return disc
end

-- OBRA: fecha UMA faixa (a outra fica livre para passar sem subir na calçada)
function Obstacles.Obra(folder, seg)
	local m = Instance.new("Model")
	m.Name = "Obra"
	local base = segFrame(seg)
	local s = (H.rng:NextNumber() < 0.5) and -1 or 1
	local laneX = s * LANE
	local LW = D.ROAD_W / 2
	for _, z in ipairs({ -14, 14 }) do
		local cf = base * CFrame.new(laneX, 1.7, z)
		H.block(m, "Barreira", Vector3.new(LW - 1, 3.4, 1.2), cf, H.ORANGE, SP, true)
		for k = -1, 1 do
			H.deco(m, "Faixa", Vector3.new(1.8, 3.45, 1.25), cf * CFrame.new(k * LW / 4, 0, 0), H.WHITE, SP)
		end
		for _, x in ipairs({ -LW / 2 + 1.2, LW / 2 - 1.2 }) do
			H.deco(m, "Luz", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(x, 2.1, 0), H.YELLOW, Enum.Material.Neon)
		end
		local board = H.deco(m, "Placa", Vector3.new(8, 2.6, 0.3), cf * CFrame.new(0, 3.4, 0), H.YELLOW, SP)
		H.surfaceText(board, Enum.NormalId.Front, "OBRAS", Color3.fromRGB(20, 20, 20))
		H.surfaceText(board, Enum.NormalId.Back, "OBRAS", Color3.fromRGB(20, 20, 20))
	end
	-- dentro da faixa fechada: monte de areia e escavadeira
	local sand = H.block(m, "Areia", Vector3.new(9, 4, 9), base * CFrame.new(laneX, 1.6, 6), Color3.fromRGB(205, 175, 115), Enum.Material.Sand, true)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = sand
	local ex = base * CFrame.new(laneX, 0, -5)
	H.block(m, "Esteira", Vector3.new(1.5, 1.5, 7), ex * CFrame.new(-2, 0.75, 0), H.DARKGRAY, Enum.Material.Metal, true)
	H.block(m, "Esteira", Vector3.new(1.5, 1.5, 7), ex * CFrame.new(2, 0.75, 0), H.DARKGRAY, Enum.Material.Metal, true)
	H.block(m, "Corpo", Vector3.new(5, 2.4, 5.4), ex * CFrame.new(0, 2.7, 0.4), H.YELLOW, SP, true)
	H.block(m, "Cabine", Vector3.new(3, 2.8, 3), ex * CFrame.new(-0.7, 5.3, 1), H.YELLOW, SP, true)
	H.deco(m, "Braco", Vector3.new(0.9, 0.9, 7), ex * CFrame.new(1.2, 4.7, -3.2) * CFrame.Angles(math.rad(25), 0, 0), H.YELLOW, SP)
	-- cones em diagonal estreitando a pista antes da obra, nos dois sentidos
	for _, dir in ipairs({ -1, 1 }) do
		for i, def in ipairs({ { 13.5, 28 }, { 9, 23 }, { 4.5, 18.5 } }) do
			local p = base * CFrame.new(s * def[1], 0, dir * def[2])
			H.staticCone(m, p.Position)
		end
	end
	m.Parent = folder
end

-- DESVIO: fecha uma faixa
function Obstacles.Desvio(folder, seg)
	local m = Instance.new("Model")
	m.Name = "Desvio"
	local base = segFrame(seg)
	local lane = ((H.rng:NextNumber() < 0.5) and -1 or 1) * LANE
	for _, z in ipairs({ -4, 4 }) do
		local cf = base * CFrame.new(lane, 1.5, z)
		H.block(m, "Cavalete", Vector3.new(D.ROAD_W / 2 - 0.5, 3, 1), cf, H.WHITE, SP, true)
		for x = -1, 1 do
			H.deco(m, "Faixa", Vector3.new(2, 3.05, 1.05), cf * CFrame.new(x * LANE / 2, 0, 0), H.RED, SP)
		end
	end
	local board = H.deco(m, "Placa", Vector3.new(7, 2.4, 0.3), base * CFrame.new(lane, 4.2, -4), H.YELLOW, SP)
	H.surfaceText(board, Enum.NormalId.Front, "⚠️ DESVIO", Color3.fromRGB(20, 20, 20))
	H.surfaceText(board, Enum.NormalId.Back, "⚠️ DESVIO", Color3.fromRGB(20, 20, 20))
	for i = 1, 3 do
		local x = lane * (0.3 + i * 0.25)
		H.staticCone(m, (base * CFrame.new(x, 0, -8 - i * 5)).Position)
		H.staticCone(m, (base * CFrame.new(x, 0, 8 + i * 5)).Position)
	end
	m.Parent = folder
end

-- RAMPAS DE SALTO: uma por faixa, subindo no sentido da mão
function Obstacles.Rampa(folder, seg)
	local m = Instance.new("Model")
	m.Name = "Rampa"
	local side = seg.Axis:Cross(Vector3.yAxis)
	local len, h, w = 16, 5, 11
	local sink = 0.3
	for _, s in ipairs({ 1, -1 }) do
		local travel = seg.Axis * s
		local pos = seg.Center + side * s * LANE + travel * -10 + Vector3.new(0, h / 2 - sink, 0)
		H.block(m, "Rampa", Vector3.new(w, h, len), CFrame.lookAt(pos, pos - travel), H.YELLOW, Enum.Material.DiamondPlate, true, "WedgePart")
		local back = pos + travel * (len / 2 + 0.06)
		H.deco(m, "Traseira", Vector3.new(w, h, 0.1), CFrame.lookAt(back, back + travel), H.DARKGRAY, SP)
		for k = -1, 1 do
			local stripePos = pos + side * k * 3.5 - travel * (len / 2 + 4) + Vector3.new(0, -h / 2 + sink + 0.25, 0)
			H.deco(m, "Seta", Vector3.new(1.2, 0.1, 3.5), CFrame.lookAt(stripePos, stripePos + travel), H.WHITE, SP)
		end
	end
	m.Parent = folder
end

-- CONES (físicos no cliente)
function Obstacles.Cones(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local group = Instance.new("Folder")
	group.Name = "ConeGroup"
	local spacing = math.min(14, freeAlong(seg, 6) / 2)
	for k = -2, 2 do
		local offset = (k % 2 == 0) and LANE * 0.6 or -LANE * 0.6
		local p = seg.Center + seg.Axis * (k * spacing) + side * offset
		group:SetAttribute("P" .. (k + 3), Vector3.new(p.X, 0, p.Z))
	end
	group.Parent = folder
end

-- CARRO parado na faixa
function Obstacles.Carro(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local s = (H.rng:NextNumber() < 0.5) and -1 or 1
	local free = freeAlong(seg, 8)
	local pos = seg.Center + side * s * LANE + seg.Axis * H.rng:NextNumber(-free, free)
	local forward = (s == 1) and seg.Axis or -seg.Axis
	H.car(folder, CFrame.lookAt(pos, pos + forward), H.pick(H.CAR_COLORS), true)
end

-- Visual da tira de pregos: tapete de borracha, bordas amarelas e duas fileiras de dentes de metal
function Obstacles.VisualEspinhos(m, center: Vector3, axis: Vector3, halfWidth: number)
	local side = axis:Cross(Vector3.yAxis)
	local base = CFrame.fromMatrix(Vector3.new(center.X, 0, center.Z), side, Vector3.yAxis, -axis)
	local W = halfWidth * 2
	H.deco(m, "Tira", Vector3.new(W, 0.24, 3.2), base * CFrame.new(0, 0.32, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber)
	for _, z in ipairs({ -1.45, 1.45 }) do
		H.deco(m, "Faixa", Vector3.new(W, 0.27, 0.3), base * CFrame.new(0, 0.33, z), H.YELLOW, SP)
	end
	Obstacles.DentesEspinhos(m, base, halfWidth)
end

-- Pontas de aço: cada uma são 2 cunhas costas com costas, com o triângulo virado para quem chega
function Obstacles.DentesEspinhos(m, base: CFrame, halfWidth: number)
	local h, half = 0.75, 0.3
	local teeth = math.floor((halfWidth * 2 - 1.2) / 2) + 1
	for k = 0, teeth - 1 do
		local x = -halfWidth + 0.6 + k * 2
		for r, z in ipairs({ -0.62, 0.62 }) do
			local c = base * CFrame.new(x + (r == 2 and 1 or 0), 0.44 + h / 2, z)
			for _, sgn in ipairs({ -1, 1 }) do
				local back = c.RightVector * sgn
				local p = c.Position - back * (half / 2)
				H.deco(m, "Dente", Vector3.new(0.22, h, half), CFrame.lookAt(p, p - back), Color3.fromRGB(176, 182, 192), Enum.Material.SmoothPlastic, "WedgePart")
			end
		end
	end
end

-- ESPINHOS: fura o pneu (Folder "SpikeStrip"). Sempre numa faixa só: dá para desviar pela outra.
function Obstacles.Espinhos(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local halfWidth = D.ROAD_W / 4 + 1
	local free = freeAlong(seg, 6)
	local along = seg.Axis * H.rng:NextNumber(-math.min(30, free), math.min(30, free))
	local center = seg.Center + side * (((H.rng:NextNumber() < 0.5) and -1 or 1) * LANE) + along
	local m = Instance.new("Model")
	m.Name = "Espinhos"
	Obstacles.VisualEspinhos(m, center, seg.Axis, halfWidth)
	m.Parent = folder
	local data = Instance.new("Folder")
	data.Name = "SpikeStrip"
	data:SetAttribute("Center", Vector3.new(center.X, 0, center.Z))
	data:SetAttribute("Axis", seg.Axis)
	data:SetAttribute("HalfLength", 2)
	data:SetAttribute("HalfWidth", halfWidth)
	data.Parent = folder
end

-- Visual do óleo: manchas brilhantes, reflexo furta-cor e um tambor caído vazando na beira da faixa
function Obstacles.VisualOleo(m, center: Vector3, axis: Vector3, sideSign: number)
	local side = axis:Cross(Vector3.yAxis)
	for k, def in ipairs({ { 0, 0, 12 }, { 3.5, 2.5, 7 }, { -3, -2.5, 6 }, { sideSign * 5, 3.5, 4 } }) do
		local disc = flatDisc(m, "Mancha", center + side * def[1] + axis * def[2], def[3], 0.23 + k * 0.02, Color3.fromRGB(14, 13, 16), Enum.Material.Rubber)
		disc.Reflectance = 0
	end
	local sheen = flatDisc(m, "Brilho", center + side * 1.2 - axis * 1, 4, 0.33, Color3.fromRGB(104, 66, 118), Enum.Material.Rubber, 0.72)
	local bp = center + side * sideSign * 6.8 + axis * 4.5
	local barrel = H.deco(m, "Tambor", Vector3.new(3.2, 2.3, 2.3), CFrame.fromMatrix(Vector3.new(bp.X, 1.15, bp.Z), side, Vector3.yAxis), Color3.fromRGB(30, 90, 170), Enum.Material.Metal)
	barrel.Shape = Enum.PartType.Cylinder
	for _, x in ipairs({ -0.9, 0.9 }) do
		local ring = H.deco(m, "Aro", Vector3.new(0.22, 2.42, 2.42), barrel.CFrame * CFrame.new(x, 0, 0), Color3.fromRGB(22, 60, 120), Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
	end
end

-- ÓLEO: derrapagem
function Obstacles.Oleo(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local s = (H.rng:NextNumber() < 0.5) and -1 or 1
	local free = math.min(35, freeAlong(seg, 8))
	local center = seg.Center + side * s * LANE + seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Oleo"
	Obstacles.VisualOleo(m, center, seg.Axis, s)
	m.Parent = folder
	hazardData(folder, "oil", center, seg.Axis, 6.5, 6.5)
end

-- Visual do buraco: decalque plano (sem lateral, não parece tampa) girado ao acaso + pedaços soltos em 3D
function Obstacles.VisualBuraco(m, center: Vector3, size: number, rng)
	local w = size / 0.59
	local plate = H.deco(m, "Buraco", Vector3.new(w, 0.05, w), CFrame.new(center.X, 0.24, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), H.WHITE, SP)
	plate.Transparency = 1 -- topo 0.265: acima da faixa central (0.245)
	local decal = Instance.new("Decal")
	decal.Texture = POTHOLE_TEX
	decal.Face = Enum.NormalId.Top
	decal.Parent = plate
	for _ = 1, 2 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (size / 2 + rng:NextNumber(0.6, 1.8))
		H.deco(m, "Pedaco", Vector3.new(rng:NextNumber(0.4, 0.8), 0.25, rng:NextNumber(0.4, 0.8)),
			CFrame.new(p.X, 0.33, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(58, 58, 64), Enum.Material.Asphalt)
	end
end

-- BURACOS
function Obstacles.Buraco(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local free = math.min(45, freeAlong(seg, 6))
	for _ = 1, H.rng:NextInteger(1, 3) do
		local center = seg.Center + side * H.rng:NextNumber(-D.ROAD_W / 2 + 4, D.ROAD_W / 2 - 4) + seg.Axis * H.rng:NextNumber(-free, free)
		local m = Instance.new("Model")
		m.Name = "Buraco"
		local size = H.rng:NextNumber(4, 6)
		Obstacles.VisualBuraco(m, center, size, H.rng)
		m.Parent = folder
		hazardData(folder, "pothole", center, seg.Axis, size / 2, size / 2)
	end
end

-- Triângulos brancos pintados nas duas aproximações, apontando para a lombada (cada um = 2 cunhas espelhadas)
function Obstacles.PinturaLombada(m, center: Vector3, axis: Vector3)
	local side = axis:Cross(Vector3.yAxis)
	local a, b = 1.2, 2.4 -- meia base e altura do triângulo
	for _, dir in ipairs({ -1, 1 }) do
		local u = -axis * dir
		for _, x in ipairs({ -10, -4, 4, 10 }) do
			local base = center + side * x + axis * dir * 7.4
			for _, sgn in ipairs({ -1, 1 }) do
				local s = side * sgn
				local zv = -s
				local p = base + u * (b / 2) + s * (a / 2)
				local cf = CFrame.fromMatrix(Vector3.new(p.X, 0.25, p.Z), u:Cross(zv), u, zv)
				H.deco(m, "Pintura", Vector3.new(0.05, b, a), cf, H.WHITE, SP, "WedgePart")
			end
		end
	end
end

-- Visual da lombada: faixa amarela e preta, setas pintadas no asfalto antes dela e placa "LOMBADA"
function Obstacles.VisualLombada(m, center: Vector3, axis: Vector3)
	local side = axis:Cross(Vector3.yAxis)
	local pieces = 8
	local pw = D.ROAD_W / pieces
	for k = 0, pieces - 1 do
		local x = -D.ROAD_W / 2 + pw * (k + 0.5)
		local p = center + side * x
		local bump = H.deco(m, "Lombada", Vector3.new(pw, 2.4, 2.4), CFrame.fromMatrix(Vector3.new(p.X, -0.55, p.Z), side, Vector3.yAxis, -axis),
			(k % 2 == 0) and H.YELLOW or Color3.fromRGB(30, 30, 30), SP)
		bump.Shape = Enum.PartType.Cylinder
	end
	Obstacles.PinturaLombada(m, center, axis)
	local signPos = center + side * (D.ROAD_W / 2 + 2) - axis * 12
	H.cylV(m, "Poste", CFrame.new(signPos.X, 0.3, signPos.Z), 7, 0.3, H.DARKGRAY, Enum.Material.Metal, false)
	local at = Vector3.new(signPos.X, 7.6, signPos.Z)
	local board = H.deco(m, "Placa", Vector3.new(4.4, 1.8, 0.2), CFrame.lookAt(at, at - axis), H.YELLOW, SP)
	H.surfaceText(board, Enum.NormalId.Front, "LOMBADA", Color3.fromRGB(20, 20, 20))
end

-- LOMBADA: atravessa a rua; devagar não acontece nada, rápido dá tranco e pulo
function Obstacles.Lombada(folder, seg)
	local free = math.min(30, freeAlong(seg, 10))
	local center = seg.Center + seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Lombada"
	Obstacles.VisualLombada(m, center, seg.Axis)
	m.Parent = folder
	hazardData(folder, "bump", center, seg.Axis, 1.6, D.ROAD_W / 2)
end

-- Visual da lama: poças em tons de marrom (centro mais escuro) e torrões espalhados
function Obstacles.VisualLama(m, center: Vector3, axis: Vector3, rng)
	local side = axis:Cross(Vector3.yAxis)
	local tones = { Color3.fromRGB(104, 76, 48), Color3.fromRGB(92, 66, 42), Color3.fromRGB(80, 57, 36), Color3.fromRGB(66, 47, 30) }
	for k, def in ipairs({ { 0, 0, 14 }, { 4, 3, 9 }, { -4, -3, 8 }, { 1, -1, 6 } }) do
		flatDisc(m, "Lama", center + side * def[1] + axis * def[2], def[3], 0.23 + k * 0.02, tones[k], Enum.Material.Mud)
	end
	for _ = 1, 5 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(6.5, 8.5)
		H.ellipsoid(m, "Torrao", CFrame.new(p.X, 0.32, p.Z), Vector3.new(rng:NextNumber(0.7, 1.4), 0.35, rng:NextNumber(0.7, 1.4)), Color3.fromRGB(86, 62, 40), Enum.Material.Mud)
	end
end

-- LAMA: a moto atola e perde velocidade
function Obstacles.Lama(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local s = (H.rng:NextNumber() < 0.5) and -1 or 1
	local free = math.min(35, freeAlong(seg, 8))
	local center = seg.Center + side * s * LANE + seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Lama"
	Obstacles.VisualLama(m, center, seg.Axis, H.rng)
	m.Parent = folder
	hazardData(folder, "mud", center, seg.Axis, 7, 7)
end

-- Hidrante (modelo 3D de Assets/Hidrante; sem ele, peças simples). pos = base na calçada.
function Obstacles.HydrantModel(parent, pos: Vector3, facing: Vector3)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = assets and assets:FindFirstChild("Hidrante")
	if asset then
		local m = asset:Clone()
		m.Name = "HidranteModelo"
		m:PivotTo(CFrame.lookAt(pos, pos + facing))
		m.Parent = parent
		return m
	end
	H.cylV(parent, "Hidrante", CFrame.new(pos), 3, 1.4, H.RED, SP, false)
	H.ball(parent, "Tampa", CFrame.new(pos + Vector3.new(0, 3.1, 0)), 1.5, H.RED, SP, false)
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- HIDRANTE ESTOURADO: o bocal quebrou e a água sai em arco até a faixa (névoa + respingos na poça)
function Obstacles.Hidrante(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local s = (H.rng:NextNumber() < 0.5) and -1 or 1
	local free = math.min(30, freeAlong(seg, 8))
	local along = seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Hidrante"
	local hp = seg.Center + side * s * (D.ROAD_W / 2 + 1.5) + along
	local toRoad = -side * s
	Obstacles.HydrantModel(m, Vector3.new(hp.X, 0.3, hp.Z), toRoad)
	local dir = (toRoad * 0.85 + Vector3.yAxis * 0.55).Unit
	local origin = H.deco(m, "JatoOrigem", Vector3.new(0.5, 0.5, 0.5), CFrame.fromMatrix(Vector3.new(hp.X, 2.5, hp.Z) + toRoad * 0.8, seg.Axis, dir), H.WHITE, SP)
	origin.Transparency = 1
	emitter(origin, "Jato", {
		Texture = WATER_TEX, Rate = 220, Lifetime = NumberRange.new(0.65, 0.9), Speed = NumberRange.new(18, 23),
		SpreadAngle = Vector2.new(5, 9), Acceleration = Vector3.new(0, -42, 0), Drag = 0.3, EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(225, 242, 255)), LightEmission = 0.2,
	})
	emitter(origin, "Nevoa", {
		Texture = WATER_TEX, Rate = 22, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -4, 0), EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(240, 248, 255)),
	})
	local center = seg.Center + side * s * LANE + along
	local splash = H.deco(m, "Respingo", Vector3.new(7, 0.2, 7), CFrame.new(center.X, 0.35, center.Z), H.WHITE, SP)
	splash.Transparency = 1
	emitter(splash, "Respingos", {
		Texture = WATER_TEX, Rate = 70, Lifetime = NumberRange.new(0.3, 0.55), Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(55, 55), Acceleration = Vector3.new(0, -40, 0), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(225, 242, 255)),
	})
	for k, def in ipairs({ { 0, 0, 13 }, { -3, 4, 8 }, { 3, -4, 7 } }) do
		local disc = flatDisc(m, "Agua", center + side * def[1] + seg.Axis * def[2], def[3], 0.24 + k * 0.01, Color3.fromRGB(110, 170, 230), Enum.Material.Glass, 0.3)
		disc.Reflectance = 0.3
	end
	m.Parent = folder
	hazardData(folder, "water", center, seg.Axis, 6.5, 6.5)
end

-- RADAR: passar acima do limite = multa (cobrada no servidor)
function Obstacles.Radar(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local limit = H.pick({ 45, 55, 65 })
	local free = math.min(20, freeAlong(seg, 12))
	local center = seg.Center + seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Radar"
	for _, s in ipairs({ 1, -1 }) do
		local p = center + side * s * (D.ROAD_W / 2 + 2)
		H.cylV(m, "Poste", CFrame.new(p.X, 0.3, p.Z), 9, 0.5, Color3.fromRGB(230, 230, 235), Enum.Material.Metal, false)
		local facing = -seg.Axis * s
		local boxPos = Vector3.new(p.X, 9.5, p.Z)
		H.deco(m, "Camera", Vector3.new(1.4, 1.2, 2.2), CFrame.lookAt(boxPos, boxPos + facing), Color3.fromRGB(40, 40, 45), SP)
		H.deco(m, "Flash", Vector3.new(0.6, 0.6, 0.1), CFrame.lookAt(boxPos + facing * 1.12, boxPos + facing * 2), Color3.fromRGB(255, 230, 150), Enum.Material.Neon)
		local signPos = Vector3.new(p.X, 6.4, p.Z) + facing * 0.4
		local sign = H.deco(m, "Placa", Vector3.new(3.4, 3.4, 0.2), CFrame.lookAt(signPos, signPos + facing), H.WHITE, SP)
		H.surfaceText(sign, Enum.NormalId.Front, "📸\n" .. (limit * KMH), H.RED)
	end
	H.deco(m, "Faixa", Vector3.new(D.ROAD_W, 0.05, 0.6), CFrame.fromMatrix(Vector3.new(center.X, 0.24, center.Z), side, Vector3.yAxis, -seg.Axis), H.WHITE, SP)
	m.Parent = folder
	local data = hazardData(folder, "radar", center, seg.Axis, 2.5, D.ROAD_W / 2)
	data:SetAttribute("Limit", limit)
end

-- BOLA DE DEMOLIÇÃO: guindaste com bola balançando de um lado ao outro da rua (animada no cliente)
function Obstacles.Bola(folder, seg)
	local side = seg.Axis:Cross(Vector3.yAxis)
	local free = math.min(20, freeAlong(seg, 14))
	local center = seg.Center + seg.Axis * H.rng:NextNumber(-free, free)
	local m = Instance.new("Model")
	m.Name = "Bola"
	local pivotY = 27
	for _, s in ipairs({ 1, -1 }) do
		local p = center + side * s * (D.ROAD_W / 2 + 3)
		H.block(m, "Torre", Vector3.new(2, pivotY + 2, 2), CFrame.new(p.X, (pivotY + 2) / 2, p.Z), H.YELLOW, Enum.Material.DiamondPlate, true)
		local board = H.deco(m, "Placa", Vector3.new(5, 2, 0.2), CFrame.lookAt(Vector3.new(p.X, 6, p.Z) - seg.Axis * 1.1, Vector3.new(p.X, 6, p.Z) - seg.Axis * 2), H.YELLOW, SP)
		H.surfaceText(board, Enum.NormalId.Front, "⚠️ DEMOLIÇÃO", Color3.fromRGB(20, 20, 20))
	end
	local beam = CFrame.fromMatrix(Vector3.new(center.X, pivotY + 1.5, center.Z), side, Vector3.yAxis, -seg.Axis)
	H.deco(m, "Viga", Vector3.new(D.ROAD_W + 10, 1.6, 1.6), beam, H.YELLOW, Enum.Material.DiamondPlate)
	m.Parent = folder
	local data = Instance.new("Folder")
	data.Name = "WreckingBall"
	data:SetAttribute("Pivot", Vector3.new(center.X, pivotY, center.Z))
	data:SetAttribute("Side", side)
	data:SetAttribute("Length", pivotY - 5)
	data:SetAttribute("Radius", 3.6)
	data:SetAttribute("Amplitude", math.rad(48))
	data:SetAttribute("Period", H.rng:NextNumber(2.8, 3.8))
	data:SetAttribute("Phase", H.rng:NextNumber(0, 6.28))
	data.Parent = folder
end

function Obstacles.Beco(folder, center: Vector3, axis: Vector3, length: number)
	local side = axis:Cross(Vector3.yAxis)
	local m = Instance.new("Model")
	m.Name = "Beco"
	local half = length / 2 - 12
	local count = math.clamp(math.floor(length / 45), 1, 3)
	for k = 1, count do
		local t = -half + (2 * half) * (k - 0.5) / count
		local s = (k % 2 == 0) and 1 or -1
		local p = center + axis * t + side * s * (D.ALLEY_W / 2 - 2)
		local cf = CFrame.fromMatrix(Vector3.new(p.X, 1.8, p.Z), side, Vector3.yAxis, -axis)
		H.block(m, "Cacamba", Vector3.new(3.4, 3.6, 6), cf, Color3.fromRGB(40, 110, 60), Enum.Material.Metal, true)
		H.deco(m, "Tampa", Vector3.new(3.6, 0.3, 6.2), cf * CFrame.new(0, 1.9, 0), Color3.fromRGB(30, 80, 45), Enum.Material.Metal)
		for j = 1, 2 do
			H.ball(m, "Lixo", CFrame.new(p + axis * (4 + j * 1.6) + Vector3.new(0, 0.9, 0)), 1.8, Color3.fromRGB(25, 25, 28), SP, false)
		end
	end
	m.Parent = folder
	if H.rng:NextNumber() < 0.5 then
		local pos = center + axis * H.rng:NextNumber(-half * 0.5, half * 0.5)
		flatDisc(m, "Poca", pos, 8, 0.24, Color3.fromRGB(95, 70, 45), Enum.Material.Ground)
		hazardData(folder, "mud", pos, axis, 4, D.ALLEY_W / 2)
	end
end

-- ROTA DE TRÂNSITO
function Obstacles.TrafficRoute(folder, a: Vector3, b: Vector3)
	local route = Instance.new("Folder")
	route.Name = "Route"
	route:SetAttribute("A", a)
	route:SetAttribute("B", b)
	route:SetAttribute("Cars", D.TRAFFIC_CARS_PER_ROUTE)
	route:SetAttribute("Speed", H.rng:NextInteger(D.TRAFFIC_SPEED_MIN or D.TRAFFIC_SPEED, D.TRAFFIC_SPEED_MAX or D.TRAFFIC_SPEED))
	route:SetAttribute("Lane", LANE)
	route.Parent = folder
end

return Obstacles
