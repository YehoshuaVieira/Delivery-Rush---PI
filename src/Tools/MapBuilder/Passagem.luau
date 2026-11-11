-- Garante que toda rua tenha uma faixa livre para passar sem subir na calçada (obstáculos físicos + perigos)
-- e grava os bloqueios físicos (Obstacles/Bloqueios) para o cliente não empilhar perigos dinâmicos neles.

local Passagem = {}

Passagem.MIN_GAP = 9 -- largura livre mínima (studs)
Passagem.STEER = 8 -- folga ao longo da rua para trocar de faixa
local EDGE = 1 -- margem do meio-fio
local STEP = 2

-- quem sai primeiro quando falta espaço (menor = sai antes)
local PRIORITY = { pothole = 1, mud = 2, water = 3, oil = 4, spike = 5, car = 6, desvio = 8, obra = 9 }
local VISUAL = { oil = "Oleo", mud = "Lama", pothole = "Buraco", water = "Hidrante", spike = "Espinhos" }

local function zoneHalf(axis: Vector3, hl: number, hw: number): (number, number)
	return math.abs(axis.X) * hl + math.abs(axis.Z) * hw, math.abs(axis.Z) * hl + math.abs(axis.X) * hw
end

local function partHalf(p: BasePart): (number, number)
	local r, s = p.CFrame, p.Size / 2
	local hx = math.abs(r.RightVector.X) * s.X + math.abs(r.UpVector.X) * s.Y + math.abs(r.LookVector.X) * s.Z
	local hz = math.abs(r.RightVector.Z) * s.X + math.abs(r.UpVector.Z) * s.Y + math.abs(r.LookVector.Z) * s.Z
	return hx, hz
end

-- Tudo que ocupa a pista numa área: { Kind, Min, Max (XZ), Data | Model, Container }
function Passagem.Footprints(area: Instance)
	local list = {}
	local obs = area:FindFirstChild("Obstacles")
	if not obs then
		return list
	end
	local function addZone(f: Instance, kind: string)
		local c, a = f:GetAttribute("Center"), f:GetAttribute("Axis")
		if typeof(c) ~= "Vector3" or typeof(a) ~= "Vector3" then
			return
		end
		local hx, hz = zoneHalf(a, f:GetAttribute("HalfLength") or 2, f:GetAttribute("HalfWidth") or 8)
		table.insert(list, { Kind = kind, Min = Vector2.new(c.X - hx, c.Z - hz), Max = Vector2.new(c.X + hx, c.Z + hz), Data = f, Center = c, Container = f.Parent })
	end
	for _, f in ipairs(obs:FindFirstChild("Perigos") and obs.Perigos:GetChildren() or {}) do
		if f.Name == "Hazard" and PRIORITY[f:GetAttribute("Type")] then
			addZone(f, f:GetAttribute("Type"))
		end
	end
	for _, f in ipairs(obs:FindFirstChild("Espinhos") and obs.Espinhos:GetChildren() or {}) do
		if f.Name == "SpikeStrip" then
			addZone(f, "spike")
		end
	end
	for folderName, kind in pairs({ Obras = "obra", Desvios = "desvio", CarrosParados = "car" }) do
		local folder = obs:FindFirstChild(folderName)
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:IsA("Model") then
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") and (p.CanCollide or kind == "car") and p.Transparency < 1 then
						local hx, hz = partHalf(p)
						local c = p.Position
						table.insert(list, { Kind = kind, Min = Vector2.new(c.X - hx, c.Z - hz), Max = Vector2.new(c.X + hx, c.Z + hz), Model = m })
					end
				end
			end
		end
	end
	return list
end

-- Ruas da área com o eixo ao longo do comprimento
function Passagem.Roads(area: Instance)
	local roads = {}
	local folder = area:FindFirstChild("Roads")
	for _, p in ipairs(folder and folder:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Name == "Road" then
			local alongX = p.Size.X > p.Size.Z
			table.insert(roads, {
				Center = p.Position, AlongX = alongX,
				HalfLen = (alongX and p.Size.X or p.Size.Z) / 2, HalfW = (alongX and p.Size.Z or p.Size.X) / 2,
			})
		end
	end
	return roads
end

-- Pedaço da pista ocupado por um item, em coordenadas da rua (u ao longo, v atravessando)
local function project(road, item)
	local c = road.Center
	local u0, u1, v0, v1
	if road.AlongX then
		u0, u1, v0, v1 = item.Min.X - c.X, item.Max.X - c.X, item.Min.Y - c.Z, item.Max.Y - c.Z
	else
		u0, u1, v0, v1 = item.Min.Y - c.Z, item.Max.Y - c.Z, item.Min.X - c.X, item.Max.X - c.X
	end
	if u1 < -road.HalfLen or u0 > road.HalfLen or v1 < -road.HalfW or v0 > road.HalfW then
		return nil
	end
	return { U0 = u0, U1 = u1, V0 = math.max(v0, -road.HalfW), V1 = math.min(v1, road.HalfW), Item = item }
end

-- Maior vão livre na largura da rua dados os intervalos bloqueados
function Passagem.LargestGap(intervals, halfW: number): number
	table.sort(intervals, function(a, b)
		return a[1] < b[1]
	end)
	local cursor, best = -halfW + EDGE, 0
	for _, iv in ipairs(intervals) do
		if iv[1] > cursor then
			best = math.max(best, iv[1] - cursor)
		end
		cursor = math.max(cursor, iv[2])
	end
	return math.max(best, (halfW - EDGE) - cursor)
end

-- Primeiro trecho da rua sem faixa livre: devolve os itens ativos ali (ou nil)
local function firstConflict(road, items)
	local fps = {}
	for _, item in ipairs(items) do
		if not item.Removed then
			local fp = project(road, item)
			if fp then
				table.insert(fps, fp)
			end
		end
	end
	if #fps < 2 then
		return nil
	end
	for u = -road.HalfLen, road.HalfLen, STEP do
		local intervals, active = {}, {}
		for _, fp in ipairs(fps) do
			if u >= fp.U0 - Passagem.STEER and u <= fp.U1 + Passagem.STEER then
				table.insert(intervals, { fp.V0, fp.V1 })
				table.insert(active, fp.Item)
			end
		end
		if #intervals > 0 and Passagem.LargestGap(intervals, road.HalfW) < Passagem.MIN_GAP then
			return active
		end
	end
	return nil
end

local function nearestVisual(container: Instance, name: string, center: Vector3)
	local best, bestD = nil, 26
	for _, m in ipairs(container:GetChildren()) do
		if m:IsA("Model") and m.Name == name then
			local cf = m:GetBoundingBox()
			local d = Vector2.new(cf.Position.X - center.X, cf.Position.Z - center.Z).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function removeItem(item, items)
	if item.Model then
		for _, other in ipairs(items) do
			if other.Model == item.Model then
				other.Removed = true
			end
		end
		item.Model:Destroy()
	else
		item.Removed = true
		local visual = VISUAL[item.Kind] and nearestVisual(item.Container, VISUAL[item.Kind], item.Center)
		if visual then
			visual:Destroy()
		end
		item.Data:Destroy()
	end
end

-- Remove o mínimo necessário (perigos antes de carros, carros antes de desvios/obras) até toda rua ter passagem
function Passagem.Fix(area: Instance)
	local items = Passagem.Footprints(area)
	local removed = {}
	for i, road in ipairs(Passagem.Roads(area)) do
		for _ = 1, 50 do
			local active = firstConflict(road, items)
			if not active then
				break
			end
			table.sort(active, function(a, b)
				return PRIORITY[a.Kind] < PRIORITY[b.Kind]
			end)
			local victim = active[1]
			removed[victim.Kind] = (removed[victim.Kind] or 0) + 1
			removeItem(victim, items)
		end
		if i % 25 == 0 then
			task.wait()
		end
	end
	return removed
end

-- Conta trechos sem passagem (diagnóstico)
function Passagem.Count(area: Instance): number
	local items = Passagem.Footprints(area)
	local n = 0
	for _, road in ipairs(Passagem.Roads(area)) do
		if firstConflict(road, items) then
			n += 1
		end
	end
	return n
end

-- Bloqueios físicos (obra, desvio, carro parado) como pastas leves para o cliente
function Passagem.WriteBlockers(area: Instance): number
	local obs = area:FindFirstChild("Obstacles")
	if not obs then
		return 0
	end
	local old = obs:FindFirstChild("Bloqueios")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bloqueios"
	local n = 0
	for _, item in ipairs(Passagem.Footprints(area)) do
		if item.Model then
			local b = Instance.new("Folder")
			b.Name = "Blocker"
			local c = (item.Min + item.Max) / 2
			local h = (item.Max - item.Min) / 2
			b:SetAttribute("Center", Vector3.new(c.X, 0, c.Y))
			b:SetAttribute("Axis", Vector3.xAxis)
			b:SetAttribute("HalfLength", h.X)
			b:SetAttribute("HalfWidth", h.Y)
			b.Parent = folder
			n += 1
		end
	end
	folder.Parent = obs
	return n
end

return Passagem
