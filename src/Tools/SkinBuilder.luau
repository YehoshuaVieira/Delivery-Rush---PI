-- Ferramenta de edição: transforma um modelo 3D de moto num template jogável (MotoSkins.NivelN).
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SkinBuilder = {}

local WHEELBASE = 5.32
local GROUND_Y = -1.315
local TEST_CF = CFrame.new(0, 1.35, 3470)

local function weldTo(ch, p)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = ch, p
	w.Parent = p
end

local function plate(vis, ch, name, size, rel, transparency, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = ch.CFrame * rel
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = false
	p.Parent = vis
	weldTo(ch, p)
	return p
end

local function logo(p, face)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.3
	sg.MaxDistance = 250
	sg.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = "🛵 DELIVERY\nRUSH"
	l.Parent = sg
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(20, 20, 25)
	s.Parent = l
end

-- src: Model gerado (peças com "front"/"rear" no nome = rodas). opts.BoxColor: cor do baú da marca (opcional)
function SkinBuilder.Build(src: Model, level: number, opts)
	opts = opts or {}
	local base = ServerStorage.MotoTemplate
	local t = base:Clone()
	t.Name = "Nivel" .. level
	t:SetAttribute("SkinLevel", level)
	local ch = t.Chassis
	local vis = t.Visual
	local brandBox = base.Visual:FindFirstChild("deliverybox")
	vis:ClearAllChildren()

	local pv = CFrame.new(src:GetPivot().Position)
	local front, rear, boxSrc, others = nil, nil, nil, {}
	for _, p in ipairs(src:GetDescendants()) do
		if p:IsA("MeshPart") then
			local n = p.Name:lower()
			if n:find("front") then
				front = p
			elseif n:find("rear") then
				rear = p
			elseif n:find("box") and opts.DropBox then
			elseif n:find("box") and p.Size.Y >= 0.8 and p.Size.Z <= 3.6 then
				boxSrc = p
			else
				table.insert(others, p)
			end
		end
	end
	assert(front and rear, "rodas não encontradas")
	local relF, relR = pv:ToObjectSpace(front.CFrame), pv:ToObjectSpace(rear.CFrame)
	local S = WHEELBASE / math.abs(relF.Z - relR.Z)
	local R = CFrame.Angles(0, math.pi, 0)
	local radius = front.Size.Y * S / 2
	local offY = GROUND_Y + radius - relF.Y * S
	local offZ = (relF.Z * S + relR.Z * S) / 2
	local offset = CFrame.new(0, offY, offZ)

	local meshParts = {}
	local function place(p, name)
		local rel = pv:ToObjectSpace(p.CFrame)
		local c = p:Clone()
		for _, j in ipairs(c:GetChildren()) do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end
		end
		c.Name = name
		c.Size = p.Size * S
		c.CFrame = ch.CFrame * offset * R * CFrame.new(rel.Position * S) * rel.Rotation
		c.Anchored = false
		c.CanCollide, c.CanTouch, c.Massless = false, false, true
		c.CanQuery = true
		c.Parent = vis
		table.insert(meshParts, c)
		return c
	end
	local fw = place(front, "frontwheel")
	local rw = place(rear, "rearwheel")
	for i, p in ipairs(others) do
		place(p, i == 1 and "body" or ("body" .. i))
	end
	local ownBox = boxSrc and place(boxSrc, "deliverybox")

	t:PivotTo(TEST_CF)
	t.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { vis }
	local cf = ch.CFrame
	local function cast(o: Vector3, d: Vector3)
		local hit = Workspace:Raycast(cf:PointToWorldSpace(o), cf:VectorToWorldSpace(d), params)
		return hit and cf:PointToObjectSpace(hit.Position)
	end
	local seatY, seatZ = math.huge, 0.8
	for z = 0.3, 1.5, 0.15 do
		local h = cast(Vector3.new(0, 9, z), Vector3.new(0, -12, 0))
		if h and h.Y < seatY then
			seatY, seatZ = h.Y, z
		end
	end
	if seatY == math.huge then
		seatY = 2.8
	end
	-- bagageiro: placa escura embaixo do baú + 2 hastes até a rabeta (cobre qualquer vão)
	local function addRack(bottom, cz, size, tailY)
		local rack = Instance.new("Part")
		rack.Name = "Bagageiro"
		rack.Size = Vector3.new(size.X * 0.6, 0.18, size.Z * 0.75)
		rack.CFrame = cf * CFrame.new(0, bottom - 0.09, cz)
		rack.Color = Color3.fromRGB(35, 35, 40)
		rack.Material = Enum.Material.Metal
		rack.CanCollide, rack.CanTouch, rack.Massless = false, false, true
		rack.CanQuery = false
		rack.Parent = vis
		table.insert(meshParts, rack)
		local h = math.max(1.6, bottom - (tailY or (bottom - 0.7)) + 0.6)
		for _, sgn in ipairs({ 1, -1 }) do
			local strut = rack:Clone()
			strut.Name = "BagageiroHaste"
			strut.Size = Vector3.new(0.2, h, 0.2)
			strut.CFrame = cf * CFrame.new(sgn * size.X * 0.25, bottom - h / 2, cz - size.Z * 0.2)
			strut.Parent = vis
			table.insert(meshParts, strut)
		end
	end

	local tail = {}
	local tailEnd, boxTop, boxZ0, boxZ1 = 1.5, -math.huge, nil, nil
	for z = 1.5, 5.5, 0.1 do
		local h = cast(Vector3.new(0, 9, z), Vector3.new(0, -12, 0))
		if h and h.Y > GROUND_Y + radius * 1.2 then
			tail[#tail + 1] = { Z = z, Y = h.Y }
			tailEnd = z
			if h.Y > seatY + 1.1 then
				boxTop = math.max(boxTop, h.Y)
				boxZ0 = boxZ0 or z
				boxZ1 = z
			end
		end
	end
	local hasBox = ownBox ~= nil or (boxZ0 ~= nil and (boxZ1 - boxZ0) > 1.0)
	local box
	if ownBox then
		local rel = cf:ToObjectSpace(ownBox.CFrame)
		ownBox.Size *= (opts.OwnBoxScale or 1.3)
		ownBox.CanQuery = false
		local under = cast(Vector3.new(0, 9, rel.Z), Vector3.new(0, -12, 0))
		local tailY = under and under.Y or seatY
		local bottom = math.max(tailY + 0.15, seatY - 0.1)
		ownBox.CFrame = cf * CFrame.new(0, bottom + ownBox.Size.Y / 2, rel.Z) * rel.Rotation
		ownBox.CanQuery = true
		addRack(bottom, rel.Z, ownBox.Size, tailY)
		box = { CenterZ = rel.Z, Bottom = bottom, Top = bottom + ownBox.Size.Y, Width = ownBox.Size.X }
	elseif hasBox then
		local cz = (boxZ0 + boxZ1) / 2
		local side = cast(Vector3.new(6, boxTop - 0.6, cz), Vector3.new(-12, 0, 0))
		box = { CenterZ = cz, Bottom = seatY + 0.3, Top = boxTop, Width = side and side.X * 2 or 2 }
	else
		local b = brandBox:Clone()
		for _, j in ipairs(b:GetChildren()) do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end
		end
		local k = (opts.BoxScale or 0.9)
		b.Size = brandBox.Size * k
		if opts.BoxColor then
			b.TextureID = ""
			b.Color = opts.BoxColor
			b.Material = Enum.Material.SmoothPlastic
			b.Reflectance = 0.05
		end
		local cz = seatZ + 0.9 + b.Size.Z / 2
		local under = cast(Vector3.new(0, 9, cz), Vector3.new(0, -12, 0))
		local tailY = under and under.Y or seatY
		local bottom = math.max(seatY + 0.45, tailY + 0.2)
		addRack(bottom, cz, b.Size, tailY)
		b.CFrame = cf * CFrame.new(0, bottom + b.Size.Y / 2, cz) * (base.Chassis.CFrame:ToObjectSpace(brandBox.CFrame)).Rotation
		b.Name = "deliverybox"
		b.Anchored = false
		b.CanCollide, b.CanTouch, b.Massless = false, false, true
		b.CanQuery = true
		b.Parent = vis
		table.insert(meshParts, b)
		box = { CenterZ = cz, Bottom = bottom, Top = bottom + b.Size.Y, Width = b.Size.X }
	end
	local midY = (box.Bottom + box.Top) / 2
	local back = cast(Vector3.new(0, midY, 9), Vector3.new(0, 0, -12))
	local backZ = back and back.Z or (box.CenterZ + 1.2)
	local lampY, lampZ = 2.3, -2.6
	local best = math.huge
	for y = 1.5, 3.2, 0.1 do
		local h = cast(Vector3.new(0, y, -9), Vector3.new(0, 0, 12))
		if h and h.Z < best then
			best, lampY, lampZ = h.Z, y, h.Z
		end
	end
	t.Parent = nil

	for _, p in ipairs(meshParts) do
		p.CanQuery = false
		if p == fw or p == rw then
			local w = Instance.new("Weld")
			w.Name = "WheelWeld"
			w.Part0, w.Part1 = ch, p
			w.C0 = ch.CFrame:ToObjectSpace(p.CFrame)
			w.C1 = CFrame.identity
			w:SetAttribute("Radius", p.Size.Y / 2)
			w.Parent = p
		else
			weldTo(ch, p)
		end
	end
	local bw = math.max(1.4, box.Width)
	local bh = box.Top - box.Bottom
	local bLogo = plate(vis, ch, "LogoTras", Vector3.new(bw * 0.8, bh * 0.42, 0.05), CFrame.new(0, midY + bh * 0.08, backZ + 0.04), 1)
	logo(bLogo, Enum.NormalId.Back)
	for _, sgn in ipairs({ 1, -1 }) do
		local s = plate(vis, ch, sgn > 0 and "LogoDireita" or "LogoEsquerda", Vector3.new(0.05, bh * 0.42, math.min(2.2, (backZ - box.CenterZ) * 1.4)),
			CFrame.new(sgn * (bw / 2 + 0.04), midY + bh * 0.05, box.CenterZ), 1)
		logo(s, sgn > 0 and Enum.NormalId.Right or Enum.NormalId.Left)
	end
	plate(vis, ch, "LanternaBau", Vector3.new(bw * 0.5, 0.16, 0.08), CFrame.new(0, box.Bottom + 0.35, backZ - 0.02), 0, Color3.fromRGB(120, 12, 18), Enum.Material.Neon)
	t.Headlight.CFrame = ch.CFrame * CFrame.new(0, lampY, lampZ - 0.3)
	t.Seat.CFrame = ch.CFrame * CFrame.new(0, seatY - 0.3, seatZ)
	for _, part in ipairs({ t.Seat, t.Headlight }) do
		for _, j in ipairs(part:GetChildren()) do
			if j:IsA("WeldConstraint") then j:Destroy() end
		end
		weldTo(ch, part)
	end

	local folder = ServerStorage:FindFirstChild("MotoSkins") or Instance.new("Folder")
	folder.Name = "MotoSkins"
	folder.Parent = ServerStorage
	local old = folder:FindFirstChild(t.Name)
	if old then
		old:Destroy()
	end
	t.Parent = folder
	return string.format("%s: escala %.2f, banco y=%.2f z=%.2f, baú %s (topo %.2f, z %.2f, larg %.2f), farol y=%.2f z=%.2f",
		t.Name, S, seatY, seatZ, hasBox and "próprio" or "da marca", box.Top, box.CenterZ, box.Width, lampY, lampZ)
end

return SkinBuilder
