-- Rede de ruas a partir do atributo "RoadLines" de cada bairro: menor caminho pelas ruas.
-- Usada pela trilha no chão (cliente) e pelo prazo dos pedidos (servidor). Atributos chegam mesmo com streaming.

local RoadGraph = {}

local ALLEY_COST = 1.6 -- beco só entra na rota se compensar bem
local cache = {}

local function build(areasFolder: Instance, allowed)
	local lines = {}
	for _, area in ipairs(areasFolder:GetChildren()) do
		local text = allowed[area:GetAttribute("AreaId")] and area:GetAttribute("RoadLines")
		for ax, coord, lo, hi, width, alley in string.gmatch(type(text) == "string" and text or "", "([01]),([^,]+),([^,]+),([^,]+),([^,]+),([01])") do
			local alongX = ax == "1"
			coord = tonumber(coord)
			local key = (alongX and "x" or "z") .. math.round(coord)
			local line = lines[key]
			if not line then
				line = { AlongX = alongX, Coord = coord, Width = 0, Alley = true, Spans = {} }
				lines[key] = line
			end
			line.Width = math.max(line.Width, tonumber(width))
			line.Alley = line.Alley and alley == "1"
			table.insert(line.Spans, { tonumber(lo), tonumber(hi) })
		end
	end

	-- trechos na mesma linha se juntam
	local segments = {}
	for _, line in pairs(lines) do
		table.sort(line.Spans, function(a, b)
			return a[1] < b[1]
		end)
		local cur = nil
		for _, span in ipairs(line.Spans) do
			if cur and span[1] <= cur.B + 1 then
				cur.B = math.max(cur.B, span[2])
			else
				cur = { AlongX = line.AlongX, Coord = line.Coord, Width = line.Width, Alley = line.Alley, A = span[1], B = span[2], Nodes = {} }
				table.insert(segments, cur)
			end
		end
	end

	local nodes, index = {}, {}
	local function nodeAt(x: number, z: number): number
		local key = math.round(x) .. "," .. math.round(z)
		local id = index[key]
		if not id then
			id = #nodes + 1
			nodes[id] = { Pos = Vector3.new(x, 0, z), Edges = {} }
			index[key] = id
		end
		return id
	end
	-- cruzamentos (a rua que termina na borda da outra também conta)
	for _, a in ipairs(segments) do
		if a.AlongX then
			for _, b in ipairs(segments) do
				if not b.AlongX then
					local x, z = b.Coord, a.Coord
					if x >= a.A - b.Width / 2 - 1 and x <= a.B + b.Width / 2 + 1 and z >= b.A - a.Width / 2 - 1 and z <= b.B + a.Width / 2 + 1 then
						local id = nodeAt(x, z)
						table.insert(a.Nodes, { T = x, Id = id })
						table.insert(b.Nodes, { T = z, Id = id })
					end
				end
			end
		end
	end
	for _, s in ipairs(segments) do
		for _, t in ipairs({ s.A, s.B }) do
			table.insert(s.Nodes, { T = t, Id = nodeAt(s.AlongX and t or s.Coord, s.AlongX and s.Coord or t) })
		end
		table.sort(s.Nodes, function(a, b)
			return a.T < b.T
		end)
		local k = s.Alley and ALLEY_COST or 1
		for i = 2, #s.Nodes do
			local u, v = s.Nodes[i - 1], s.Nodes[i]
			if u.Id ~= v.Id then
				local cost = (v.T - u.T) * k
				table.insert(nodes[u.Id].Edges, { v.Id, cost })
				table.insert(nodes[v.Id].Edges, { u.Id, cost })
			end
		end
	end
	return { Segments = segments, Nodes = nodes }
end

-- grafo dos bairros permitidos ({ [areaId] = true }), guardado em cache
function RoadGraph.Get(areasFolder: Instance, allowed)
	local ids = {}
	for id in pairs(allowed) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local key = table.concat(ids, ",")
	if not cache[key] then
		cache[key] = build(areasFolder, allowed)
	end
	return cache[key]
end

local function segPoint(s, t: number): Vector3
	return s.AlongX and Vector3.new(t, 0, s.Coord) or Vector3.new(s.Coord, 0, t)
end

-- ponto da rede mais perto de pos (beco só se estiver bem mais perto)
local function project(graph, pos: Vector3)
	local best, bestT, bestD = nil, 0, math.huge
	for _, s in ipairs(graph.Segments) do
		local along = s.AlongX and pos.X or pos.Z
		local across = s.AlongX and pos.Z or pos.X
		local t = math.clamp(along, s.A, s.B)
		local d = math.sqrt((along - t) ^ 2 + (across - s.Coord) ^ 2) * (s.Alley and 1.5 or 1)
		if d < bestD then
			best, bestT, bestD = s, t, d
		end
	end
	return best, bestT
end

-- Menor caminho (Dijkstra com heap) de from até to. Retorna a lista de pontos (no chão) ou nil.
-- Pontos temporários: 0 = início, -1 = fim.
function RoadGraph.Route(graph, from: Vector3, to: Vector3)
	local nodes = graph.Nodes
	local sa, ta = project(graph, from)
	local sb, tb = project(graph, to)
	if not sa or not sb then
		return nil
	end
	local extra = { [0] = {}, [-1] = {} }
	local function link(temp: number, s, t: number)
		local before, after = nil, nil
		for _, n in ipairs(s.Nodes) do
			if n.T <= t then
				before = n
			end
			if n.T >= t and not after then
				after = n
			end
		end
		local k = s.Alley and ALLEY_COST or 1
		for _, n in ipairs({ before, after }) do
			if n then
				local cost = math.abs(n.T - t) * k
				table.insert(extra[temp], { n.Id, cost })
				extra[n.Id] = extra[n.Id] or {}
				table.insert(extra[n.Id], { temp, cost })
			end
		end
	end
	link(0, sa, ta)
	link(-1, sb, tb)
	if sa == sb then
		table.insert(extra[0], { -1, math.abs(tb - ta) })
	end

	local dist, prev = { [0] = 0 }, {}
	local heap = { { 0, 0 } }
	local function push(d: number, id: number)
		table.insert(heap, { d, id })
		local i = #heap
		while i > 1 do
			local p = i // 2
			if heap[p][1] <= heap[i][1] then
				break
			end
			heap[p], heap[i] = heap[i], heap[p]
			i = p
		end
	end
	local function pop()
		local top = heap[1]
		local last = table.remove(heap)
		if #heap > 0 then
			heap[1] = last
			local i = 1
			while true do
				local l, r, m = i * 2, i * 2 + 1, i
				if heap[l] and heap[l][1] < heap[m][1] then
					m = l
				end
				if heap[r] and heap[r][1] < heap[m][1] then
					m = r
				end
				if m == i then
					break
				end
				heap[m], heap[i] = heap[i], heap[m]
				i = m
			end
		end
		return top[1], top[2]
	end
	local function relax(d: number, u: number, list)
		for _, e in ipairs(list) do
			local v, nd = e[1], d + e[2]
			if nd < (dist[v] or math.huge) then
				dist[v], prev[v] = nd, u
				push(nd, v)
			end
		end
	end
	while #heap > 0 do
		local d, u = pop()
		if u == -1 then
			break
		end
		if d <= (dist[u] or math.huge) then
			if u > 0 then
				relax(d, u, nodes[u].Edges)
			end
			if extra[u] then
				relax(d, u, extra[u])
			end
		end
	end
	if dist[-1] == nil then
		return nil
	end

	local ids = {}
	local cur = -1
	while cur ~= nil do
		table.insert(ids, 1, cur)
		cur = prev[cur]
	end
	local points = {}
	local function add(p: Vector3)
		local last = points[#points]
		if not last or (last - p).Magnitude > 0.5 then
			table.insert(points, p)
		end
	end
	for _, id in ipairs(ids) do
		add(id == 0 and segPoint(sa, ta) or id == -1 and segPoint(sb, tb) or nodes[id].Pos)
	end
	add(Vector3.new(to.X, 0, to.Z))
	return points
end

-- comprimento (studs) do caminho pelas ruas de from até to, contando a ida da posição até a rua
function RoadGraph.Length(graph, from: Vector3, to: Vector3): number?
	local points = RoadGraph.Route(graph, from, to)
	if not points then
		return nil
	end
	local total = (points[1] - Vector3.new(from.X, 0, from.Z)).Magnitude
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

return RoadGraph
