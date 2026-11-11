-- Acabamento visual depois de gerar um bairro: janelas de verdade nas fachadas, cores, ruas (faixas, desgaste, calçada).
-- Tudo por textura ou em pastas próprias "Acabamento": quase nenhuma peça nova, e dá para desfazer (Desfazer).

local Acabamento = {}

local TEX = {
	Janela = { "rbxassetid://115119698880221", "rbxassetid://139647815877499", "rbxassetid://137219906928883" }, -- vidro, persiana, cortina
	FaixaPedestre = "rbxassetid://123926323159838",
	Calcada = "rbxassetid://123466267090346",
	Desgaste = "rbxassetid://137658996572801",
	VidroCasa = "rbxassetid://105559492407425",
	ParedeCasa = "rbxassetid://118708413603978", -- reboco leve + barrado escuro embaixo
	Reboco = "rbxassetid://96691013617261", -- reboco leve, sem barrado (casas que já têm rodapé)
	VidroModerno = "rbxassetid://115025566695085", -- 3 painéis com caixilho e reflexo; repete sem emenda na vertical
}
local WINDOW_H = 3.2 -- altura da faixa de janelas (era 2,5: janelas achatadas)

-- sorteio estável por posição (o mesmo prédio sempre recebe o mesmo resultado)
local function hash(v: Vector3, salt: number): number
	local h = math.floor(v.X * 73.13 + v.Z * 19.7 + v.Y * 7.31 + salt * 101.9)
	return (h * 2654435761) % 1000 / 1000
end

------------------------------------------------------------------ cores das fachadas
local PLASTER = {
	Color3.fromRGB(214, 196, 160), Color3.fromRGB(230, 220, 196), Color3.fromRGB(196, 140, 108), Color3.fromRGB(196, 198, 200),
	Color3.fromRGB(160, 178, 196), Color3.fromRGB(162, 180, 152), Color3.fromRGB(214, 156, 132), Color3.fromRGB(200, 164, 96),
	Color3.fromRGB(236, 234, 226),
}
local BRICK = { Color3.fromRGB(170, 95, 75), Color3.fromRGB(150, 85, 65), Color3.fromRGB(184, 118, 88) }

local function recolor(building: BasePart)
	if building:GetAttribute("OrigColor") == nil then
		building:SetAttribute("OrigColor", building.Color)
	end
	if building.Material == Enum.Material.Brick then
		building.Color = BRICK[1 + math.floor(hash(building.Position, 1) * #BRICK)]
	elseif hash(building.Position, 2) < 0.45 then
		building.Color = PLASTER[1 + math.floor(hash(building.Position, 3) * #PLASTER)]
	end
end

------------------------------------------------------------------ janelas
-- Cada faixa "Windows" (vidro contínuo em volta do andar) vira parede com uma fileira de janelas por textura,
-- centradas entre os pilares (Pier) daquela face.
local FACES = {
	{ Enum.NormalId.Front, "X", "Z", -1 }, { Enum.NormalId.Back, "X", "Z", 1 },
	{ Enum.NormalId.Right, "Z", "X", 1 }, { Enum.NormalId.Left, "Z", "X", -1 },
}

local function windowBand(band: BasePart, wall: BasePart, piers)
	for _, t in ipairs(band:GetChildren()) do
		if t:IsA("Texture") then
			t:Destroy()
		end
	end
	if band:GetAttribute("OrigColor") == nil then
		band:SetAttribute("OrigColor", band.Color)
		band:SetAttribute("OrigMaterial", band.Material.Name)
		band:SetAttribute("OrigTransparency", band.Transparency)
		band:SetAttribute("OrigHeight", band.Size.Y)
	end
	band.Color = wall.Color
	band.Material = wall.Material
	band.Transparency = 0
	band.Reflectance = 0
	band.Size = Vector3.new(band.Size.X, WINDOW_H, band.Size.Z)
	for k, f in ipairs(FACES) do
		local face, uAxis, nAxis, sign = f[1], f[2], f[3], f[4]
		local width = band.Size[uAxis]
		local us = {}
		for _, p in ipairs(piers) do
			local lp = band.CFrame:PointToObjectSpace(p.Position)
			if math.abs(lp[nAxis] - sign * band.Size[nAxis] / 2) < 1.5 then
				table.insert(us, lp[uAxis])
			end
		end
		table.sort(us)
		-- vão entre pilares; vão largo leva 2 janelas. Sem pilares: uma janela a cada 5 studs, centrada
		local s = #us >= 2 and (us[#us] - us[1]) / (#us - 1) or 5
		local tile = s > 8.5 and s / 2 or s
		local ref = #us > 0 and us[1] or 0
		local r = hash(band.Position, k)
		local tex = Instance.new("Texture")
		tex.Name = "Janelas"
		tex.Face = face
		tex.Texture = r < 0.62 and TEX.Janela[1] or (r < 0.84 and TEX.Janela[2] or TEX.Janela[3])
		tex.StudsPerTileU = tile
		tex.StudsPerTileV = WINDOW_H
		tex.OffsetStudsU = (ref + width / 2) % tile
		tex.Parent = band
	end
end

function Acabamento.Fachadas(areaFolder: Instance): number
	local count = 0
	for _, groupName in ipairs({ "Buildings", "Customers" }) do
		local group = areaFolder:FindFirstChild(groupName)
		for _, lot in ipairs(group and group:GetChildren() or {}) do
			if lot:IsA("Model") then
				local walls, bands, piers = {}, {}, {}
				for _, p in ipairs(lot:GetChildren()) do
					if p:IsA("BasePart") then
						if p.Name == "Building" then
							table.insert(walls, p)
						elseif p.Name == "Windows" then
							table.insert(bands, p)
						elseif p.Name == "Pier" then
							table.insert(piers, p)
						end
					end
				end
				for _, w in ipairs(walls) do
					recolor(w)
				end
				for _, band in ipairs(bands) do
					-- parede dona da faixa: o prédio cuja caixa contém o centro da faixa
					local wall = walls[1]
					for _, w in ipairs(walls) do
						local lp = w.CFrame:PointToObjectSpace(band.Position)
						if math.abs(lp.X) <= w.Size.X / 2 + 1 and math.abs(lp.Z) <= w.Size.Z / 2 + 1 and math.abs(lp.Y) <= w.Size.Y / 2 + 1 then
							wall = w
							break
						end
					end
					if wall then
						windowBand(band, wall, piers)
						count += 1
					end
				end
			end
		end
	end
	return count
end

-- volta as fachadas ao que eram (cores, faixas de vidro)
function Acabamento.DesfazerFachadas(areaFolder: Instance)
	for _, d in ipairs(areaFolder:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("OrigColor") ~= nil and (d.Name == "Building" or d.Name == "Windows") then
			d.Color = d:GetAttribute("OrigColor")
			if d.Name == "Windows" then
				d.Material = Enum.Material[d:GetAttribute("OrigMaterial")]
				d.Transparency = d:GetAttribute("OrigTransparency") or 0
				d.Size = Vector3.new(d.Size.X, d:GetAttribute("OrigHeight") or d.Size.Y, d.Size.Z)
				for _, t in ipairs(d:GetChildren()) do
					if t:IsA("Texture") then
						t:Destroy()
					end
				end
			end
		end
	end
end

------------------------------------------------------------------ ruas
local LANE = 8 -- distância do centro da rua ao centro de cada mão (igual às rotas de trânsito)
local WALK = 4 -- profundidade da faixa de pedestre
local WALK_GAP = 1.5 -- da borda do cruzamento até a faixa

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function texture(part: BasePart, id: string, u: number, v: number, transparency: number?)
	local t = Instance.new("Texture")
	t.Face = Enum.NormalId.Top
	t.Texture = id
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	t.Transparency = transparency or 0
	t.Parent = part
	return t
end

-- ruas (sem becos) a partir do atributo RoadLines, com os trechos da mesma linha juntos
local function roadSegments(areaFolder: Instance)
	local lines = {}
	local text = areaFolder:GetAttribute("RoadLines")
	for ax, coord, lo, hi, width, alley in string.gmatch(type(text) == "string" and text or "", "([01]),([^,]+),([^,]+),([^,]+),([^,]+),([01])") do
		if alley == "0" then
			local key = ax .. math.round(tonumber(coord))
			lines[key] = lines[key] or { AlongX = ax == "1", Coord = tonumber(coord), Width = tonumber(width), Spans = {} }
			table.insert(lines[key].Spans, { tonumber(lo), tonumber(hi) })
		end
	end
	local segs = {}
	for _, line in pairs(lines) do
		table.sort(line.Spans, function(a, b)
			return a[1] < b[1]
		end)
		local cur
		for _, s in ipairs(line.Spans) do
			if cur and s[1] <= cur.B + 1 then
				cur.B = math.max(cur.B, s[2])
			else
				cur = { AlongX = line.AlongX, Coord = line.Coord, Width = line.Width, A = s[1], B = s[2], Cross = {} }
				table.insert(segs, cur)
			end
		end
	end
	-- cruzamentos: posição T ao longo de cada rua onde outra rua passa
	for _, a in ipairs(segs) do
		if a.AlongX then
			for _, b in ipairs(segs) do
				if not b.AlongX then
					local x, z = b.Coord, a.Coord
					if x >= a.A - b.Width / 2 - 1 and x <= a.B + b.Width / 2 + 1 and z >= b.A - a.Width / 2 - 1 and z <= b.B + a.Width / 2 + 1 then
						table.insert(a.Cross, { T = x, Half = b.Width / 2 })
						table.insert(b.Cross, { T = z, Half = a.Width / 2 })
					end
				end
			end
		end
	end
	for _, s in ipairs(segs) do
		table.sort(s.Cross, function(p, q)
			return p.T < q.T
		end)
	end
	return segs
end

-- CFrame no chão da rua: X da peça = atravessando a rua, Z = ao longo dela
local function roadFrame(s, t: number, offset: number, y: number): CFrame
	local along = s.AlongX and Vector3.xAxis or Vector3.zAxis
	local across = s.AlongX and Vector3.zAxis or Vector3.xAxis
	local pos = (s.AlongX and Vector3.new(t, y, s.Coord) or Vector3.new(s.Coord, y, t)) + across * offset
	-- Z tem que ser X × Y (base "destra"); com o Z escolhido à mão a peça sai espelhada nas ruas do eixo X
	return CFrame.fromMatrix(pos, across, Vector3.yAxis, across:Cross(Vector3.yAxis))
end

-- trechos livres de uma rua (fora dos cruzamentos e das faixas de pedestre)
local function freeIntervals(s, margin: number)
	local list, cursor = {}, s.A
	for _, c in ipairs(s.Cross) do
		local lo, hi = c.T - c.Half - margin, c.T + c.Half + margin
		if lo > cursor + 2 then
			table.insert(list, { cursor, lo })
		end
		cursor = math.max(cursor, hi)
	end
	if s.B > cursor + 2 then
		table.insert(list, { cursor, s.B })
	end
	return list
end

function Acabamento.Ruas(areaFolder: Instance): string
	local old = areaFolder:FindFirstChild("Acabamento")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Acabamento"
	local folders = {}
	for _, n in ipairs({ "FaixasPedestre", "Retencao", "LinhaCentral", "Desgaste", "MeioFio" }) do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = root
		folders[n] = f
	end
	local WHITE = Color3.fromRGB(236, 236, 232)
	local segs = roadSegments(areaFolder)
	local walks, stops, wears = 0, 0, 0
	for _, s in ipairs(segs) do
		local top = s.AlongX and 0.12 or 0.2 -- ruas no eixo X ficam mais baixas (anti-cintilação)
		-- faixas de pedestre e linha de retenção em cada chegada a um cruzamento
		for _, c in ipairs(s.Cross) do
			for _, dir in ipairs({ -1, 1 }) do
				local t = c.T + dir * (c.Half + WALK_GAP + WALK / 2)
				if t - WALK / 2 > s.A + 2 and t + WALK / 2 < s.B - 2 then
					local walk = deco(folders.FaixasPedestre, "Faixa", Vector3.new(s.Width - 3, 0.04, WALK), roadFrame(s, t, 0, 0.223), WHITE, nil, 1)
					texture(walk, TEX.FaixaPedestre, 2.4, WALK)
					walks += 1
					-- quem chega ao cruzamento vem andando no sentido -dir: a mão dele fica à direita desse sentido
					local travel = (s.AlongX and Vector3.xAxis or Vector3.zAxis) * -dir
					local right = travel:Cross(Vector3.yAxis)
					local across = s.AlongX and Vector3.zAxis or Vector3.xAxis
					local side = right:Dot(across) > 0 and 1 or -1
					local ts = t + dir * (WALK / 2 + 1)
					deco(folders.Retencao, "Retencao", Vector3.new(s.Width / 2 - 1.5, 0.04, 0.7), roadFrame(s, ts, side * (s.Width / 4 - 0.25), 0.223), WHITE)
					stops += 1
				end
			end
		end
		-- desgaste das duas mãos (onde os pneus passam), só fora dos cruzamentos
		for _, iv in ipairs(freeIntervals(s, WALK_GAP + WALK + 2)) do
			local len, mid = iv[2] - iv[1], (iv[1] + iv[2]) / 2
			for _, side in ipairs({ -1, 1 }) do
				local wear = deco(folders.Desgaste, "Desgaste", Vector3.new(10, 0.02, len), roadFrame(s, mid, side * LANE, top + 0.004), WHITE, nil, 1)
				texture(wear, TEX.Desgaste, 10, 24, 0.75)
				wears += 1
			end
		end
	end

	-- linha amarela: a original vira invisível e volta em pedaços que param antes de cada cruzamento
	local roads = areaFolder:FindFirstChild("Roads")
	local pieces = 0
	for _, cl in ipairs(roads and roads:GetChildren() or {}) do
		if cl:IsA("BasePart") and cl.Name == "CenterLine" then
			local alongX = cl.Size.X > cl.Size.Z
			local coord = alongX and cl.Position.Z or cl.Position.X
			local len = alongX and cl.Size.X or cl.Size.Z
			local mid = alongX and cl.Position.X or cl.Position.Z
			local seg
			for _, s in ipairs(segs) do
				if s.AlongX == alongX and math.abs(s.Coord - coord) < 1 and mid >= s.A - 1 and mid <= s.B + 1 then
					seg = s
					break
				end
			end
			if seg then
				if cl:GetAttribute("OrigTransparency") == nil then
					cl:SetAttribute("OrigTransparency", cl.Transparency)
				end
				cl.Transparency = 1
				local view = { A = mid - len / 2, B = mid + len / 2, Cross = seg.Cross }
				for _, iv in ipairs(freeIntervals(view, WALK_GAP + WALK + 2.5)) do
					local piece = cl:Clone()
					piece.Name = "LinhaCentral"
					piece.Transparency = cl:GetAttribute("OrigTransparency")
					piece:SetAttribute("OrigTransparency", nil)
					local l = iv[2] - iv[1]
					local m = (iv[1] + iv[2]) / 2
					piece.Size = alongX and Vector3.new(l, cl.Size.Y, cl.Size.Z) or Vector3.new(cl.Size.X, cl.Size.Y, l)
					piece.Position = alongX and Vector3.new(m, cl.Position.Y, cl.Position.Z) or Vector3.new(cl.Position.X, cl.Position.Y, m)
					piece.CanCollide, piece.CanQuery, piece.CanTouch = false, false, false
					piece.Parent = folders.LinhaCentral
					pieces += 1
				end
			end
		end
	end

	-- o lote ficava só 0,02 acima da calçada: a textura das placas "vazava" no gramado de longe. Sobe o topo 0,06.
	for _, lot in ipairs(areaFolder:FindFirstChild("Buildings") and areaFolder.Buildings:GetChildren() or {}) do
		if lot:IsA("BasePart") and lot.Name == "Lot" and not lot:GetAttribute("Elevado") then
			lot:SetAttribute("Elevado", true)
			lot.Size += Vector3.new(0, 0.06, 0)
			lot.Position += Vector3.new(0, 0.03, 0)
		end
	end

	-- calçadas: placas de concreto por textura e meio-fio em volta de cada quarteirão
	local curbs, walksides = 0, 0
	for _, d in ipairs(areaFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Sidewalk" and not d:IsDescendantOf(root) then
			if not d:FindFirstChild("Placas") then
				local t = texture(d, TEX.Calcada, 4, 4, 0.15)
				t.Name = "Placas"
			end
			walksides += 1
			local top = d.Position.Y + d.Size.Y / 2
			local cf = d.CFrame
			for _, e in ipairs({ { "X", 1 }, { "X", -1 }, { "Z", 1 }, { "Z", -1 } }) do
				local size, off
				if e[1] == "X" then
					size = Vector3.new(0.7, 0.16, d.Size.Z)
					off = Vector3.new(e[2] * (d.Size.X / 2 - 0.35), 0, 0)
				else
					size = Vector3.new(d.Size.X, 0.16, 0.7)
					off = Vector3.new(0, 0, e[2] * (d.Size.Z / 2 - 0.35))
				end
				local p = cf * CFrame.new(off)
				deco(folders.MeioFio, "MeioFio", size, CFrame.new(p.X, top + 0.06, p.Z) * cf.Rotation, Color3.fromRGB(214, 212, 204), Enum.Material.Concrete)
				curbs += 1
			end
		end
	end
	root.Parent = areaFolder
	return string.format("%s: %d faixas de pedestre, %d retenções, %d trechos de desgaste, %d pedaços de linha, %d calçadas, %d meios-fios",
		areaFolder.Name, walks, stops, wears, pieces, walksides, curbs)
end

-- tira tudo o que Ruas() criou e devolve a linha amarela original
function Acabamento.DesfazerRuas(areaFolder: Instance)
	local f = areaFolder:FindFirstChild("Acabamento")
	if f then
		f:Destroy()
	end
	for _, d in ipairs(areaFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "CenterLine" and d:GetAttribute("OrigTransparency") ~= nil then
			d.Transparency = d:GetAttribute("OrigTransparency")
		elseif d:IsA("Texture") and d.Name == "Placas" then
			d:Destroy()
		end
	end
end

------------------------------------------------------------------ casas
-- Vidro das janelas com céu refletido (era azul-marinho chapado) e, nos sobrados, reboco com barrado
function Acabamento.Casas(areaFolder: Instance): string
	local glass, walls = 0, 0
	for _, groupName in ipairs({ "Buildings", "Customers" }) do
		local group = areaFolder:FindFirstChild(groupName)
		for _, p in ipairs(group and group:GetDescendants() or {}) do
			if p:IsA("BasePart") and p.Name == "WindowGlass" and not p:FindFirstChild("Vidro") then
				for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
					local t = Instance.new("Texture")
					t.Name = "Vidro"
					t.Face = face
					t.Texture = TEX.VidroCasa
					t.StudsPerTileU = p.Size.X
					t.StudsPerTileV = p.Size.Y
					t.Parent = p
				end
				glass += 1
			elseif p:IsA("BasePart") and p.Name == "Sobrado" and not p:FindFirstChild("Reboco") then
				for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
					local t = Instance.new("Texture")
					t.Name = "Reboco"
					t.Face = face
					t.Texture = TEX.ParedeCasa
					t.StudsPerTileU = 12
					t.StudsPerTileV = p.Size.Y -- um ladrilho na altura toda: o barrado fica no pé da parede
					t.Parent = p
				end
				walls += 1
			end
		end
	end
	-- paredes das casas térreas/sobrados "House" (já têm rodapé), vidro das mansões e das torres
	local plaster, modern = 0, 0
	local function sideTextures(p: BasePart, name: string, id: string, u: number, v: number)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local t = Instance.new("Texture")
			t.Name = name
			t.Face = face
			t.Texture = id
			t.StudsPerTileU = u
			t.StudsPerTileV = v
			t.Parent = p
		end
	end
	local buildings = areaFolder:FindFirstChild("Buildings")
	for _, p in ipairs(buildings and buildings:GetDescendants() or {}) do
		if p:IsA("BasePart") then
			if p.Name == "House" and not p:FindFirstChild("Reboco") then
				sideTextures(p, "Reboco", TEX.Reboco, 12, 12)
				plaster += 1
			elseif (p.Name == "VidroTerreo" or p.Name == "VidroSuperior") and not p:FindFirstChild("VidroModerno") then
				sideTextures(p, "VidroModerno", TEX.VidroModerno, 10, p.Size.Y)
				p.Transparency = math.min(p.Transparency, 0.12)
				modern += 1
			elseif p.Name == "Tower" and p.Material == Enum.Material.Glass and not p:FindFirstChild("VidroModerno") then
				sideTextures(p, "VidroModerno", TEX.VidroModerno, 12, 12)
				modern += 1
			end
		end
	end
	return string.format("%s: %d vidros, %d paredes de sobrado, %d paredes de casa, %d vidros modernos", areaFolder.Name, glass, walls, plaster, modern)
end

Acabamento.TEX = TEX
return Acabamento
