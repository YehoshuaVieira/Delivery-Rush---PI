-- Ferramenta de edição: monta uma moto importada (Blender -> Importar 3D) no esqueleto físico do MotoTemplate.
-- Peças da fonte: <Moto>_frontwheel/_rearwheel = pneus (giram, recebem o WheelWeld); sufixo Dianteira/Traseira = giram
-- junto com a roda; Banco, Farol e Escape orientam assento, farol e chama do turbo; Lanterna vira a luz de freio.
-- As motos não têm baú (peças Bau*/Bagageiro da fonte são ignoradas). Ver blender/moto_nova.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AcabamentoMoto = require(script.Parent.AcabamentoMoto)

local MotoBuilder = {}

local WHEELBASE = 5.32
local GROUND_Y = -1.315
local TEST_CF = CFrame.new(0, 1.35, 3470)

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- caixa (no espaço do chassi) de uma peça girada só em volta do eixo Y
local function box(ch: BasePart, p: BasePart)
	local cf, size = p.CFrame, p.Size
	local corners = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(corners, ch.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(sx, sy, sz) * size / 2)))
			end
		end
	end
	local mn, mx = corners[1], corners[1]
	for _, c in ipairs(corners) do
		mn = mn:Min(c)
		mx = mx:Max(c)
	end
	return mn, mx
end

-- src: Model importado. looks: [nome sem prefixo] = { r, g, b, "Material", reflectance } (peças sem textura).
function MotoBuilder.Build(src: Model, name: string, looks, opts)
	opts = opts or {}
	local t = ServerStorage.MotoTemplate:Clone()
	t.Name = name
	t:SetAttribute("SkinName", name)
	local ch = t.Chassis
	local vis = t.Visual
	vis:ClearAllChildren()

	local parts, front, rear = {}, nil, nil
	for _, p in ipairs(src:GetDescendants()) do
		local key = p:IsA("MeshPart") and (p.Name:match("_(.+)$") or p.Name)
		if key and not key:match("^Bau") and key ~= "Bagageiro" then
			parts[key] = p
			if key == "frontwheel" then
				front = p
			elseif key == "rearwheel" then
				rear = p
			end
		end
	end
	assert(front and rear, "pneus não encontrados")
	local S = WHEELBASE / math.abs(front.Position.X - rear.Position.X)
	-- importado com a frente para -X (ou +X); no chassi a frente é -Z
	local rot = front.Position.X < rear.Position.X and CFrame.Angles(0, -math.pi / 2, 0) or CFrame.Angles(0, math.pi / 2, 0)
	local ground = math.min(front.Position.Y - front.Size.Y / 2, rear.Position.Y - rear.Size.Y / 2)
	local pivot = CFrame.new((front.Position.X + rear.Position.X) / 2, ground, (front.Position.Z + rear.Position.Z) / 2)
	local base = ch.CFrame * CFrame.new(0, GROUND_Y, 0) * rot

	local built = {}
	for key, p in pairs(parts) do
		local rel = pivot:ToObjectSpace(p.CFrame)
		local c = p:Clone()
		for _, j in ipairs(c:GetChildren()) do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
				j:Destroy()
			end
		end
		c.Name = key
		c.Size = p.Size * S
		c.CFrame = base * CFrame.new(rel.Position * S) * rel.Rotation
		c.Anchored = false
		c.CanCollide, c.CanTouch, c.CanQuery, c.Massless = false, false, true, true
		local look = looks and looks[key]
		if look and not c:FindFirstChildOfClass("SurfaceAppearance") then
			c.Color = Color3.fromRGB(look[1], look[2], look[3])
			c.Material = Enum.Material[look[4]]
			c.Reflectance = look[5]
			c.Transparency = look[4] == "Glass" and 0.3 or 0
		end
		c.CastShadow = c.Size.Magnitude > 1.5
		c.Parent = vis
		built[key] = c
	end

	-- assento: o ponto mais baixo do banco na área do piloto (raycast só no banco)
	t:PivotTo(TEST_CF)
	t.Parent = Workspace
	local cf = ch.CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { built.Banco or vis }
	local seatY, seatZ = math.huge, 0.6
	local range = opts.SeatRange or { -0.2, 1.6 } -- z do chassi (+ = para trás) onde fica o piloto
	for z = range[1], range[2], 0.1 do
		local hit = Workspace:Raycast(cf:PointToWorldSpace(Vector3.new(0, 9, z)), cf:VectorToWorldSpace(Vector3.new(0, -12, 0)), params)
		if hit then
			local y = cf:PointToObjectSpace(hit.Position).Y
			if y < seatY then
				seatY, seatZ = y, z
			end
		end
	end
	-- sem peça Farol: o farol vai no ponto mais à frente da moto (sem contar as rodas) na altura do guidão
	local lampY, lampZ = nil, math.huge
	if not built.Farol then
		local static = {}
		for key, c in pairs(built) do
			if key ~= "frontwheel" and key ~= "rearwheel" and not key:match("Dianteira$") and not key:match("Traseira$") then
				table.insert(static, c)
			end
		end
		params.FilterDescendantsInstances = static
		for y = 1.4, 2.8, 0.1 do
			local hit = Workspace:Raycast(cf:PointToWorldSpace(Vector3.new(0, y, -9)), cf:VectorToWorldSpace(Vector3.new(0, 0, 12)), params)
			local z = hit and cf:PointToObjectSpace(hit.Position).Z
			if z and z < lampZ then
				lampY, lampZ = y, z
			end
		end
	end
	t.Parent = nil
	if opts.Seat then
		-- altura/posição do banco medidas no Blender (moto de malha única: a colisão aproximada engana o raycast)
		seatY, seatZ = GROUND_Y + opts.Seat[2] * S, -opts.Seat[1] * S
	elseif seatY == math.huge then
		seatY = 1.6
	end

	-- rodas: o pneu recebe o WheelWeld (o MotoController gira) e as peças Dianteira/Traseira vão soldadas nele
	for key, c in pairs(built) do
		c.CanQuery = false
		if key == "frontwheel" or key == "rearwheel" then
			local w = Instance.new("Weld")
			w.Name = "WheelWeld"
			w.Part0, w.Part1 = ch, c
			w.C0 = ch.CFrame:ToObjectSpace(c.CFrame)
			w.C1 = CFrame.identity
			w:SetAttribute("Radius", c.Size.Y / 2)
			w.Parent = c
		elseif key:match("Dianteira$") then
			weld(built.frontwheel, c)
		elseif key:match("Traseira$") then
			weld(built.rearwheel, c)
		else
			weld(ch, c)
		end
	end

	t.Seat.CFrame = ch.CFrame * CFrame.new(0, seatY - 0.3 + (opts.SeatOffsetY or 0), seatZ)
	if built.Farol then
		local mn, mx = box(ch, built.Farol)
		t.Headlight.CFrame = ch.CFrame * CFrame.new(0, (mn.Y + mx.Y) / 2, mn.Z - 0.2)
	elseif lampY then
		t.Headlight.CFrame = ch.CFrame * CFrame.new(0, lampY, lampZ - 0.2)
	end
	if built.Escape then
		local mn, mx = box(ch, built.Escape)
		t.Exhaust.CFrame = ch.CFrame * CFrame.new(opts.ExhaustX or mn.X * 0.5, mn.Y + 0.35, mx.Z - 0.4)
	end
	for _, part in ipairs({ t.Seat, t.Headlight, t.Exhaust }) do
		for _, j in ipairs(part:GetChildren()) do
			if j:IsA("WeldConstraint") then
				j:Destroy()
			end
		end
		weld(ch, part)
	end

	-- a lanterna da moto é a luz de freio (o MotoController procura "LanternaBau")
	if built.Lanterna then
		built.Lanterna.Name = "LanternaBau"
		built.Lanterna.Color = Color3.fromRGB(120, 12, 18)
	end
	local polish = AcabamentoMoto.Polir(t, opts.PlateNumber or 3)

	local folder = ServerStorage:FindFirstChild("MotoSkins")
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	t.Parent = folder

	-- vitrine do menu: cópia ancorada, sem física nem assento
	local shelf = ReplicatedStorage.Assets:FindFirstChild("MotoVitrines") or Instance.new("Folder")
	shelf.Name = "MotoVitrines"
	shelf.Parent = ReplicatedStorage.Assets
	local oldShow = shelf:FindFirstChild(name)
	if oldShow then
		oldShow:Destroy()
	end
	local show = t:Clone()
	for _, d in ipairs(show:GetDescendants()) do
		if d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("ParticleEmitter") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
		end
	end
	for _, n in ipairs({ "Seat", "Collider", "ColliderBack", "ColliderFront", "Exhaust", "Headlight" }) do
		local x = show:FindFirstChild(n)
		if x then
			x:Destroy()
		end
	end
	show.Parent = shelf

	return string.format("%s: escala %.2f, banco y=%.2f z=%.2f; %s", name, S, seatY, seatZ, polish)
end

return MotoBuilder
