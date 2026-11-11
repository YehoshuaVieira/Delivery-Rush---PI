-- Gerador da cidade (só edição): Build("base"), Build(1..5) ou Build(). ATENÇÃO: apaga e recria o mapa.

local Workspace = game:GetService("Workspace")

local H = require(script.Helpers)
local D = require(script.Data)
local Restaurants = require(script.Restaurants)
local Blocks = require(script.Blocks)
local Obstacles = require(script.Obstacles)
local Passagem = require(script.Passagem)

local MapBuilder = {}

local MAX_PART = 2000
local W = D.ROAD_W
local LANE = W / 4

-- Faixa (chão, rua, parede) de a até b, dividida em pedaços <= MAX_PART
local function strip(parent, name, a: Vector3, b: Vector3, width, height, y, color, material, collide)
	local delta = b - a
	local len = delta.Magnitude
	local unit = delta.Unit
	local n = math.max(1, math.ceil(len / MAX_PART))
	local horizontal = math.abs(unit.X) > 0.5
	local parts = {}
	for k = 0, n - 1 do
		local s0, s1 = len * k / n, len * (k + 1) / n
		local mid = a + unit * ((s0 + s1) / 2)
		local size = horizontal and Vector3.new(s1 - s0, height, width) or Vector3.new(width, height, s1 - s0)
		table.insert(parts, H.block(parent, name, size, CFrame.new(mid.X, y, mid.Z), color, material, collide))
	end
	return parts
end

local function countParts(root: Instance): number
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Posições das ruas (coordenadas locais) de 'from' até 'to', com espaçamento sorteado.
local function makeLines(from: number, to: number, must: number?)
	local lines = { from }
	local minStep = math.huge
	for _, s in ipairs(D.SPACINGS) do
		minStep = math.min(minStep, s)
	end
	local function fill(a, b)
		local x = a
		while true do
			local step = H.pick(D.SPACINGS)
			if b - (x + step) < minStep then
				local rest = b - x
				if rest > 280 then
					table.insert(lines, x + math.round(rest / 2))
				end
				table.insert(lines, b)
				return
			end
			x += step
			table.insert(lines, x)
		end
	end
	if must then
		fill(from, must)
		fill(must, to)
	else
		fill(from, to)
	end
	return lines
end

local function buildBase(): string
	Workspace.StreamingEnabled = true
	pcall(function()
		Workspace.StreamingMinRadius = 400
		Workspace.StreamingTargetRadius = 1500
		Workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.MinimumRadiusPause
	end)
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	if not Workspace:FindFirstChild("Motos") then
		H.folder("Motos", Workspace)
	end

	local map = H.folder("Map", Workspace)
	map:SetAttribute("RoadW", D.ROAD_W)
	map:SetAttribute("SidewalkW", D.SIDEWALK_W)
	H.folder("Areas", map)
	local spawns = H.folder("MotoSpawns", map)

	local world = Instance.new("Model")
	world.Name = "World"
	world.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local tile = 2048
	local n = math.ceil((D.WORLD_LIMIT + 100) * 2 / tile)
	local start = -n * tile / 2 + tile / 2
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			H.block(world, "Ground", Vector3.new(tile, 16, tile), CFrame.new(start + i * tile, -8, start + j * tile),
				Color3.fromRGB(104, 150, 72), Enum.Material.Grass, true)
		end
	end
	local L = D.WORLD_LIMIT
	for _, w in ipairs({
		{ Vector3.new(-L, 0, -L), Vector3.new(L, 0, -L) }, { Vector3.new(-L, 0, L), Vector3.new(L, 0, L) },
		{ Vector3.new(-L, 0, -L), Vector3.new(-L, 0, L) }, { Vector3.new(L, 0, -L), Vector3.new(L, 0, L) },
	}) do
		for _, p in ipairs(strip(world, "Boundary", w[1], w[2], 2, 60, 30, H.WHITE, nil, true)) do
			p.Transparency = 1
			p.CanQuery = false
		end
	end
	world.Parent = map

	for i, s in ipairs({
		{ Vector3.new(LANE, 1.7, -50), Vector3.new(0, 0, -1) },
		{ Vector3.new(-LANE, 1.7, 50), Vector3.new(0, 0, 1) },
		{ Vector3.new(50, 1.7, LANE), Vector3.new(1, 0, 0) },
		{ Vector3.new(-50, 1.7, -LANE), Vector3.new(-1, 0, 0) },
	}) do
		H.deco(spawns, "Spawn" .. i, Vector3.new(2, 1, 4), CFrame.lookAt(s[1], s[1] + s[2]), Color3.fromRGB(0, 255, 0)).Transparency = 1
	end
	local spawnLoc = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLoc then
		spawnLoc.CFrame = CFrame.new(0, 0.5, 0)
		spawnLoc.Size = Vector3.new(6, 1, 6)
		spawnLoc.Transparency = 1
		spawnLoc.CanCollide = false
		spawnLoc.Duration = 0
	end
	return "Base criada: " .. countParts(map) .. " peças"
end

local function buildArea(area): string
	local map = Workspace:FindFirstChild("Map")
	assert(map, "Rode Build('base') primeiro")
	H.SetSeed(D.SEED + area.Id * 7919)

	local areasFolder = map.Areas
	local old = areasFolder:FindFirstChild(area.Folder)
	if old then
		old:Destroy()
	end
	local S = D.STYLE[area.Style]
	local c = area.C
	local folder = H.folder(area.Folder, areasFolder)
	folder:SetAttribute("AreaId", area.Id)
	folder:SetAttribute("Center", c)
	folder:SetAttribute("Size", D.AREA_SIZE)
	local roads = H.folder("Roads", folder)
	local buildings = H.folder("Buildings", folder)
	local restaurants = H.folder("Restaurants", folder)
	local customers = H.folder("Customers", folder)
	local obstacles = H.folder("Obstacles", folder)
	local hazards = H.folder("Perigos", obstacles)
	local obstacleFolders = {
		Obra = H.folder("Obras", obstacles), Desvio = H.folder("Desvios", obstacles), Rampa = H.folder("Rampas", obstacles),
		Cones = H.folder("ConeSpots", obstacles), Carro = H.folder("CarrosParados", obstacles), Espinhos = H.folder("Espinhos", obstacles),
		Bola = H.folder("Bolas", obstacles),
		Oleo = hazards, Buraco = hazards, Lombada = hazards, Lama = hazards, Hidrante = hazards, Radar = hazards,
	}
	local alleysFolder = H.folder("Becos", obstacles)
	local trafficFolder = H.folder("TrafficRoutes", obstacles)
	local limits = H.folder("RoadLimits", folder)
	local props = H.folder("StreetProps", folder)

	local toCenter = Vector3.new(-math.sign(c.X), 0, -math.sign(c.Z))
	local isOuter = area.Id ~= 1

	local xs = makeLines(-D.HALF, D.HALF, (area.Id == 1) and 0 or nil)
	local zs = makeLines(-D.HALF, D.HALF, (area.Id == 1) and 0 or nil)
	local nx, nz = #xs - 1, #zs - 1

	-- a rua de divisa com o Centro pertence ao Centro
	local function ownsV(i: number): boolean
		return not isOuter or not ((toCenter.X == -1 and i == 1) or (toCenter.X == 1 and i == #xs))
	end
	local function ownsH(j: number): boolean
		return not isOuter or not ((toCenter.Z == -1 and j == 1) or (toCenter.Z == 1 and j == #zs))
	end

	local candV, candH = {}, {}
	for i = 2, #xs - 1 do
		if not (area.Id == 1 and xs[i] == 0) then table.insert(candV, i) end
	end
	for j = 2, #zs - 1 do
		if not (area.Id == 1 and zs[j] == 0) then table.insert(candH, j) end
	end
	H.shuffle(candV)
	H.shuffle(candH)
	local trafficV, trafficH = {}, {}
	local nV = math.ceil(D.TRAFFIC_ROUTES_PER_AREA / 2)
	for n = 1, math.min(nV, #candV) do trafficV[candV[n]] = true end
	for n = 1, math.min(D.TRAFFIC_ROUTES_PER_AREA - nV, #candH) do trafficH[candH[n]] = true end

	local removedV, removedH, merged = {}, {}, {}
	for i = 2, #xs - 1 do
		if not trafficV[i] then
			for j = 1, nz do
				local a, b = (i - 1) .. ":" .. j, i .. ":" .. j
				local mid = Vector3.new(xs[i], 0, (zs[j] + zs[j + 1]) / 2)
				if not merged[a] and not merged[b] and not (area.Id == 1 and mid.Magnitude < 300) and H.rng:NextNumber() < D.MERGE_CHANCE then
					removedV[i .. ":" .. j] = true
					merged[a], merged[b] = true, true
				end
			end
		end
	end
	for j = 2, #zs - 1 do
		if not trafficH[j] then
			for i = 1, nx do
				local a, b = i .. ":" .. (j - 1), i .. ":" .. j
				local mid = Vector3.new((xs[i] + xs[i + 1]) / 2, 0, zs[j])
				if not merged[a] and not merged[b] and not (area.Id == 1 and mid.Magnitude < 300) and H.rng:NextNumber() < D.MERGE_CHANCE then
					removedH[j .. ":" .. i] = true
					merged[a], merged[b] = true, true
				end
			end
		end
	end

	local function lineIsFull(removed, k, count)
		for n = 1, count do
			if removed[k .. ":" .. n] then return false end
		end
		return true
	end
	local extraRoutes = 0
	for n = nV + 1, #candV do
		if extraRoutes >= math.ceil(D.EXTRA_TRAFFIC_ROUTES / 2) then break end
		local i = candV[n]
		if lineIsFull(removedV, i, nz) then
			trafficV[i] = true
			extraRoutes += 1
		end
	end
	for n = D.TRAFFIC_ROUTES_PER_AREA - nV + 1, #candH do
		if extraRoutes >= D.EXTRA_TRAFFIC_ROUTES then break end
		local j = candH[n]
		if lineIsFull(removedH, j, nx) then
			trafficH[j] = true
			extraRoutes += 1
		end
	end

	local segments = {}
	local ASPHALT, YELLOW_LINE = Color3.fromRGB(52, 52, 58), Color3.fromRGB(245, 205, 50)
	local function buildRun(vertical: boolean, k: number, s0: number, s1: number)
		local a, b
		if vertical then
			a, b = Vector3.new(c.X + k, 0, c.Z + s0), Vector3.new(c.X + k, 0, c.Z + s1)
		else
			a, b = Vector3.new(c.X + s0, 0, c.Z + k), Vector3.new(c.X + s1, 0, c.Z + k)
		end
		local unit = (b - a).Unit
		-- ruas no eixo X ficam 0,08 abaixo das do eixo Z: no cruzamento elas não disputam o mesmo plano (cintilação)
		strip(roads, "Road", a - unit * W / 2, b + unit * W / 2, W, 0.1, vertical and 0.15 or 0.07, ASPHALT, Enum.Material.Asphalt, false)
		strip(roads, "CenterLine", a + unit * W / 2, b - unit * W / 2, 0.8, 0.05, 0.22, YELLOW_LINE, H.SP, false)
	end
	for i = 1, #xs do
		if ownsV(i) then
			local runStart = nil
			for j = 1, nz + 1 do
				local kept = j <= nz and not removedV[i .. ":" .. j]
				if kept then
					runStart = runStart or j
					segments["V:" .. i .. ":" .. j] = {
						Center = Vector3.new(c.X + xs[i], 0, c.Z + (zs[j] + zs[j + 1]) / 2), Axis = Vector3.new(0, 0, 1),
						Length = zs[j + 1] - zs[j], Traffic = trafficV[i] == true,
					}
				elseif runStart then
					buildRun(true, xs[i], zs[runStart], zs[j])
					runStart = nil
				end
			end
		end
	end
	for j = 1, #zs do
		if ownsH(j) then
			local runStart = nil
			for i = 1, nx + 1 do
				local kept = i <= nx and not removedH[j .. ":" .. i]
				if kept then
					runStart = runStart or i
					segments["H:" .. j .. ":" .. i] = {
						Center = Vector3.new(c.X + (xs[i] + xs[i + 1]) / 2, 0, c.Z + zs[j]), Axis = Vector3.new(1, 0, 0),
						Length = xs[i + 1] - xs[i], Traffic = trafficH[j] == true,
					}
				elseif runStart then
					buildRun(false, zs[j], xs[runStart], xs[i])
					runStart = nil
				end
			end
		end
	end

	-- posição numa rua principal -> chave do trecho (para reservar os trechos com Pad)
	local function segmentKeyAt(p: Vector3): string?
		local lx, lz = p.X - c.X, p.Z - c.Z
		for i = 1, #xs do
			if math.abs(lx - xs[i]) <= W / 2 then
				for j = 1, nz do
					if lz >= zs[j] and lz < zs[j + 1] then return "V:" .. i .. ":" .. j end
				end
			end
		end
		for j = 1, #zs do
			if math.abs(lz - zs[j]) <= W / 2 then
				for i = 1, nx do
					if lx >= xs[i] and lx < xs[i + 1] then return "H:" .. j .. ":" .. i end
				end
			end
		end
		return nil
	end

	local rects, done = {}, {}
	for i = 1, nx do
		for j = 1, nz do
			local key = i .. ":" .. j
			if not done[key] then
				local x0, x1, z0, z1 = xs[i], xs[i + 1], zs[j], zs[j + 1]
				if removedV[(i + 1) .. ":" .. j] then
					x1 = xs[i + 2]
					done[(i + 1) .. ":" .. j] = true
				elseif removedH[(j + 1) .. ":" .. i] then
					z1 = zs[j + 2]
					done[i .. ":" .. (j + 1)] = true
				end
				done[key] = true
				table.insert(rects, {
					x0 = c.X + x0 + W / 2, x1 = c.X + x1 - W / 2, z0 = c.Z + z0 + W / 2, z1 = c.Z + z1 - W / 2,
					edgeCenter = isOuter and ((toCenter.X == -1 and x0 == -D.HALF) or (toCenter.X == 1 and x1 == D.HALF)
						or (toCenter.Z == -1 and z0 == -D.HALF) or (toCenter.Z == 1 and z1 == D.HALF)),
				})
			end
		end
	end

	local subBlocks = {}
	local alleyCount = 0
	for _, r in ipairs(rects) do
		local iw, id = r.x1 - r.x0, r.z1 - r.z0
		local big = math.max(iw, id)
		if big >= D.ALLEY_MIN_SIZE and H.rng:NextNumber() < D.ALLEY_CHANCE then
			alleyCount += 1
			local A = D.ALLEY_W
			if iw >= id then
				local mx = math.round((r.x0 + r.x1) / 2)
				table.insert(subBlocks, { x0 = r.x0, x1 = mx - A / 2, z0 = r.z0, z1 = r.z1, alley = { ["+X"] = true }, edgeCenter = r.edgeCenter })
				table.insert(subBlocks, { x0 = mx + A / 2, x1 = r.x1, z0 = r.z0, z1 = r.z1, alley = { ["-X"] = true }, edgeCenter = r.edgeCenter })
				local ac = Vector3.new(mx, 0, (r.z0 + r.z1) / 2)
				H.deco(roads, "Alley", Vector3.new(A, 0.1, id + 1), CFrame.new(ac.X, 0.01, ac.Z), Color3.fromRGB(78, 76, 74), Enum.Material.Concrete)
				Obstacles.Beco(alleysFolder, ac, Vector3.new(0, 0, 1), id)
			else
				local mz = math.round((r.z0 + r.z1) / 2)
				table.insert(subBlocks, { x0 = r.x0, x1 = r.x1, z0 = r.z0, z1 = mz - A / 2, alley = { ["+Z"] = true }, edgeCenter = r.edgeCenter })
				table.insert(subBlocks, { x0 = r.x0, x1 = r.x1, z0 = mz + A / 2, z1 = r.z1, alley = { ["-Z"] = true }, edgeCenter = r.edgeCenter })
				local ac = Vector3.new((r.x0 + r.x1) / 2, 0, mz)
				H.deco(roads, "Alley", Vector3.new(iw + 1, 0.1, A), CFrame.new(ac.X, 0.01, ac.Z), Color3.fromRGB(78, 76, 74), Enum.Material.Concrete)
				Obstacles.Beco(alleysFolder, ac, Vector3.new(1, 0, 0), iw)
			end
		else
			r.alley = {}
			table.insert(subBlocks, r)
		end
	end

	local lots = {}
	local rectStrings = {}
	local sidewalkColor = Color3.fromRGB(196, 192, 184)
	for _, sb in ipairs(subBlocks) do
		local iw, id = sb.x1 - sb.x0, sb.z1 - sb.z0
		local cx, cz = (sb.x0 + sb.x1) / 2, (sb.z0 + sb.z1) / 2
		H.deco(buildings, "Sidewalk", Vector3.new(iw, 0.3, id), CFrame.new(cx, 0.15, cz), sidewalkColor, Enum.Material.Concrete)
		H.deco(buildings, "Lot", Vector3.new(iw - D.SIDEWALK_W * 2, 0.32, id - D.SIDEWALK_W * 2), CFrame.new(cx, 0.16, cz), S.Lot, S.LotMat)
		table.insert(rectStrings, string.format("%d,%d,%d,%d", math.round(sb.x0), math.round(sb.z0), math.round(sb.x1), math.round(sb.z1)))

		local nxl = math.max(1, math.floor((iw + D.LOT_GAP) / (D.LOT + D.LOT_GAP)))
		local nzl = math.max(1, math.floor((id + D.LOT_GAP) / (D.LOT + D.LOT_GAP)))
		for a = 0, nxl - 1 do
			for b = 0, nzl - 1 do
				local x = (nxl == 1) and cx or (sb.x0 + D.LOT / 2 + a * (iw - D.LOT) / (nxl - 1))
				local z = (nzl == 1) and cz or (sb.z0 + D.LOT / 2 + b * (id - D.LOT) / (nzl - 1))
				local options = {}
				local function add(dir: Vector3, key: string, dist: number)
					if not sb.alley[key] and not (sb.edgeCenter and dir == toCenter) then
						table.insert(options, { Dir = dir, Dist = dist })
					end
				end
				if a == 0 then add(Vector3.new(-1, 0, 0), "-X", x - sb.x0) end
				if a == nxl - 1 then add(Vector3.new(1, 0, 0), "+X", sb.x1 - x) end
				if b == 0 then add(Vector3.new(0, 0, -1), "-Z", z - sb.z0) end
				if b == nzl - 1 then add(Vector3.new(0, 0, 1), "+Z", sb.z1 - z) end
				table.insert(lots, { Center = Vector3.new(x, 0, z), Options = options })
			end
		end
	end
	folder:SetAttribute("BlockRects", table.concat(rectStrings, ";"))

	if area.Id == 1 then
		local best, bestD
		for _, lot in ipairs(lots) do
			local d = lot.Center.Magnitude
			if not bestD or d < bestD then best, bestD = lot, d end
		end
		best.Plaza = true
	end

	H.shuffle(lots)
	local placed = {}
	for _, spacing in ipairs({ D.RESTAURANT_SPACING, 160 }) do
		for _, lot in ipairs(lots) do
			if #placed >= D.RESTAURANTS_PER_AREA then break end
			if not lot.Role and not lot.Plaza and #lot.Options > 0 then
				local ok = true
				for _, r in ipairs(placed) do
					if (r.Center - lot.Center).Magnitude < spacing then ok = false break end
				end
				if ok then
					lot.Role = "R"
					table.insert(placed, lot)
				end
			end
		end
	end
	local nCustomers = 0
	for _, lot in ipairs(lots) do
		if nCustomers >= D.CUSTOMERS_PER_AREA then break end
		if not lot.Role and not lot.Plaza and #lot.Options > 0 then
			lot.Role = "C"
			nCustomers += 1
		end
	end

	local reserved = {}
	local usedNames = {}
	local rIdx, cIdx = 0, 0
	local mainRng = H.rng
	-- cada lote usa um sorteio próprio: mudar um prédio não altera o resto da cidade
	local function withLotRng(lot, fn, ...)
		H.rng = Random.new((D.SEED * 7 + math.floor(lot.Center.X) * 131 + math.floor(lot.Center.Z) * 977) % 2147483647)
		fn(...)
		H.rng = mainRng
	end
	for _, lot in ipairs(lots) do
		local choice = #lot.Options > 0 and lot.Options[H.rng:NextInteger(1, #lot.Options)] or nil
		local dir = choice and choice.Dir or nil
		if lot.Role and choice then
			H.PAD_OFFSET = choice.Dist + LANE
			local padPos = lot.Center + choice.Dir * H.PAD_OFFSET
			if lot.Role == "R" then
				rIdx += 1
				local name, food = D.RestaurantInfo(area, rIdx, usedNames)
				withLotRng(lot, Restaurants.Build, restaurants, area.Style, S, lot.Center, choice.Dir, name, food)
			else
				cIdx += 1
				local index = (area.Id - 1) * D.CUSTOMERS_PER_AREA + cIdx
				local first = D.FIRST_NAMES[((index - 1) % #D.FIRST_NAMES) + 1]
				local display = first .. " " .. H.pick(D.SURNAMES)
				withLotRng(lot, Blocks.Customer, customers, area.Style, S, lot.Center, choice.Dir, display)
			end
			local key = segmentKeyAt(padPos)
			if key then
				reserved[key] = reserved[key] or {}
				table.insert(reserved[key], padPos)
			end
		elseif lot.Plaza then
			withLotRng(lot, Blocks.Decor, buildings, area.Style, S, lot.Center, true, dir)
		elseif H.rng:NextNumber() < D.EMPTY_LOT_CHANCE then
			withLotRng(lot, Blocks.Empty, buildings, area.Style, S, lot.Center, dir)
		else
			withLotRng(lot, Blocks.Decor, buildings, area.Style, S, lot.Center, false, dir)
		end
	end

	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local pos = Vector3.new(c.X + xs[i] + W / 2 + D.SIDEWALK_W / 2, 0, c.Z + zs[j] + W / 2 + D.SIDEWALK_W / 2)
			H.cylV(props, "LampPole", CFrame.new(pos.X, 0.3, pos.Z), 14, 0.5, Color3.fromRGB(60, 62, 70), Enum.Material.Metal, false)
			local head = pos + Vector3.new(-2, 14.3, -2)
			H.deco(props, "LampHead", Vector3.new(1.4, 0.6, 3.6), CFrame.lookAt(head, head + Vector3.new(-1, 0, -1)), Color3.fromRGB(255, 236, 180), Enum.Material.Neon)
			if i > 1 and not removedV[i .. ":" .. j] and H.rng:NextNumber() < 0.3 then
				local hp = Vector3.new(c.X + xs[i] - W / 2 - D.SIDEWALK_W / 2, 0.3, c.Z + zs[j] + W / 2 + 6)
				Obstacles.HydrantModel(props, hp, Vector3.new(1, 0, 0))
			end
		end
	end

	for i in pairs(trafficV) do
		Obstacles.TrafficRoute(trafficFolder, Vector3.new(c.X + xs[i], 0, c.Z - D.HALF), Vector3.new(c.X + xs[i], 0, c.Z + D.HALF))
	end
	for j in pairs(trafficH) do
		Obstacles.TrafficRoute(trafficFolder, Vector3.new(c.X - D.HALF, 0, c.Z + zs[j]), Vector3.new(c.X + D.HALF, 0, c.Z + zs[j]))
	end

	local keys = {}
	for key in pairs(segments) do table.insert(keys, key) end
	table.sort(keys)
	local counts = {}
	for _, name in ipairs(D.OBSTACLE_ORDER) do counts[name] = 0 end
	-- sorteio ponderado numa lista (pesos somando 1)
	local function pickWeighted(order, weights)
		local r = H.rng:NextNumber()
		local acc = 0
		for _, name in ipairs(order) do
			acc += weights[name]
			if r < acc then return name end
		end
		return order[#order]
	end
	local function place(kind, seg)
		Obstacles[kind](obstacleFolders[kind], seg)
		counts[kind] += 1
	end
	-- "trecho falso" centrado a d studs do meio: o obstáculo fica exatamente ali (perto de uma ponta)
	local function endSeg(seg, d, sign)
		return { Center = seg.Center + seg.Axis * d * sign, Axis = seg.Axis, Length = W + 12 }
	end
	-- distância (até o meio da vaga) para cada tipo caber antes do cruzamento
	local function endDistance(kind, seg)
		if kind == "Rampa" then return seg.Length / 2 - W / 2 - 30 end
		if kind == "Espinhos" then return seg.Length / 2 - W / 2 - 16 end
		return seg.Length / 2 - W / 2 - 20
	end
	local function farFromPads(key, pos)
		for _, pad in ipairs(reserved[key] or {}) do
			if (Vector3.new(pad.X, 0, pad.Z) - pos).Magnitude < D.PAD_CLEARANCE then return false end
		end
		return true
	end

	for _, key in ipairs(keys) do
		local seg = segments[key]
		if not (area.Id == 1 and seg.Center.Magnitude < 250) then
			local mainKind = nil
			if seg.Traffic then
				if not reserved[key] and H.rng:NextNumber() < D.TRAFFIC_HAZARD_CHANCE then
					mainKind = pickWeighted(D.FLAT_ORDER, D.FLAT_WEIGHTS)
					place(mainKind, seg)
				end
			elseif not reserved[key] then
				local r = H.rng:NextNumber()
				local acc = 0
				for _, name in ipairs(D.OBSTACLE_ORDER) do
					acc += D.OBSTACLE_CHANCE[name]
					if r < acc then mainKind = name break end
				end
				if mainKind == "Obra" and counts.Obra >= D.MAX_OBRAS_PER_AREA then mainKind = "Desvio" end
				if mainKind == "Bola" and counts.Bola >= D.MAX_BOLAS_PER_AREA then mainKind = "Lombada" end
				if mainKind then place(mainKind, seg) end
			end
			if mainKind ~= "Carro" and seg.Length >= D.END_MIN_LENGTH then
				for _, sign in ipairs({ -1, 1 }) do
					local chance = seg.Traffic and D.TRAFFIC_END_CHANCE or D.END_CHANCE
					if H.rng:NextNumber() < chance then
						local kind
						if seg.Traffic then
							kind = pickWeighted(D.FLAT_ORDER, D.FLAT_WEIGHTS)
							if kind == "Radar" then kind = "Lombada" end
						else
							kind = pickWeighted(D.END_ORDER, D.END_WEIGHTS)
							if kind == "Rampa" and seg.Length < D.EXTRA_RAMP_MIN_LENGTH then kind = "Espinhos" end
						end
						local s = endSeg(seg, endDistance(kind, seg), sign)
						if farFromPads(key, s.Center) then
							place(kind, s)
						end
					end
				end
			end
		end
	end

	local function sharedEdge(dx, dz): boolean
		local neighbor = c + Vector3.new(dx, 0, dz) * D.AREA_SIZE
		for _, other in ipairs(D.AREAS) do
			if (other.C - neighbor).Magnitude < 1 then return true end
		end
		return false
	end
	local edgeOff = D.HALF + W / 2 + 1
	for _, e in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		if not sharedEdge(e[1], e[2]) then
			local a, b
			if e[1] ~= 0 then
				a, b = Vector3.new(c.X + e[1] * edgeOff, 0, c.Z - edgeOff), Vector3.new(c.X + e[1] * edgeOff, 0, c.Z + edgeOff)
			else
				a, b = Vector3.new(c.X - edgeOff, 0, c.Z + e[2] * edgeOff), Vector3.new(c.X + edgeOff, 0, c.Z + e[2] * edgeOff)
			end
			for _, p in ipairs(strip(limits, "EdgeLimit", a, b, 2, 60, 30, H.WHITE, nil, true)) do
				p.Transparency = 1
				p.CanQuery = false
				p.CanTouch = false
			end
		end
	end

	if isOuter then
		local barrier = Instance.new("Model")
		barrier.Name = "Barrier"
		barrier.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local outer, inner = D.HALF + W / 2 + 1, D.HALF - W / 2 - 1
		local xmin, xmax, zmin, zmax = c.X - outer, c.X + outer, c.Z - outer, c.Z + outer
		if toCenter.X == 1 then xmax = c.X + inner elseif toCenter.X == -1 then xmin = c.X - inner end
		if toCenter.Z == 1 then zmax = c.Z + inner elseif toCenter.Z == -1 then zmin = c.Z - inner end
		for _, w in ipairs({
			{ Vector3.new(xmin, 0, zmin), Vector3.new(xmax, 0, zmin) }, { Vector3.new(xmin, 0, zmax), Vector3.new(xmax, 0, zmax) },
			{ Vector3.new(xmin, 0, zmin), Vector3.new(xmin, 0, zmax) }, { Vector3.new(xmax, 0, zmin), Vector3.new(xmax, 0, zmax) },
		}) do
			for _, p in ipairs(strip(barrier, "Wall", w[1], w[2], 2, 16, 8, Color3.fromRGB(255, 60, 60), H.SP, false)) do
				p.Transparency = 1
				p.CastShadow = false
			end
		end
		local signPos = Vector3.new(
			toCenter.X == 1 and xmax or (toCenter.X == -1 and xmin or c.X), 12,
			toCenter.Z == 1 and zmax or (toCenter.Z == -1 and zmin or c.Z))
		local sign = H.deco(barrier, "Sign", Vector3.new(1, 1, 1), CFrame.new(signPos), H.WHITE)
		sign.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Name = "LockLabel"
		bb.Size = UDim2.fromOffset(300, 70)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		bb.MaxDistance = 600
		bb.LightInfluence = 0
		bb.Enabled = false
		bb.Parent = sign
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.15
		label.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = "🔒 " .. area.Name
		label.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.15, 0)
		corner.Parent = label
		barrier.Parent = folder
	end

	local parts = {}
	for _, name in ipairs(D.OBSTACLE_ORDER) do
		if counts[name] > 0 then table.insert(parts, name .. " " .. counts[name]) end
	end
	local removed = 0
	for _ in pairs(removedV) do removed += 1 end
	for _ in pairs(removedH) do removed += 1 end
	return string.format("%s: %d peças | ruas %dx%d, %d superquarteirões, %d becos | %d restaurantes, %d clientes | %s",
		area.Name, countParts(folder), #xs, #zs, removed, alleyCount, rIdx, cIdx, table.concat(parts, ", "))
end

-- Ruas do bairro como texto no atributo "RoadLines" ("eixoX,coord,de,ate,largura,beco;..."): atributos chegam
-- sempre ao cliente, já as peças das ruas longe da moto não (streaming). A trilha (RouteGuide) usa isto.
function MapBuilder.WriteRoadLines(folder: Instance): number
	local entries = {}
	local roads = folder:FindFirstChild("Roads")
	for _, p in ipairs(roads and roads:GetChildren() or {}) do
		if p:IsA("BasePart") and (p.Name == "Road" or p.Name == "Alley") then
			local alongX = p.Size.X >= p.Size.Z
			local len = alongX and p.Size.X or p.Size.Z
			local mid = alongX and p.Position.X or p.Position.Z
			table.insert(entries, string.format("%d,%g,%g,%g,%g,%d", alongX and 1 or 0, alongX and p.Position.Z or p.Position.X,
				mid - len / 2, mid + len / 2, alongX and p.Size.Z or p.Size.X, p.Name == "Alley" and 1 or 0))
		end
	end
	folder:SetAttribute("RoadLines", table.concat(entries, ";"))
	return #entries
end

-- Depois de gerar a área: toda rua precisa de uma faixa livre (sem subir na calçada) e o cliente recebe os bloqueios
local function buildAreaWithPassage(area): string
	local result = buildArea(area)
	local folder = Workspace.Map.Areas:FindFirstChild(area.Folder)
	if folder then
		Passagem.Fix(folder)
		Passagem.WriteBlockers(folder)
		MapBuilder.WriteRoadLines(folder)
		-- janelas nas fachadas, faixas de pedestre, linha amarela que para no cruzamento, calçada e meio-fio
		local Acabamento = require(script.Acabamento)
		Acabamento.Fachadas(folder)
		Acabamento.Ruas(folder)
		Acabamento.Casas(folder)
	end
	return result
end

function MapBuilder.Build(stage)
	if stage == nil or stage == "all" then
		local out = { buildBase() }
		for _, area in ipairs(D.AREAS) do
			table.insert(out, buildAreaWithPassage(area))
		end
		return table.concat(out, "\n")
	end
	if stage == "base" then
		return buildBase()
	end
	local area = D.AREAS[stage]
	assert(area, "Estágio inválido: use 'base' ou 1.." .. #D.AREAS)
	return buildAreaWithPassage(area)
end

return MapBuilder
