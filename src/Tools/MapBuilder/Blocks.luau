-- Quarteirões: clientes (com Pad), lotes decorativos e detalhes das construções.
local H = require(script.Parent.Helpers)
local D = require(script.Parent.Data)

local SP = H.SP
local at = H.at
local M = Enum.Material
local V3 = Vector3.new
local CF = CFrame.new

local NORTH = V3(0, 0, -1)
local DARKWIN = Color3.fromRGB(46, 60, 80)
local FRAME = Color3.fromRGB(245, 245, 240)
local STEEL = Color3.fromRGB(58, 60, 68)
local GRAYC = Color3.fromRGB(178, 174, 166)
local TANK_BLUE = Color3.fromRGB(38, 105, 185)
local GLASS_C = Color3.fromRGB(120, 160, 190)
local AWNINGS = { Color3.fromRGB(215, 45, 45), Color3.fromRGB(250, 195, 40), Color3.fromRGB(40, 115, 210), Color3.fromRGB(40, 150, 90), Color3.fromRGB(240, 120, 30) }
local SHUTTERS = { Color3.fromRGB(60, 110, 70), Color3.fromRGB(150, 70, 50), Color3.fromRGB(70, 90, 140), Color3.fromRGB(120, 85, 55) }
local DOORS = { Color3.fromRGB(110, 72, 45), Color3.fromRGB(80, 52, 34), Color3.fromRGB(150, 100, 60), Color3.fromRGB(60, 60, 66) }
local GATES = { Color3.fromRGB(60, 62, 68), Color3.fromRGB(235, 235, 232), Color3.fromRGB(110, 75, 50), Color3.fromRGB(40, 70, 110) }
local CLADDING = { Color3.fromRGB(70, 68, 66), Color3.fromRGB(120, 110, 100), Color3.fromRGB(165, 160, 150), Color3.fromRGB(90, 80, 72) }

local Blocks = {}

local function newLotModel(name)
	local m = Instance.new("Model")
	m.Name = name
	pcall(function()
		m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	return m
end

-- Fachadas de um volume (cx, cz, w, d) no referencial do lote.
local function faces(f, cx, cz, w, d)
	return {
		front = { F = at(f, cx, 0, cz + d / 2), W = w },
		right = { F = at(f, cx + w / 2, 0, cz) * CFrame.Angles(0, -math.pi / 2, 0), W = d },
		back = { F = at(f, cx, 0, cz - d / 2) * CFrame.Angles(0, math.pi, 0), W = w },
		left = { F = at(f, cx - w / 2, 0, cz) * CFrame.Angles(0, math.pi / 2, 0), W = d },
	}
end

local function body(parent, name, f, cx, cz, w, h, d, color, mat, y0)
	return H.block(parent, name, V3(w, h, d), at(f, cx, (y0 or 0) + h / 2, cz), color, mat, true)
end

-- Faixa de janelas por andar em volta do volume inteiro (1 peça por andar)
local function bands(parent, f, cx, cz, w, d, y0, floors, floorH, color, mat)
	for k = 1, floors do
		local y = y0 + (k - 1) * floorH + floorH * 0.55
		H.deco(parent, "Windows", V3(w + 0.3, floorH * 0.5, d + 0.3), at(f, cx, y, cz), color or DARKWIN, mat or M.Glass)
	end
end

-- Pilares (e peitoris) numa fachada: com as faixas formam a grade de janelas
local function facadeGrid(parent, face, y0, floors, floorH, color, sills, spacing)
	local width = face.W
	local n = math.max(2, math.floor(width / (spacing or 7)))
	local hTot = floors * floorH
	for i = 1, n - 1 do
		local x = -width / 2 + width * i / n
		H.deco(parent, "Pier", V3(0.9, hTot - 0.4, 0.5), face.F * CF(x, y0 + hTot / 2, -0.25), color, M.Concrete)
	end
	if sills then
		for k = 1, floors do
			H.deco(parent, "Sill", V3(width - 0.6, 0.3, 0.75), face.F * CF(0, y0 + (k - 1) * floorH + floorH * 0.3 - 0.15, -0.35), color, M.Concrete)
		end
	end
end

-- Aletas verticais (torres de vidro)
local function fins(parent, face, y0, height, count, color)
	for i = 1, count do
		local x = -face.W / 2 + face.W * i / (count + 1)
		H.deco(parent, "Aleta", V3(0.7, height, 1), face.F * CF(x, y0 + height / 2, -0.5), color, M.Metal)
	end
end

local function door(parent, face, x, w, h, color, mat, lamp)
	local F = face.F
	H.deco(parent, "DoorFrame", V3(w + 0.8, h + 0.4, 0.3), F * CF(x, (h + 0.4) / 2, -0.12), FRAME, SP)
	local d = H.deco(parent, "Door", V3(w, h, 0.35), F * CF(x, h / 2, -0.18), color, mat or M.Wood)
	H.deco(parent, "Step", V3(w + 2.4, 0.4, 1.6), F * CF(x, 0.2, -0.8), Color3.fromRGB(190, 188, 182), M.Concrete)
	if lamp then
		H.deco(parent, "WallLamp", V3(0.5, 0.8, 0.5), F * CF(x + w / 2 + 1.2, h - 0.3, -0.35), Color3.fromRGB(255, 225, 160), M.Neon)
	end
	return d
end

-- Janela com moldura, peitoril e (opcional) venezianas abertas
local function window(parent, face, x, y, w, h, shutterColor)
	local F = face.F
	H.deco(parent, "WindowFrame", V3(w + 0.6, h + 0.6, 0.22), F * CF(x, y, -0.08), FRAME, SP)
	H.deco(parent, "WindowGlass", V3(w, h, 0.26), F * CF(x, y, -0.12), DARKWIN, M.Glass)
	H.deco(parent, "WindowSill", V3(w + 1.2, 0.3, 0.7), F * CF(x, y - h / 2 - 0.45, -0.3), Color3.fromRGB(222, 216, 205), M.Concrete)
	if shutterColor then
		for _, s in ipairs({ -1, 1 }) do
			H.deco(parent, "Veneziana", V3(w / 2, h + 0.4, 0.2), F * CF(x + s * (w * 0.75 + 0.4), y, -0.15), shutterColor, M.WoodPlanks)
		end
	end
end

-- Varanda: laje + guarda-corpo (vidro ou mureta) + corrimão
local function balcony(parent, face, x, y, width, style)
	local F = face.F
	H.deco(parent, "Balcony", V3(width, 0.4, 2.6), F * CF(x, y, -1.3), Color3.fromRGB(215, 212, 205), M.Concrete)
	if style == "mureta" then
		H.deco(parent, "Mureta", V3(width, 1.2, 0.3), F * CF(x, y + 0.8, -2.45), Color3.fromRGB(240, 238, 232), M.Plaster)
	else
		local rail = H.deco(parent, "Railing", V3(width, 1.2, 0.12), F * CF(x, y + 0.8, -2.55), Color3.fromRGB(170, 200, 220), M.Glass)
		rail.Transparency = 0.45
		H.deco(parent, "Handrail", V3(width, 0.16, 0.25), F * CF(x, y + 1.45, -2.55), STEEL, M.Metal)
	end
end

-- Ar-condicionado split pendurado na fachada (bem brasileiro)
local function acUnit(parent, face, x, y)
	local F = face.F
	H.deco(parent, "ArCondicionado", V3(2.4, 1.5, 1), F * CF(x, y, -0.55), Color3.fromRGB(234, 234, 230), SP)
	H.deco(parent, "Ventoinha", V3(1.1, 1.1, 0.1), F * CF(x - 0.45, y, -1.07), Color3.fromRGB(120, 120, 124), M.Metal)
end

-- Loja no térreo: vitrine, porta de aço (às vezes meio baixada), toldo e letreiro
local function storefront(parent, face, x, sw, gh, name, opts)
	opts = opts or {}
	local F = face.F
	local gH = gh - 2.4
	local glass = H.deco(parent, "Vitrine", V3(sw - 1.2, gH, 0.2), F * CF(x, 0.4 + gH / 2, -0.1), GLASS_C, M.Glass)
	glass.Transparency = 0.2
	glass.Reflectance = 0.15
	H.deco(parent, "VitrineFrame", V3(sw - 0.4, 0.45, 0.4), F * CF(x, 0.4 + gH + 0.2, -0.2), STEEL, M.Metal)
	if opts.Shutter then
		local sh = gH * H.rng:NextNumber(0.3, 0.6)
		H.deco(parent, "PortaDeAco", V3(sw - 1.2, sh, 0.3), F * CF(x, 0.4 + gH - sh / 2, -0.3), Color3.fromRGB(160, 160, 165), M.CorrodedMetal)
	end
	H.deco(parent, "Toldo", V3(sw - 0.4, 0.25, 3.4), F * CF(x, gh - 1.2, -1.7) * CFrame.Angles(math.rad(-18), 0, 0), opts.Awning or H.pick(AWNINGS), M.Fabric)
	local sign = H.deco(parent, "Letreiro", V3(sw - 1, 1.7, 0.4), F * CF(x, opts.SignY or (gh + 0.2), -(opts.SignOut or 0.25)), opts.SignColor or Color3.fromRGB(30, 30, 36), SP)
	H.surfaceText(sign, Enum.NormalId.Front, name, opts.TextColor or H.WHITE)
end

-- Topo de prédio: platibanda, laje, caixa d'água azul e (opcional) casa de máquinas, antena e condensadoras
local function roofTop(parent, f, cx, cz, w, d, h, opts)
	opts = opts or {}
	H.deco(parent, "Platibanda", V3(w + 0.5, 1.4, d + 0.5), at(f, cx, h + 0.3, cz), opts.Rim or Color3.fromRGB(208, 204, 196), M.Concrete)
	H.deco(parent, "Laje", V3(w - 1.2, 0.2, d - 1.2), at(f, cx, h + 0.95, cz), Color3.fromRGB(118, 118, 122), M.Concrete)
	local top = h + 1
	local qx, qz = w / 4, d / 4
	local sx = (H.rng:NextNumber() < 0.5) and -1 or 1
	if opts.Tank ~= false then
		local tx, tz = cx + sx * qx, cz - qz
		H.deco(parent, "BaseCaixa", V3(6, 1, 6), at(f, tx, top + 0.5, tz), GRAYC, M.Concrete)
		H.cylV(parent, "CaixaDagua", at(f, tx, top + 1, tz), 3.6, 5, TANK_BLUE, SP, false)
		H.cylV(parent, "TampaCaixa", at(f, tx, top + 4.6, tz), 0.5, 5.4, Color3.fromRGB(70, 140, 215), SP, false)
	end
	if opts.Machine then
		H.deco(parent, "CasaDeMaquinas", V3(math.min(8, w / 3), 4.5, math.min(7, d / 3)), at(f, cx - sx * qx, top + 2.25, cz - qz), Color3.fromRGB(192, 188, 180), M.Concrete)
	end
	if opts.Antenna then
		H.cylV(parent, "Antena", at(f, cx - sx * qx, top, cz + qz), 9, 0.25, Color3.fromRGB(150, 150, 155), M.Metal, false)
	end
	for i = 1, opts.AC or 0 do
		H.deco(parent, "Condensadora", V3(3, 2, 2), at(f, cx + sx * (qx - 3) * ((i % 2 == 0) and 1 or 0.3), top + 1, cz + qz), Color3.fromRGB(215, 215, 212), M.Metal)
	end
end

-- Muro com portão (bem brasileiro). segs = { {x0, x1, tipo} }: tipo nil = muro, "gate" = portão, "garage" = portão da garagem
local function frontWall(parent, f, z, height, color, segs)
	for _, s in ipairs(segs) do
		local w = s[2] - s[1]
		local x = (s[1] + s[2]) / 2
		if s[3] == "gate" then
			local gate = H.deco(parent, "Portao", V3(w, height + 0.2, 0.25), at(f, x, (height + 0.2) / 2, z), Color3.fromRGB(45, 45, 50), M.Metal)
			gate.Transparency = 0.2
		elseif s[3] == "garage" then
			H.deco(parent, "PortaoGaragem", V3(w, height + 0.4, 0.3), at(f, x, (height + 0.4) / 2, z), H.pick(GATES), M.DiamondPlate)
		else
			H.block(parent, "Muro", V3(w, height, 0.6), at(f, x, height / 2, z), color, M.Plaster, true)
		end
	end
end

local function bench(parent, cf)
	H.deco(parent, "BenchSeat", V3(5, 0.4, 1.4), cf * CF(0, 1.4, 0), Color3.fromRGB(140, 95, 55), M.Wood)
	H.deco(parent, "BenchBack", V3(5, 1.4, 0.3), cf * CF(0, 2.3, 0.6), Color3.fromRGB(140, 95, 55), M.Wood)
end

local function lampPost(parent, pos)
	H.cylV(parent, "Poste", CF(pos.X, 0.3, pos.Z), 8, 0.35, STEEL, M.Metal, false)
	H.ball(parent, "Luminaria", CF(pos.X, 8.6, pos.Z), 1.3, Color3.fromRGB(255, 232, 170), M.Neon, false)
end

local function ground(parent, bc, color, mat)
	H.deco(parent, "Grass", V3(56, 0.35, 56), CF(bc.X, 0.2, bc.Z), color or Color3.fromRGB(110, 170, 90), mat or M.Grass)
end

-- Prédio de apartamentos (centro): térreo revestido, grade de janelas, varandas, ar-condicionado e telhado cheio de coisa
local function apartment(model, f, S, x0, w, d, floors, rich)
	local gh, fh = 7, 5
	local h = gh + floors * fh
	local cz = 26 - d / 2
	local color = H.pick(S.Colors)
	local mat = H.pick({ M.Plaster, M.Plaster, M.Brick, M.Concrete })
	body(model, "Building", f, x0, cz, w, h, d, color, mat)
	H.deco(model, "Terreo", V3(w + 0.3, gh, d + 0.3), at(f, x0, gh / 2, cz), H.pick(CLADDING), H.pick({ M.CeramicTiles, M.Granite, M.Concrete }))
	H.deco(model, "Cinta", V3(w + 0.7, 0.6, d + 0.7), at(f, x0, gh + 0.1, cz), FRAME, M.Concrete)
	bands(model, f, x0, cz, w, d, gh, floors, fh)
	local fc = faces(f, x0, cz, w, d)
	local pier = color:Lerp(Color3.new(1, 1, 1), 0.45)
	facadeGrid(model, fc.front, gh, floors, fh, pier, rich)
	facadeGrid(model, fc.right, gh, floors, fh, pier, false, 10)
	facadeGrid(model, fc.left, gh, floors, fh, pier, false, 10)
	local bx = ((H.rng:NextNumber() < 0.5) and -1 or 1) * w / 4
	if rich or H.rng:NextNumber() < 0.5 then
		for k = 1, floors, 2 do
			balcony(model, fc.front, bx, gh + (k - 1) * fh + 0.2, w / 2 - 3, "vidro")
		end
	end
	local nAC = rich and H.rng:NextInteger(2, 3) or H.rng:NextInteger(0, 1)
	for _ = 1, nAC do
		acUnit(model, fc.front, -bx + H.rng:NextNumber(-3, 3), gh + (H.rng:NextInteger(1, floors) - 1) * fh + 0.9)
	end
	roofTop(model, f, x0, cz, w, d, h, { Machine = floors >= 6, Antenna = rich and H.rng:NextNumber() < 0.5 })
	return { Faces = fc, GH = gh, H = h, BX = bx }
end

-- Casa (térrea ou sobrado) com telhado de barro. (x0, z0) = centro da planta.
local function house(model, f, S, x0, z0, w, d, floors, opts)
	opts = opts or {}
	local fh = 7.5
	local h = floors * fh
	local rh = opts.RoofH or 5
	local color = opts.Color or H.pick(S.Colors)
	body(model, "House", f, x0, z0, w, h, d, color, M.Plaster)
	H.deco(model, "Rodape", V3(w + 0.3, 1, d + 0.3), at(f, x0, 0.5, z0), color:Lerp(Color3.new(0, 0, 0), 0.3), M.Plaster)
	H.gableRoof(model, at(f, x0, 0, z0).Position, f.LookVector, w, d, h, rh, H.pick(S.Roofs))
	local fc = faces(f, x0, z0, w, d)
	local shutter = (opts.Shutters ~= false and H.rng:NextNumber() < 0.6) and H.pick(SHUTTERS) or nil
	door(model, fc.front, opts.DoorX or 0, 3.6, 6.4, H.pick(DOORS), M.Wood, opts.Lamp ~= false)
	for _, x in ipairs(opts.Windows or { -w / 4 - 1, w / 4 + 1 }) do
		window(model, fc.front, x, 3.9, 4, 3.2, shutter)
	end
	if floors >= 2 then
		window(model, fc.front, -w / 4 - 1, fh + 3.9, 4, 3.2, shutter)
		balcony(model, fc.front, w / 4 + 1, fh + 0.2, 7, "mureta")
		H.deco(model, "PortaVaranda", V3(3.2, 5.6, 0.3), fc.front.F * CF(w / 4 + 1, fh + 3, -0.15), DARKWIN, M.Glass)
	end
	window(model, fc.right, 0, 3.9, 3.4, 3, nil)
	window(model, fc.left, 0, 3.9, 3.4, 3, nil)
	if opts.Tank ~= false then
		local tx, tz = x0 + w / 4, z0 - d / 4
		H.cylV(model, "CaixaDagua", at(f, tx, h + rh * 0.35, tz), 3.2, 4.4, TANK_BLUE, SP, false)
		H.cylV(model, "TampaCaixa", at(f, tx, h + rh * 0.35 + 3.2, tz), 0.45, 4.8, Color3.fromRGB(70, 140, 215), SP, false)
	end
	if opts.Dish then
		local dp = fc.right.F * CF(-d / 4, h - 1.2, -0.6)
		H.deco(model, "Parabolica", V3(0.25, 2.4, 2.4), dp * CFrame.Angles(0, math.rad(-60), math.rad(15)), Color3.fromRGB(230, 230, 235), SP)
	end
	return fc, h
end

-- Prédio comercial: loja no térreo, faixa de ACM colorido e andares de escritório
local function commercial(model, f, S, x0, w, d, floors, storeName, rich)
	local gh, fh = 7.5, 5
	local base = gh + 1.8
	local h = base + floors * fh
	local cz = 26 - d / 2
	local color = H.pick(S.Colors)
	body(model, "Building", f, x0, cz, w, h, d, color, H.pick({ M.Plaster, SP }))
	bands(model, f, x0, cz, w, d, base, floors, fh)
	local fc = faces(f, x0, cz, w, d)
	H.deco(model, "ACM", V3(w + 0.4, 2.2, 0.5), fc.front.F * CF(0, gh + 0.6, -0.3), color:Lerp(Color3.new(1, 1, 1), 0.25), M.Metal)
	facadeGrid(model, fc.front, base, floors, fh, color:Lerp(Color3.new(1, 1, 1), 0.6), rich, 6)
	storefront(model, fc.front, 0, w - 2, gh, storeName, { Shutter = H.rng:NextNumber() < 0.3, SignY = gh + 0.6, SignOut = 0.75 })
	if rich then
		local blade = H.deco(model, "LetreiroVertical", V3(0.6, 7, 3), fc.front.F * CF(w / 2 - 1.2, base + 4, -1.8), H.pick(AWNINGS), SP)
		H.surfaceText(blade, Enum.NormalId.Right, "ABERTO", H.WHITE)
		H.surfaceText(blade, Enum.NormalId.Left, "ABERTO", H.WHITE)
		for _ = 1, 2 do
			acUnit(model, fc.front, H.rng:NextNumber(-w / 2 + 4, w / 2 - 6), base + (H.rng:NextInteger(1, floors) - 1) * fh + 0.8)
		end
	end
	roofTop(model, f, x0, cz, w, d, h, { AC = rich and 2 or 1, Tank = rich or H.rng:NextNumber() < 0.5 })
	if rich and H.rng:NextNumber() < 0.45 then
		for _, x in ipairs({ -6, 6 }) do
			H.deco(model, "OutdoorPoste", V3(0.5, 7, 0.5), at(f, x0 + x, h + 4.5, cz), STEEL, M.Metal)
		end
		local board = H.deco(model, "Outdoor", V3(20, 6, 0.5), at(f, x0, h + 9, cz), H.pick(AWNINGS), SP)
		H.surfaceText(board, Enum.NormalId.Front, H.pick({ "PEÇA JÁ! 🛵", "PROMOÇÃO 50%", "DELIVERY RUSH", "SUPER OFERTA" }), H.WHITE)
	end
	return fc, h
end

-- Mansão moderna: volume branco embaixo, volume de madeira em balanço em cima, vidro e laje fina
local function mansion(model, f, S, withPool)
	local white = H.pick(S.Colors)
	local wood = H.pick({ Color3.fromRGB(165, 115, 75), Color3.fromRGB(120, 85, 58), Color3.fromRGB(70, 72, 78) })
	body(model, "Mansion", f, -2, 5, 32, 9, 20, white, M.Plaster)
	body(model, "UpperFloor", f, 2, 8, 26, 8, 18, wood, M.WoodPlanks, 9)
	H.deco(model, "Laje", V3(34, 0.6, 22), at(f, -2, 9.2, 5), Color3.fromRGB(235, 235, 230), M.Concrete)
	H.deco(model, "LajeTopo", V3(28.5, 0.6, 20.5), at(f, 2, 17.3, 8), Color3.fromRGB(235, 235, 230), M.Concrete)
	local g = H.deco(model, "VidroTerreo", V3(20, 7, 0.2), at(f, -8, 4, 15.1), GLASS_C, M.Glass)
	g.Transparency = 0.3
	local u = H.deco(model, "VidroSuperior", V3(18, 5, 0.2), at(f, 4, 13, 17.1), GLASS_C, M.Glass)
	u.Transparency = 0.3
	for _, x in ipairs({ -10.5, 14.5 }) do
		H.deco(model, "Pilar", V3(0.6, 9, 0.6), at(f, x, 4.5, 16.5), STEEL, M.Metal)
	end
	local fc = faces(f, -2, 5, 32, 20)
	door(model, fc.front, 8, 3.4, 7.5, Color3.fromRGB(90, 60, 40), M.Wood, true)
	if H.rng:NextNumber() < 0.5 then
		for _, x in ipairs({ -3, 7 }) do
			local p = H.deco(model, "PainelSolar", V3(8, 0.3, 5), at(f, x, 18, 6) * CFrame.Angles(math.rad(15), 0, 0), Color3.fromRGB(30, 45, 80), M.Glass)
			p.Reflectance = 0.2
		end
	end
	if withPool then
		H.deco(model, "Deck", V3(30, 0.3, 13), at(f, -2, 0.4, -19), Color3.fromRGB(190, 150, 105), M.WoodPlanks)
		H.deco(model, "BordaPiscina", V3(20, 0.35, 8.5), at(f, -4, 0.45, -19.5), Color3.fromRGB(240, 240, 235), M.Concrete)
		local pool = H.deco(model, "Piscina", V3(18.5, 0.25, 7), at(f, -4, 0.55, -19.5), Color3.fromRGB(50, 170, 225), M.Glass)
		pool.Transparency = 0.15
		for _, x in ipairs({ 9, 12.5 }) do
			H.deco(model, "Espreguicadeira", V3(2, 0.6, 5.5), at(f, x, 1, -19) * CFrame.Angles(math.rad(8), 0, 0), H.WHITE, M.Fabric)
		end
		H.palm(model, at(f, 17, 0, -24).Position, 1)
	end
	return fc
end

-- Torre de vidro (financeiro). podium = base de 2 andares em granito. Retorna fachadas e a altura do topo.
local function tower(model, f, S, x0, cz, w, d, h, podium)
	local glassColor = H.pick(S.Colors)
	local y0 = 0
	if podium then
		body(model, "Podio", f, x0, cz + 1, w + 8, 12, d + 6, Color3.fromRGB(62, 64, 72), M.Granite)
		y0 = 12
	end
	local t = body(model, "Tower", f, x0, cz, w, h - y0, d, glassColor, M.Glass, y0)
	t.Reflectance = 0.18
	for y = y0 + 6, h - 8, 12 do
		H.deco(model, "Windows", V3(w + 0.3, 1.2, d + 0.3), at(f, x0, y, cz), Color3.fromRGB(170, 180, 195), M.Metal)
	end
	local fc = faces(f, x0, cz, w, d)
	local finColor = Color3.fromRGB(190, 196, 206)
	fins(model, fc.front, y0, h - y0, 2, finColor)
	fins(model, fc.right, y0, h - y0, 2, finColor)
	fins(model, fc.back, y0, h - y0, 1, finColor)
	fins(model, fc.left, y0, h - y0, 1, finColor)
	H.deco(model, "Coroa", V3(w - 6, 8, d - 6), at(f, x0, h + 4, cz), glassColor:Lerp(Color3.new(0, 0, 0), 0.25), M.Glass)
	H.deco(model, "CoroaNeon", V3(w + 0.6, 1, d + 0.6), at(f, x0, h - 0.5, cz), H.pick({ Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 190, 80) }), M.Neon)
	return fc, h + 8
end

function Blocks.Customer(parent, styleName, S, bc, dir, displayName)
	local model = newLotModel("Cliente_" .. displayName)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("PlaceType", S.Place)
	local f = H.lotFrame(bc, dir)

	if styleName == "centro" then
		local info = apartment(model, f, S, 0, 40, 28, H.rng:NextInteger(4, 8), true)
		local front = info.Faces.front
		door(model, front, info.BX, 4.6, 6.2, GLASS_C, M.Glass, true)
		H.deco(model, "Marquise", V3(10, 0.5, 3.6), front.F * CF(info.BX, 6.7, -1.8), STEEL, M.Metal)
		local plate = H.deco(model, "Numero", V3(2.4, 1.1, 0.2), front.F * CF(info.BX + 3.6, 5.2, -0.2), Color3.fromRGB(30, 60, 120), SP)
		H.surfaceText(plate, Enum.NormalId.Front, tostring(H.rng:NextInteger(10, 999)), H.WHITE)
		storefront(model, front, -info.BX, 18, info.GH, H.pick(D.STORE_NAMES), { Shutter = H.rng:NextNumber() < 0.4 })
	elseif styleName == "residencial" then
		local floors = (H.rng:NextNumber() < 0.45) and 2 or 1
		house(model, f, S, -5, 8, 26, 18, floors, { Dish = H.rng:NextNumber() < 0.4 })
		body(model, "Garage", f, 19, 9, 12, 7, 16, Color3.fromRGB(235, 232, 225), M.Plaster)
		H.deco(model, "LajeGaragem", V3(13.5, 0.5, 18), at(f, 19, 7.2, 10), Color3.fromRGB(215, 212, 205), M.Concrete)
		H.deco(model, "PortaGaragem", V3(10, 5.8, 0.25), at(f, 19, 2.9, 17.1), H.pick(GATES), M.DiamondPlate)
		H.deco(model, "Entrada", V3(10, 0.1, 11), at(f, 19, 0.37, 23), Color3.fromRGB(170, 166, 158), M.Pavement)
		H.deco(model, "Caminho", V3(3, 0.1, 11), at(f, -5, 0.37, 23), Color3.fromRGB(200, 190, 170), M.Pavement)
		if H.rng:NextNumber() < 0.7 then
			H.car(model, at(f, 19, 0.35, 23), nil, true)
		end
		local wallColor = H.pick(S.Colors):Lerp(Color3.new(1, 1, 1), 0.3)
		frontWall(model, f, 28.8, 2.4, wallColor, {
			{ -29.5, -6.8 }, { -6.8, -3.2, "gate" }, { -3.2, 13.5 }, { 13.5, 24.5, "garage" }, { 24.5, 29.5 },
		})
		local num = H.deco(model, "Numero", V3(2.2, 1, 0.2), at(f, -9, 1.6, 29.15), Color3.fromRGB(30, 60, 120), SP)
		H.surfaceText(num, Enum.NormalId.Front, tostring(H.rng:NextInteger(10, 999)), H.WHITE)
		for _, x in ipairs({ -15, 5 }) do
			H.ellipsoid(model, "Arbusto", at(f, x, 1.2, 19.5), V3(4, 2.6, 2.6), Color3.fromRGB(60, 130 + H.rng:NextInteger(-15, 15), 60), M.LeafyGrass)
		end
		H.tree(model, at(f, -24, 0, -20).Position, 1)
	elseif styleName == "comercial" then
		local fc = commercial(model, f, S, 0, 44, 28, H.rng:NextInteger(2, 4), H.pick(D.STORE_NAMES), true)
		door(model, fc.front, 0, 4.4, 5.6, GLASS_C, M.Glass, false)
	elseif styleName == "nobre" then
		mansion(model, f, S, true)
		frontWall(model, f, 28.8, 3, Color3.fromRGB(235, 232, 225), {
			{ -29.5, 4 }, { 4, 12, "gate" }, { 12, 14 }, { 14, 26, "garage" }, { 26, 29.5 },
		})
		H.deco(model, "CercaViva", V3(33.5, 1.6, 1.4), at(f, -12.75, 3.8, 28.8), Color3.fromRGB(45, 105, 50), M.LeafyGrass)
		H.deco(model, "Cobertura", V3(12, 0.5, 13), at(f, 20, 7, 21), Color3.fromRGB(235, 235, 230), M.Concrete)
		for _, x in ipairs({ 14.6, 25.4 }) do
			H.deco(model, "PilarCobertura", V3(0.5, 6.8, 0.5), at(f, x, 3.4, 26.5), STEEL, M.Metal)
		end
		H.car(model, at(f, 20, 0.35, 21), nil, true)
		for _, x in ipairs({ -22, -6 }) do
			H.deco(model, "LuzJardim", V3(0.6, 1.2, 0.6), at(f, x, 0.9, 24), Color3.fromRGB(255, 228, 170), M.Neon)
		end
		H.tree(model, at(f, -24, 0, 22).Position, 0.9)
	elseif styleName == "financeiro" then
		local _, top = tower(model, f, S, 0, 2, 34, 34, H.rng:NextInteger(70, 140), true)
		local podiumFront = faces(f, 0, 3, 42, 40).front
		local lobby = H.deco(model, "Saguao", V3(26, 9, 0.2), podiumFront.F * CF(0, 4.8, -0.1), GLASS_C, M.Glass)
		lobby.Transparency = 0.25
		door(model, podiumFront, 0, 6, 7, GLASS_C, M.Glass, false)
		H.deco(model, "Marquise", V3(22, 0.6, 6), podiumFront.F * CF(0, 10, -3), STEEL, M.Metal)
		H.deco(model, "MarquiseLuz", V3(22, 0.2, 0.3), podiumFront.F * CF(0, 9.65, -5.9), Color3.fromRGB(80, 220, 255), M.Neon)
		for _, x in ipairs({ -9, 9 }) do
			H.cylV(model, "Coluna", podiumFront.F * CF(x, 0, -5.4), 9.7, 0.9, Color3.fromRGB(200, 200, 205), M.Metal, true)
		end
		for _, x in ipairs({ -20, 20 }) do
			H.deco(model, "Floreira", V3(4, 1.6, 4), at(f, x, 0.8, 27.5), Color3.fromRGB(170, 170, 175), M.Concrete)
			H.tree(model, at(f, x, 1.6, 27.5).Position, 0.55)
		end
		if H.rng:NextNumber() < 0.4 then
			H.cylV(model, "Helipad", at(f, 0, top, 2), 0.5, 22, Color3.fromRGB(60, 62, 70), M.Concrete, false)
			local mark = H.deco(model, "HelipadMark", V3(10, 0.1, 10), at(f, 0, top + 0.55, 2), Color3.fromRGB(60, 62, 70), M.Concrete)
			H.surfaceText(mark, Enum.NormalId.Top, "H", Color3.fromRGB(255, 220, 60)).Parent.PixelsPerStud = 20
		else
			H.cylV(model, "Mast", at(f, 0, top, 2), 26, 0.8, Color3.fromRGB(200, 200, 210), M.Metal, false)
			H.ball(model, "MastLight", at(f, 0, top + 26.5, 2), 1.4, H.RED, M.Neon, false)
		end
	end

	H.pad(model, bc + dir * H.PAD_OFFSET, H.BLUE)
	model.Parent = parent
	return model
end

local function park(model, bc, f, color, trees, palms)
	ground(model, bc, color)
	H.deco(model, "Caminho", V3(4, 0.1, 56), CF(bc.X, 0.4, bc.Z), Color3.fromRGB(205, 195, 170), M.Pavement)
	H.deco(model, "Caminho", V3(56, 0.1, 4), CF(bc.X, 0.41, bc.Z), Color3.fromRGB(205, 195, 170), M.Pavement)
	for i = 1, trees do
		local q = V3(((i % 2 == 0) and 1 or -1) * H.rng:NextNumber(9, 22), 0, ((i <= 2) and 1 or -1) * H.rng:NextNumber(9, 22))
		if palms then
			H.palm(model, bc + q, H.rng:NextNumber(0.85, 1.15))
		else
			H.tree(model, bc + q, H.rng:NextNumber(0.9, 1.3))
		end
	end
	bench(model, at(f, 6, 0, 4))
	bench(model, at(f, -6, 0, -4) * CFrame.Angles(0, math.pi, 0))
	lampPost(model, at(f, 3, 0, 3).Position)
	lampPost(model, at(f, -3, 0, -3).Position)
end

function Blocks.Empty(parent, styleName, S, bc, dir)
	local model = newLotModel("Terreno")
	local f = H.lotFrame(bc, dir or NORTH)
	if (styleName == "centro" or styleName == "comercial" or styleName == "financeiro") and H.rng:NextNumber() < 0.6 then
		model.Name = "Estacionamento"
		H.deco(model, "Parking", V3(56, 0.35, 56), CF(bc.X, 0.2, bc.Z), Color3.fromRGB(72, 72, 78), M.Asphalt)
		for _, k in ipairs({ -2, -1, 0, 1, 2 }) do
			H.deco(model, "ParkingLine", V3(0.4, 0.37, 9), at(f, k * 10 + 5, 0.2, -18), H.WHITE, SP)
			H.deco(model, "ParkingLine", V3(0.4, 0.37, 9), at(f, k * 10 + 5, 0.2, 10), H.WHITE, SP)
		end
		for _, k in ipairs({ -2, -1, 0, 1 }) do
			if H.rng:NextNumber() < 0.55 then
				H.car(model, at(f, k * 10 + 10, 0.35, -18) * CFrame.Angles(0, math.pi, 0), nil, true)
			end
			if H.rng:NextNumber() < 0.55 then
				H.car(model, at(f, k * 10 + 10, 0.35, 10), nil, true)
			end
		end
		H.deco(model, "Cabine", V3(4, 6, 4), at(f, 24, 3, 25), Color3.fromRGB(240, 240, 235), SP)
		local sign = H.deco(model, "PlacaEstac", V3(6, 2.4, 0.3), at(f, 24, 7.4, 27), Color3.fromRGB(30, 90, 200), SP)
		H.surfaceText(sign, Enum.NormalId.Front, "🅿️ ESTACIONAMENTO", H.WHITE)
		model.Parent = parent
		return
	end
	ground(model, bc)
	if H.rng:NextNumber() < 0.6 then
		H.tree(model, bc + V3(H.rng:NextNumber(-18, 18), 0, H.rng:NextNumber(-18, 18)), H.rng:NextNumber(0.9, 1.3))
	end
	if H.rng:NextNumber() < 0.35 then
		H.deco(model, "PlacaPoste", V3(0.4, 5, 0.4), at(f, 12, 2.5, 26), STEEL, M.Metal)
		local board = H.deco(model, "Placa", V3(6, 3, 0.3), at(f, 12, 5.8, 26), H.WHITE, SP)
		H.surfaceText(board, Enum.NormalId.Front, H.pick({ "VENDE-SE", "ALUGA-SE", "EM BREVE" }), Color3.fromRGB(200, 30, 40))
	end
	model.Parent = parent
end

function Blocks.Decor(parent, styleName, S, bc, isPlaza, dir)
	local model = newLotModel("Lote")
	local f = H.lotFrame(bc, dir or NORTH)
	if isPlaza then
		model.Name = "Praca"
		ground(model, bc)
		local base = H.block(model, "Fountain", V3(2, 20, 20), CF(bc.X, 1, bc.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(200, 200, 205), M.Concrete, true)
		base.Shape = Enum.PartType.Cylinder
		local water = H.deco(model, "Water", V3(0.3, 17, 17), CF(bc.X, 2.05, bc.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 170, 240), M.Glass)
		water.Shape = Enum.PartType.Cylinder
		water.Transparency = 0.2
		H.block(model, "Statue", V3(2, 8, 2), CF(bc.X, 5, bc.Z), Color3.fromRGB(190, 160, 90), M.Metal, true)
		for _, o in ipairs({ V3(20, 0, 20), V3(-20, 0, 20), V3(20, 0, -20), V3(-20, 0, -20) }) do
			H.tree(model, bc + o, 1.1)
		end
		bench(model, CF(bc + V3(0, 0, 18)))
		bench(model, CF(bc + V3(0, 0, -18)) * CFrame.Angles(0, math.pi, 0))
		model.Parent = parent
		return
	end
	local r = H.rng:NextNumber()
	local variant = r < 0.45 and 1 or (r < 0.8 and 2 or 3)

	if styleName == "centro" then
		if variant == 1 then
			for _, x in ipairs({ -14.5, 14.5 }) do
				local info = apartment(model, f, S, x, 27, 48, H.rng:NextInteger(3, 8), false)
				storefront(model, info.Faces.front, 0, 24, info.GH, H.pick(D.STORE_NAMES), { Shutter = H.rng:NextNumber() < 0.35 })
			end
		elseif variant == 2 then
			local info = apartment(model, f, S, 0, 52, 50, H.rng:NextInteger(5, 10), false)
			storefront(model, info.Faces.front, -13, 24, info.GH, H.pick(D.STORE_NAMES), { Shutter = H.rng:NextNumber() < 0.35 })
			storefront(model, info.Faces.front, 13, 24, info.GH, H.pick(D.STORE_NAMES), { Shutter = H.rng:NextNumber() < 0.35 })
		else
			park(model, bc, f, nil, 4, false)
		end
	elseif styleName == "residencial" then
		if variant == 1 then
			for _, x in ipairs({ -15, 15 }) do
				local right = x > 0
				house(model, f, S, x, 8, 24, 16, (H.rng:NextNumber() < 0.3) and 2 or 1,
					{ Windows = { right and -7 or 7 }, DoorX = right and 5 or -5, Shutters = H.rng:NextNumber() < 0.5, Lamp = false })
				local gx = x + (right and 5 or -5)
				frontWall(model, f, 28.8, 2.2, H.pick(S.Colors):Lerp(Color3.new(1, 1, 1), 0.3), {
					{ x - 14.5, gx - 1.8 }, { gx - 1.8, gx + 1.8, "gate" }, { gx + 1.8, x + 14.5 },
				})
			end
			H.tree(model, at(f, 0, 0, -22).Position, 1)
		elseif variant == 2 then
			for _, x in ipairs({ -18, 0, 18 }) do
				body(model, "Sobrado", f, x, 10, 17.6, 14, 16, H.pick(S.Colors), M.Plaster)
				H.gableRoof(model, at(f, x, 0, 10).Position, f.LookVector, 17.6, 16, 14, 4.5, H.pick(S.Roofs), 0.8)
				local fc = faces(f, x, 10, 17.6, 16)
				door(model, fc.front, -4, 3.2, 6.2, H.pick(DOORS), M.Wood, false)
				window(model, fc.front, 3.5, 3.9, 3.6, 3, nil)
				window(model, fc.front, 0, 10.4, 5, 3, nil)
			end
			frontWall(model, f, 28.8, 1.6, Color3.fromRGB(240, 238, 232), { { -29.5, -24 }, { -20, -6 }, { -2, 12 }, { 16, 29.5 } })
		else
			park(model, bc, f, nil, 3, false)
			H.deco(model, "Areia", V3(12, 0.4, 12), CF(bc.X + 13, 0.45, bc.Z - 13), Color3.fromRGB(225, 200, 140), M.Sand)
			H.block(model, "Escorregador", V3(3, 5, 10), CFrame.lookAt(V3(bc.X - 13, 2.5, bc.Z - 13), V3(bc.X - 13, 2.5, bc.Z - 14)), Color3.fromRGB(240, 80, 80), SP, true, "WedgePart")
			H.deco(model, "Balanco", V3(8, 0.5, 0.5), CF(bc.X + 13, 6, bc.Z + 13), STEEL, M.Metal)
			for _, x in ipairs({ -4, 4 }) do
				H.deco(model, "BalancoPe", V3(0.4, 6, 0.4), CF(bc.X + 13 + x, 3, bc.Z + 13), STEEL, M.Metal)
			end
		end
	elseif styleName == "comercial" then
		if variant == 1 then
			H.deco(model, "Parking", V3(56, 0.35, 56), CF(bc.X, 0.2, bc.Z), Color3.fromRGB(70, 70, 76), M.Asphalt)
			for _, k in ipairs({ -2, -1, 0, 1, 2 }) do
				H.deco(model, "ParkingLine", V3(0.4, 0.37, 9), at(f, k * 10 + 5, 0.2, -14), H.WHITE, SP)
				H.deco(model, "ParkingLine", V3(0.4, 0.37, 9), at(f, k * 10 + 5, 0.2, 14), H.WHITE, SP)
			end
			for _, k in ipairs({ -2, -1, 0, 1 }) do
				if H.rng:NextNumber() < 0.6 then
					H.car(model, at(f, k * 10 + 10, 0.35, -14) * CFrame.Angles(0, math.pi, 0), nil, true)
				end
				if H.rng:NextNumber() < 0.6 then
					H.car(model, at(f, k * 10 + 10, 0.35, 14), nil, true)
				end
			end
			H.deco(model, "Cabine", V3(4, 6, 4), at(f, -24, 3, 26), Color3.fromRGB(240, 240, 235), SP)
			H.deco(model, "CabineTeto", V3(5, 0.5, 5), at(f, -24, 6.2, 26), H.pick(AWNINGS), SP)
			lampPost(model, at(f, -12, 0, 0).Position)
			lampPost(model, at(f, 12, 0, 0).Position)
		elseif variant == 2 then
			for k = -1, 1 do
				local x = k * 18.5
				local h = H.rng:NextInteger(9, 13)
				local color = H.pick(S.Colors)
				body(model, "Shop", f, x, 11, 17.6, h, 30, color, H.pick({ M.Plaster, SP }))
				local fc = faces(f, x, 11, 17.6, 30)
				storefront(model, fc.front, 0, 16.4, 7.5, H.pick(D.STORE_NAMES), { Shutter = H.rng:NextNumber() < 0.4 })
				H.deco(model, "Platibanda", V3(18, 1.2, 30.4), at(f, x, h + 0.4, 11), color:Lerp(Color3.new(1, 1, 1), 0.35), M.Concrete)
				if h >= 11 then
					H.deco(model, "JanelaSuperior", V3(12, 2, 0.25), fc.front.F * CF(0, 9.8, -0.1), DARKWIN, M.Glass)
				end
			end
		else
			ground(model, bc, Color3.fromRGB(150, 150, 155), M.Concrete)
			local c = at(f, 0, 0, 4)
			for _, o in ipairs({ V3(-10, 0, -8), V3(10, 0, -8), V3(-10, 0, 8), V3(10, 0, 8) }) do
				H.block(model, "Pilar", V3(1, 9, 1), c * CF(o.X, 4.5, o.Z), H.WHITE, SP, true)
			end
			H.deco(model, "Canopy", V3(30, 1.5, 24), c * CF(0, 9.75, 0), H.WHITE, SP)
			H.deco(model, "CanopyStripe", V3(30.2, 0.6, 24.2), c * CF(0, 9.4, 0), H.pick({ H.RED, Color3.fromRGB(30, 140, 60), Color3.fromRGB(30, 90, 200) }), M.Neon)
			H.deco(model, "CanopyLuz", V3(26, 0.15, 20), c * CF(0, 8.95, 0), Color3.fromRGB(255, 250, 235), M.Neon)
			for _, x in ipairs({ -5, 5 }) do
				H.deco(model, "Ilha", V3(3, 0.5, 10), c * CF(x, 0.6, 0), Color3.fromRGB(200, 200, 200), M.Concrete)
				for _, z in ipairs({ -2.5, 2.5 }) do
					H.block(model, "Bomba", V3(1.8, 4, 1.4), c * CF(x, 2.8, z), Color3.fromRGB(230, 60, 45), SP, true)
					H.deco(model, "BombaTela", V3(1.2, 0.8, 1.5), c * CF(x, 3.8, z), Color3.fromRGB(30, 30, 35), M.Glass)
				end
			end
			body(model, "Store", f, 0, -20, 26, 8, 10, H.WHITE, SP)
			local sf = faces(f, 0, -20, 26, 10).front
			local glass = H.deco(model, "Vitrine", V3(18, 5, 0.2), sf.F * CF(-2, 3, -0.1), GLASS_C, M.Glass)
			glass.Transparency = 0.3
			local sign = H.deco(model, "Letreiro", V3(14, 2.2, 0.4), sf.F * CF(0, 7.3, -0.3), H.RED, SP)
			H.surfaceText(sign, Enum.NormalId.Front, "CONVENIÊNCIA 24H", H.WHITE)
			H.deco(model, "TotemPoste", V3(1, 12, 1), at(f, 24, 6, 26), STEEL, M.Metal)
			local totem = H.deco(model, "Totem", V3(6, 7, 0.8), at(f, 24, 14, 26), H.RED, SP)
			H.surfaceText(totem, Enum.NormalId.Front, "⛽ POSTO\n5,79", H.WHITE)
		end
	elseif styleName == "nobre" then
		if variant == 1 then
			park(model, bc, f, Color3.fromRGB(96, 175, 80), 4, true)
			H.deco(model, "LagoBorda", V3(23, 0.3, 15), at(f, 12, 0.42, 12), Color3.fromRGB(200, 195, 185), M.Cobblestone)
			local pond = H.deco(model, "Lago", V3(21, 0.25, 13), at(f, 12, 0.55, 12), Color3.fromRGB(60, 150, 210), M.Glass)
			pond.Transparency = 0.15
		elseif variant == 2 then
			mansion(model, f, S, true)
			frontWall(model, f, 28.8, 3, Color3.fromRGB(235, 232, 225), { { -29.5, 6 }, { 6, 10, "gate" }, { 10, 29.5 } })
			H.deco(model, "CercaViva", V3(35.5, 1.6, 1.4), at(f, -11.75, 3.8, 28.8), Color3.fromRGB(45, 105, 50), M.LeafyGrass)
		else
			H.deco(model, "Court", V3(30, 0.35, 50), CF(bc.X, 0.2, bc.Z), Color3.fromRGB(180, 90, 60), M.Concrete)
			H.deco(model, "CourtLines", V3(24, 0.36, 44), CF(bc.X, 0.21, bc.Z), H.WHITE, SP)
			H.deco(model, "CourtInner", V3(23, 0.37, 43), CF(bc.X, 0.22, bc.Z), Color3.fromRGB(200, 105, 70), M.Concrete)
			H.deco(model, "Net", V3(26, 1.8, 0.2), CF(bc.X, 1.1, bc.Z), H.WHITE, M.Fabric)
			for _, x in ipairs({ -15.2, 15.2 }) do
				local fence = H.deco(model, "Alambrado", V3(0.2, 6, 50), CF(bc.X + x, 3, bc.Z), Color3.fromRGB(60, 90, 70), M.DiamondPlate)
				fence.Transparency = 0.6
				H.cylV(model, "Refletor", CF(bc.X + x, 0.3, bc.Z), 12, 0.5, STEEL, M.Metal, false)
				H.deco(model, "RefletorLuz", V3(1.5, 1, 2.5), CF(bc.X + x, 12.6, bc.Z), Color3.fromRGB(255, 250, 230), M.Neon)
			end
			H.palm(model, bc + V3(22, 0, 20), 1)
			H.palm(model, bc + V3(-22, 0, -20), 1)
		end
	elseif styleName == "financeiro" then
		if variant == 1 then
			for _, x in ipairs({ -14.5, 14.5 }) do
				tower(model, f, S, x, 1, 25, 48, H.rng:NextInteger(80, 150), false)
			end
		elseif variant == 2 then
			local _, top = tower(model, f, S, 0, 0, 48, 48, H.rng:NextInteger(150, 220), false)
			H.deco(model, "Escalonamento", V3(36, 24, 36), at(f, 0, top + 12, 0), H.pick(S.Colors), M.Glass).Reflectance = 0.2
			H.cylV(model, "Spire", at(f, 0, top + 24, 0), 30, 1.4, Color3.fromRGB(200, 200, 210), M.Metal, false)
			H.ball(model, "Beacon", at(f, 0, top + 54.5, 0), 1.8, H.RED, M.Neon, false)
		else
			ground(model, bc, Color3.fromRGB(150, 150, 158), M.Concrete)
			local base = H.block(model, "Fonte", V3(1.4, 16, 16), CF(bc.X, 0.9, bc.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(210, 210, 215), M.Marble, true)
			base.Shape = Enum.PartType.Cylinder
			local water = H.deco(model, "FonteAgua", V3(0.3, 14, 14), CF(bc.X, 1.55, bc.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 170, 240), M.Glass)
			water.Shape = Enum.PartType.Cylinder
			water.Transparency = 0.2
			for i = 0, 2 do
				H.block(model, "Sculpture", V3(2.4, 12, 2.4), CF(bc.X, 6 + i * 3, bc.Z) * CFrame.Angles(0, i * 0.7, math.rad(15)), Color3.fromRGB(80, 220, 255), M.Neon, i == 0)
			end
			for _, o in ipairs({ V3(-18, 0, -18), V3(18, 0, -18), V3(-18, 0, 18), V3(18, 0, 18) }) do
				H.deco(model, "Floreira", V3(4, 1.6, 4), CF(bc.X + o.X, 0.8, bc.Z + o.Z), Color3.fromRGB(170, 170, 175), M.Concrete)
				H.tree(model, bc + o + V3(0, 1.6, 0), 0.7)
			end
		end
	end
	model.Parent = parent
end

return Blocks
