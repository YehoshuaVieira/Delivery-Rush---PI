-- Restaurante detalhado, com variações por bairro.
local H = require(script.Parent.Helpers)
local FoodProps = require(script.Parent.FoodProps)

local SP = H.SP
local at = H.at

local Restaurants = {}

local function cafeTable(parent, cf, umbrellaColor, tableColor)
	H.cylV(parent, "TableLeg", cf, 2.4, 0.4, H.DARKGRAY, Enum.Material.Metal, false)
	H.cylV(parent, "TableTop", cf * CFrame.new(0, 2.4, 0), 0.3, 3.6, tableColor, SP, false)
	for _, x in ipairs({ -2.5, 2.5 }) do
		H.deco(parent, "Chair", Vector3.new(1.4, 0.3, 1.4), cf * CFrame.new(x, 1.5, 0), tableColor, SP)
		H.deco(parent, "ChairBack", Vector3.new(0.3, 1.6, 1.4), cf * CFrame.new(x + math.sign(x) * 0.6, 2.4, 0), tableColor, SP)
		H.deco(parent, "ChairLeg", Vector3.new(0.3, 1.5, 0.3), cf * CFrame.new(x, 0.75, 0), H.DARKGRAY, Enum.Material.Metal)
	end
	H.cylV(parent, "UmbrellaPole", cf, 6.6, 0.25, H.WHITE, Enum.Material.Metal, false)
	H.ellipsoid(parent, "Umbrella", cf * CFrame.new(0, 6.5, 0), Vector3.new(8, 1.8, 8), umbrellaColor, Enum.Material.Fabric)
end

local function parkedMoto(parent, cf)
	H.deco(parent, "MotoBody", Vector3.new(0.9, 0.9, 3.2), cf * CFrame.new(0, 1.5, 0), H.RED, SP)
	for _, z in ipairs({ -1.5, 1.5 }) do
		local w = H.deco(parent, "MotoWheel", Vector3.new(0.4, 1.6, 1.6), cf * CFrame.new(0, 0.8, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
		w.Shape = Enum.PartType.Cylinder
	end
	H.deco(parent, "MotoSeat", Vector3.new(0.9, 0.3, 1.3), cf * CFrame.new(0, 2.05, 0.3), H.DARKGRAY, Enum.Material.Fabric)
	H.deco(parent, "MotoBox", Vector3.new(1.6, 1.5, 1.5), cf * CFrame.new(0, 2.8, 1.3), H.RED, SP)
	H.deco(parent, "MotoBar", Vector3.new(1.6, 0.15, 0.15), cf * CFrame.new(0, 2.4, -1.3), H.DARKGRAY, SP)
end

function Restaurants.Build(parent, styleName, S, bc, dir, name, food)
	local R = S.Rest
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("DisplayName", name)
	model:SetAttribute("Food", food)

	local f = H.lotFrame(bc, dir)
	local W, D, Ht = 36, 24, R.H
	local front = 24
	local cz = front - D / 2

	local body = H.block(model, "Building", Vector3.new(W, Ht, D), at(f, 0, Ht / 2, cz), R.Color, R.Mat, true)
	if styleName == "financeiro" then
		body.Reflectance = 0.2
	end
	H.deco(model, "Sidewalk", Vector3.new(W + 10, 0.4, 6), at(f, 0, 0.35, front + 3), Color3.fromRGB(205, 200, 192), Enum.Material.Concrete)
	H.deco(model, "Plinth", Vector3.new(W + 0.4, 1.2, D + 0.4), at(f, 0, 0.6, cz), R.Trim, Enum.Material.Concrete)

	H.deco(model, "Door", Vector3.new(5, 8, 0.4), at(f, 0, 4, front + 0.2), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	H.deco(model, "DoorGlass", Vector3.new(3.4, 4.5, 0.1), at(f, 0, 5, front + 0.45), H.GLASS, Enum.Material.Glass).Transparency = 0.3
	for _, side in ipairs({ -1, 1 }) do
		H.deco(model, "Window", Vector3.new(12, 6, 0.3), at(f, side * 9.8, 4.4, front + 0.2), H.GLASS, Enum.Material.Glass).Transparency = 0.3
		H.deco(model, "Sill", Vector3.new(12.6, 0.5, 0.8), at(f, side * 9.8, 1.2, front + 0.4), R.Trim, Enum.Material.Concrete)
		H.deco(model, "Lintel", Vector3.new(12.6, 0.5, 0.6), at(f, side * 9.8, 7.6, front + 0.3), R.Trim, Enum.Material.Concrete)
		H.deco(model, "Planter", Vector3.new(3, 1.6, 2.4), at(f, side * (W / 2 - 1.5), 1.35, front + 2.2), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
		H.ball(model, "Plant", at(f, side * (W / 2 - 1.5), 3, front + 2.2), 2.8, Color3.fromRGB(60, 150, 70), Enum.Material.Grass, false)
	end

	if styleName == "nobre" then
		for _, x in ipairs({ -13, -5, 5, 13 }) do
			H.cylV(model, "Column", at(f, x, 0.55, front + 3.5), 9.5, 1.4, R.Color, Enum.Material.Marble, true)
		end
		H.deco(model, "Portico", Vector3.new(W - 2, 1, 5), at(f, 0, 10.5, front + 2.5), R.Color, Enum.Material.Marble)
		H.deco(model, "PorticoTrim", Vector3.new(W - 1.6, 0.4, 5.3), at(f, 0, 11.1, front + 2.5), R.Trim, Enum.Material.Metal)
		H.deco(model, "Carpet", Vector3.new(4, 0.1, 5.5), at(f, 0, 0.6, front + 3), Color3.fromRGB(150, 25, 35), Enum.Material.Fabric)
	elseif styleName == "financeiro" then
		H.deco(model, "Canopy", Vector3.new(W - 4, 0.5, 5), at(f, 0, 9, front + 2.5), R.AwningA, Enum.Material.Metal)
		H.deco(model, "CanopyLight", Vector3.new(W - 4, 0.2, 0.3), at(f, 0, 8.7, front + 4.9), R.Trim, Enum.Material.Neon)
	else
		local stripes = 7
		local sw = (W - 2) / stripes
		for i = 1, stripes do
			local x = -(W - 2) / 2 + sw * (i - 0.5)
			H.deco(model, "Awning", Vector3.new(sw, 0.3, 5), at(f, x, 8.6, front + 2.5) * CFrame.Angles(math.rad(-20), 0, 0),
				(i % 2 == 1) and R.AwningA or R.AwningB, Enum.Material.Fabric)
		end
		H.deco(model, "AwningValance", Vector3.new(W - 2, 0.8, 0.2), at(f, 0, 7.4, front + 4.85), R.AwningA, Enum.Material.Fabric)
	end

	local signY = R.SignY or (Ht - 2.4)
	if styleName == "financeiro" then
		H.deco(model, "SignGlow", Vector3.new(W - 5, 4.8, 0.5), at(f, 0, signY, front + 0.3), R.Trim, Enum.Material.Neon)
	end
	local sign = H.deco(model, "Sign", Vector3.new(W - 6, 4.2, 0.8), at(f, 0, signY, front + 0.7), R.Sign, SP)
	H.surfaceText(sign, Enum.NormalId.Front, FoodProps.Emoji[food] .. " " .. name, R.SignText)

	if styleName == "centro" then
		for i = -1.5, 1.5 do
			H.deco(model, "UpperWindow", Vector3.new(5, 3.4, 0.25), at(f, i * 8.5, 11.8, front + 0.1), Color3.fromRGB(60, 80, 100), Enum.Material.Glass)
			H.deco(model, "UpperSill", Vector3.new(5.6, 0.4, 0.8), at(f, i * 8.5, 9.9, front + 0.3), R.Trim, Enum.Material.Concrete)
		end
		H.deco(model, "Cornice", Vector3.new(W + 1, 1, D + 1), at(f, 0, Ht + 0.1, cz), R.Trim, Enum.Material.Concrete)
	elseif styleName == "residencial" then
		H.deco(model, "BenchSeat", Vector3.new(5, 0.4, 1.4), at(f, -10.5, 1.5, front + 4.5), R.Table, Enum.Material.Wood)
		H.deco(model, "BenchBack", Vector3.new(5, 1.4, 0.3), at(f, -10.5, 2.4, front + 3.9), R.Table, Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do
			H.deco(model, "FlowerBed", Vector3.new(1.8, 0.6, D - 4), at(f, side * (W / 2 + 1.2), 0.5, cz), Color3.fromRGB(90, 60, 40), Enum.Material.Ground)
			for k = -1, 1 do
				H.ball(model, "Flower", at(f, side * (W / 2 + 1.2), 1.2, cz + k * 6), 1.4, H.pick({ Color3.fromRGB(240, 80, 120), Color3.fromRGB(250, 220, 60), Color3.fromRGB(200, 120, 255) }), SP, false)
			end
		end
	elseif styleName == "nobre" then
		for _, side in ipairs({ -1, 1 }) do
			H.deco(model, "Hedge", Vector3.new(6, 2.4, 2), at(f, side * 20, 1.5, front + 4.5), Color3.fromRGB(40, 100, 45), Enum.Material.Grass)
			H.cylV(model, "LanternPole", at(f, side * 4.2, 0.55, front + 1.2), 5, 0.3, H.DARKGRAY, Enum.Material.Metal, false)
			H.deco(model, "Lantern", Vector3.new(0.9, 1.2, 0.9), at(f, side * 4.2, 6.1, front + 1.2), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
		end
	elseif styleName == "financeiro" then
		for _, x in ipairs({ -W / 2, W / 2 }) do
			for _, z in ipairs({ front, front - D }) do
				H.deco(model, "NeonEdge", Vector3.new(0.4, Ht, 0.4), at(f, x, Ht / 2, z), R.Trim, Enum.Material.Neon)
			end
		end
		H.deco(model, "NeonTop", Vector3.new(W, 0.4, 0.4), at(f, 0, Ht, front), R.Trim, Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			H.deco(model, "ConcretePlanter", Vector3.new(3, 1.6, 3), at(f, side * 21, 1.35, front + 3), Color3.fromRGB(170, 170, 175), Enum.Material.Concrete)
			H.tree(model, (at(f, side * 21, 2.1, front + 3)).Position, 0.55)
		end
	end

	if styleName == "residencial" then
		H.gableRoof(model, at(f, 0, 0, cz).Position, dir, W, D, Ht, 7, R.Roof)
		H.deco(model, "Chimney", Vector3.new(2.5, 5, 2.5), at(f, -10, Ht + 4.5, cz - 4), Color3.fromRGB(150, 80, 60), Enum.Material.Brick)
		H.cylV(model, "MascotPole", at(f, 24, 0.3, 26), 9, 0.6, H.DARKGRAY, Enum.Material.Metal, false)
		FoodProps.Build(model, food, at(f, 24, 9.3, 26))
	else
		if styleName ~= "centro" then
			H.deco(model, "Parapet", Vector3.new(W, 1.2, 0.6), at(f, 0, Ht + 0.6, front - 0.3), R.Trim, Enum.Material.Concrete)
			H.deco(model, "Parapet", Vector3.new(W, 1.2, 0.6), at(f, 0, Ht + 0.6, front - D + 0.3), R.Trim, Enum.Material.Concrete)
			H.deco(model, "Parapet", Vector3.new(0.6, 1.2, D), at(f, -W / 2 + 0.3, Ht + 0.6, cz), R.Trim, Enum.Material.Concrete)
			H.deco(model, "Parapet", Vector3.new(0.6, 1.2, D), at(f, W / 2 - 0.3, Ht + 0.6, cz), R.Trim, Enum.Material.Concrete)
		end
		H.deco(model, "AC", Vector3.new(3, 2, 3), at(f, -12, Ht + 1, cz - 5), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
		H.deco(model, "AC", Vector3.new(3, 2, 3), at(f, -7.5, Ht + 1, cz - 5), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
		H.cylV(model, "Pedestal", at(f, 6, Ht, cz), 1.2, 3.2, H.DARKGRAY, Enum.Material.Metal, false)
		FoodProps.Build(model, food, at(f, 6, Ht + 1.2, cz))
	end

	if styleName == "comercial" then
		H.car(model, at(f, 24, 0, 12), H.pick(H.CAR_COLORS), true)
		H.car(model, at(f, 24, 0, -2), H.pick(H.CAR_COLORS), true)
		H.cylV(model, "PylonPole", at(f, 26, 0.3, 26), 18, 1, H.DARKGRAY, Enum.Material.Metal, true)
		local pylon = H.deco(model, "Pylon", Vector3.new(9, 6, 1), at(f, 26, 21, 26), R.Sign, SP)
		H.surfaceText(pylon, Enum.NormalId.Front, FoodProps.Emoji[food], H.WHITE)
		H.surfaceText(pylon, Enum.NormalId.Back, FoodProps.Emoji[food], H.WHITE)
		H.deco(model, "NeonStrip", Vector3.new(W, 0.6, 0.3), at(f, 0, Ht - 0.3, front + 0.2), R.AwningB, Enum.Material.Neon)
	else
		cafeTable(model, at(f, 24, 0.3, 18), R.Umbrella, R.Table)
		cafeTable(model, at(f, 24, 0.3, 6), R.Umbrella, R.Table)
	end
	H.deco(model, "MotoParking", Vector3.new(9, 0.1, 14), at(f, -24, 0.36, 12), H.YELLOW, SP)
	H.deco(model, "MotoParkingInner", Vector3.new(8.2, 0.12, 13.2), at(f, -24, 0.37, 12), Color3.fromRGB(80, 80, 88), Enum.Material.Asphalt)
	parkedMoto(model, at(f, -24, 0.4, 15.5) * CFrame.Angles(0, math.rad(90), 0))
	parkedMoto(model, at(f, -24, 0.4, 8.5) * CFrame.Angles(0, math.rad(90), 0))

	H.cylV(model, "PickupPole", at(f, 7, 0.55, 29), 7.5, 0.4, Color3.fromRGB(80, 80, 85), Enum.Material.Metal, false)
	local board = H.deco(model, "PickupSign", Vector3.new(5, 2.4, 0.3), at(f, 7, 8, 29), H.RED, SP)
	H.surfaceText(board, Enum.NormalId.Front, "🛵 RETIRADA", H.WHITE)
	H.surfaceText(board, Enum.NormalId.Back, "🛵 RETIRADA", H.WHITE)
	H.pad(model, bc + dir * H.PAD_OFFSET, H.PAD_ORANGE)

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

return Restaurants
