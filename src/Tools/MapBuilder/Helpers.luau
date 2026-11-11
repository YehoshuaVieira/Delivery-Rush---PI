-- Funções de construção de peças usadas pelo MapBuilder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local H = {}

H.RED = Color3.fromRGB(234, 29, 44)
H.WHITE = Color3.fromRGB(248, 248, 248)
H.ORANGE = Color3.fromRGB(255, 120, 20)
H.YELLOW = Color3.fromRGB(255, 200, 40)
H.DARKGRAY = Color3.fromRGB(45, 45, 50)
H.GLASS = Color3.fromRGB(165, 205, 230)
H.BLUE = Color3.fromRGB(0, 150, 255)
H.PAD_ORANGE = Color3.fromRGB(255, 140, 0)
H.SP = Enum.Material.SmoothPlastic
H.CAR_COLORS = {
	Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 90, 200), Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(30, 30, 30), Color3.fromRGB(240, 200, 40), Color3.fromRGB(60, 160, 90),
}

H.PAD_OFFSET = 36

H.rng = Random.new(1)
function H.SetSeed(seed: number)
	H.rng = Random.new(seed)
end
function H.pick(list)
	return list[H.rng:NextInteger(1, #list)]
end
function H.shuffle(list)
	for i = #list, 2, -1 do
		local j = H.rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

function H.folder(name: string, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Peça ancorada. collide=true => colide e pode ser detectada por raycast; false => só visual.
function H.block(parent, name, size, cf, color, material, collide, className)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or H.SP
	p.CanCollide = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if not p.CanCollide then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

function H.deco(parent, name, size, cf, color, material, className)
	return H.block(parent, name, size, cf, color, material, false, className)
end

-- Cilindro em pé com a BASE em baseCF
function H.cylV(parent, name, baseCF, height, diameter, color, material, collide)
	local p = H.block(parent, name, Vector3.new(height, diameter, diameter),
		baseCF * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Elipsóide visual (Part + SpecialMesh esfera, aceita tamanhos diferentes por eixo)
function H.ellipsoid(parent, name, cf, size, color, material)
	local p = H.deco(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function H.ball(parent, name, cf, diameter, color, material, collide)
	local p = H.block(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material, collide)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Caixa apoiada no chão (ou em yBase), com a frente virada para dir
function H.box(parent, name, groundPos, dir, w, h, d, color, material, yBase)
	local c = Vector3.new(groundPos.X, (yBase or 0) + h / 2, groundPos.Z)
	return H.block(parent, name, Vector3.new(w, h, d), CFrame.lookAt(c, c + dir), color, material, true)
end

-- Faixas de janelas em volta do prédio (1 peça por andar, um pouco maior que o prédio)
function H.bands(parent, groundPos, dir, w, d, h, color, spacing, startY, material)
	for y = startY, h - 3, spacing do
		local c = Vector3.new(groundPos.X, y, groundPos.Z)
		H.deco(parent, "Windows", Vector3.new(w + 0.3, 1.8, d + 0.3), CFrame.lookAt(c, c + dir), color, material or Enum.Material.Glass)
	end
end

-- Telhado de 2 águas com TELHA DE BARRO, beiral e cumeeira (cumeeira paralela à fachada)
function H.gableRoof(parent, groundPos, dir, w, d, baseY, rh, color, overhang)
	overhang = overhang or 1.2
	local c = Vector3.new(groundPos.X, baseY + rh / 2, groundPos.Z)
	local cf = CFrame.lookAt(c, c + dir)
	local half = d / 2 + overhang
	H.block(parent, "Roof", Vector3.new(w + overhang * 2, rh, half), cf * CFrame.new(0, 0, -half / 2), color, Enum.Material.ClayRoofTiles, true, "WedgePart")
	H.block(parent, "Roof", Vector3.new(w + overhang * 2, rh, half), cf * CFrame.new(0, 0, half / 2) * CFrame.Angles(0, math.pi, 0), color, Enum.Material.ClayRoofTiles, true, "WedgePart")
	H.deco(parent, "Cumeeira", Vector3.new(w + overhang * 2, 0.5, 1), cf * CFrame.new(0, rh / 2 + 0.05, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.ClayRoofTiles)
end

-- Árvore: tronco + copa em 2 volumes com tons diferentes (mais orgânica)
function H.tree(parent, pos, scale)
	scale = scale or 1
	local trunk = H.block(parent, "Trunk", Vector3.new(6 * scale, 1.2 * scale, 1.2 * scale),
		CFrame.new(pos + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(105, 78, 52), Enum.Material.Wood, true)
	trunk.Shape = Enum.PartType.Cylinder
	local base = Color3.fromRGB(62 + H.rng:NextInteger(-12, 12), 128 + H.rng:NextInteger(-18, 18), 52 + H.rng:NextInteger(-8, 8))
	H.ellipsoid(parent, "Leaves", CFrame.new(pos + Vector3.new(0, 8 * scale, 0)), Vector3.new(9, 7, 9) * scale, base, Enum.Material.LeafyGrass)
	local off = Vector3.new(H.rng:NextNumber(-1.8, 1.8), 0, H.rng:NextNumber(-1.8, 1.8)) * scale
	H.ellipsoid(parent, "Leaves", CFrame.new(pos + off + Vector3.new(0, 10.8 * scale, 0)), Vector3.new(6, 4.8, 6) * scale,
		base:Lerp(Color3.fromRGB(160, 205, 90), 0.3), Enum.Material.LeafyGrass)
end

-- Palmeira (bairro nobre / praças): tronco levemente inclinado + 6 folhas caídas + cocos
function H.palm(parent, pos, scale)
	scale = scale or 1
	local h = 15 * scale
	local base = CFrame.new(pos) * CFrame.Angles(math.rad(H.rng:NextNumber(-6, 6)), H.rng:NextNumber(0, 6.28), math.rad(H.rng:NextNumber(-6, 6)))
	local trunk = H.block(parent, "PalmTrunk", Vector3.new(h, 1.1 * scale, 1.1 * scale), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 118, 84), Enum.Material.Wood, true)
	trunk.Shape = Enum.PartType.Cylinder
	local top = base * CFrame.new(0, h, 0)
	for k = 0, 5 do
		H.deco(parent, "PalmLeaf", Vector3.new(1.8 * scale, 0.2, 7.5 * scale),
			top * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.Angles(math.rad(-28), 0, 0) * CFrame.new(0, 0, -3.4 * scale),
			Color3.fromRGB(58 + H.rng:NextInteger(-8, 8), 138, 58), Enum.Material.LeafyGrass)
	end
	H.ball(parent, "Cocos", top * CFrame.new(0, -0.7, 0), 1.7 * scale, Color3.fromRGB(110, 82, 40), H.SP, false)
end

function H.surfaceText(part, face, text, textColor)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 25
	sg.LightInfluence = 0
	sg.MaxDistance = (part.Name == "Sign" or part.Name == "Outdoor" or part.Name == "Pylon" or part.Name == "Totem") and 600 or 350
	sg.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = sg
	return label
end

-- Ponto de coleta/entrega (lido pelo OrderManager). Fica INVISÍVEL: só marca a posição.
function H.pad(parent, pos, color)
	local p = H.deco(parent, "Pad", Vector3.new(0.2, 14, 14), CFrame.new(pos.X, 0.3, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 1
	p.CastShadow = false
	return p
end

-- Referencial local de um lote: x = direita, y = altura, z = em direção à rua
function H.lotFrame(bc: Vector3, dir: Vector3): CFrame
	local right = dir:Cross(Vector3.yAxis)
	return CFrame.fromMatrix(Vector3.new(bc.X, 0, bc.Z), right, Vector3.yAxis, -dir)
end
function H.at(frame: CFrame, x, y, z): CFrame
	return frame * CFrame.new(x, y, -z)
end

local carAssets = nil
local function getCarAssets()
	if carAssets == nil then
		carAssets = {}
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local folder = assets and assets:FindFirstChild("Cars")
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:IsA("Model") and not m:GetAttribute("NoParking") then
				table.insert(carAssets, m)
			end
		end
		table.sort(carAssets, function(a, b) return a.Name < b.Name end)
	end
	return carAssets
end

-- Carro (cf na altura do chão, olhando para frente). Usa os modelos 3D se existirem.
function H.car(parent, cf, color, collide)
	local assets = getCarAssets()
	if #assets > 0 then
		local m = H.pick(assets):Clone()
		m.Name = "Carro"
		m:PivotTo(cf)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = collide == true
				p.CanQuery = collide == true
				p.CanTouch = false
			end
		end
		m.Parent = parent
		return m
	end
	local m = Instance.new("Model")
	m.Name = "Carro"
	local body = H.block(m, "Body", Vector3.new(4.6, 2, 9.4), cf * CFrame.new(0, 1.6, 0), color, H.SP, collide)
	H.deco(m, "Cabin", Vector3.new(4.2, 1.7, 5), cf * CFrame.new(0, 3.4, 0.6), Color3.fromRGB(40, 50, 60), Enum.Material.Glass)
	for _, z in ipairs({ -3, 3 }) do
		local w = H.deco(m, "Axle", Vector3.new(5, 1.8, 1.8), cf * CFrame.new(0, 0.9, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
		w.Shape = Enum.PartType.Cylinder
	end
	H.deco(m, "Headlights", Vector3.new(3.6, 0.5, 0.2), cf * CFrame.new(0, 1.9, -4.72), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	H.deco(m, "Taillights", Vector3.new(3.6, 0.5, 0.2), cf * CFrame.new(0, 1.9, 4.72), Color3.fromRGB(220, 30, 30), Enum.Material.Neon)
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Cone decorativo (sem colisão, só 2 peças para a cidade grande ficar leve)
function H.staticCone(parent, pos)
	local cf = CFrame.new(pos.X, 0, pos.Z)
	H.deco(parent, "ConeBase", Vector3.new(2.2, 0.3, 2.2), cf * CFrame.new(0, 0.35, 0), H.DARKGRAY)
	H.cylV(parent, "Cone", cf * CFrame.new(0, 0.5, 0), 2.6, 1.4, H.ORANGE, H.SP, false)
end

return H
