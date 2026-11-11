-- Mascotes gigantes de comida no telhado dos restaurantes.
local H = require(script.Parent.Helpers)

local SP = H.SP
local C = {
	bun = Color3.fromRGB(222, 160, 75), patty = Color3.fromRGB(95, 55, 35), lettuce = Color3.fromRGB(90, 190, 70),
	cheese = Color3.fromRGB(255, 205, 50), tomato = Color3.fromRGB(215, 50, 40), crust = Color3.fromRGB(225, 170, 90),
	sauce = Color3.fromRGB(200, 45, 35), mozza = Color3.fromRGB(250, 225, 140), pepperoni = Color3.fromRGB(165, 35, 30),
	white = Color3.fromRGB(248, 248, 245), acai = Color3.fromRGB(85, 30, 100), cream = Color3.fromRGB(255, 240, 215),
	pink = Color3.fromRGB(250, 150, 185), wood = Color3.fromRGB(150, 100, 60), nori = Color3.fromRGB(30, 50, 35),
	salmon = Color3.fromRGB(250, 130, 90), coffee = Color3.fromRGB(90, 55, 35), bread = Color3.fromRGB(200, 130, 60),
	silver = Color3.fromRGB(200, 200, 205), banana = Color3.fromRGB(250, 225, 110),
}

local FoodProps = {}

FoodProps.Emoji = {
	burger = "🍔", pizza = "🍕", acai = "🍇", icecream = "🍦", sushi = "🍣", coffee = "☕", bread = "🥖",
	pastel = "🥟", skewer = "🍢", marmita = "🍱", cake = "🍰", chef = "🍽️", bowl = "🥗",
}

local builders = {}

builders.burger = function(m, cf)
	H.cylV(m, "Bun", cf, 2.2, 11, C.bun, SP)
	H.cylV(m, "Lettuce", cf * CFrame.new(0, 2.2, 0), 0.6, 12, C.lettuce, SP)
	H.cylV(m, "Patty", cf * CFrame.new(0, 2.8, 0), 2, 11.6, C.patty, SP)
	H.deco(m, "Cheese", Vector3.new(9.5, 0.4, 9.5), cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(45), 0), C.cheese, SP)
	H.cylV(m, "Tomato", cf * CFrame.new(0, 5.2, 0), 0.7, 11.8, C.tomato, SP)
	H.ellipsoid(m, "TopBun", cf * CFrame.new(0, 6, 0), Vector3.new(11.4, 7, 11.4), C.bun, SP)
	for i = 1, 5 do
		local a = i * 1.25
		H.ellipsoid(m, "Sesame", cf * CFrame.new(math.cos(a) * 3, 9, math.sin(a) * 3), Vector3.new(0.8, 0.4, 0.5), C.white, SP)
	end
end

builders.pizza = function(m, cf)
	H.cylV(m, "Pole", cf, 5, 0.6, C.silver, Enum.Material.Metal)
	local p = cf * CFrame.new(0, 7, 0) * CFrame.Angles(math.rad(-60), 0, 0)
	H.cylV(m, "Crust", p, 1, 13, C.crust, SP)
	H.cylV(m, "Sauce", p * CFrame.new(0, 0.05, 0), 1, 11.8, C.sauce, SP)
	H.cylV(m, "Cheese", p * CFrame.new(0, 0.12, 0), 1, 11, C.mozza, SP)
	H.cylV(m, "Pepperoni", p * CFrame.new(0, 0.2, 0), 1, 2.2, C.pepperoni, SP)
	for i = 0, 5 do
		local a = i * math.pi / 3
		H.cylV(m, "Pepperoni", p * CFrame.new(math.cos(a) * 3.6, 0.2, math.sin(a) * 3.6), 1, 2.2, C.pepperoni, SP)
	end
end

builders.acai = function(m, cf)
	H.cylV(m, "Cup", cf, 8, 7, C.acai, SP)
	H.cylV(m, "Label", cf * CFrame.new(0, 2.5, 0), 2.6, 7.15, C.white, SP)
	H.cylV(m, "Rim", cf * CFrame.new(0, 8, 0), 0.5, 7.4, C.white, SP)
	H.ellipsoid(m, "Top", cf * CFrame.new(0, 8.5, 0), Vector3.new(7, 3, 7), C.acai, SP)
	for i = 1, 3 do
		local a = i * 2.1
		H.cylV(m, "Banana", cf * CFrame.new(math.cos(a) * 1.8, 9.4, math.sin(a) * 1.8) * CFrame.Angles(0.3, 0, 0.2), 0.5, 2, C.banana, SP)
	end
	H.deco(m, "Spoon", Vector3.new(0.5, 6, 1), cf * CFrame.new(1.5, 10.5, 0.5) * CFrame.Angles(0, 0, math.rad(-25)), C.silver, Enum.Material.Metal)
end

builders.icecream = function(m, cf)
	H.cylV(m, "Cone1", cf, 2.5, 2, C.bread, SP)
	H.cylV(m, "Cone2", cf * CFrame.new(0, 2.5, 0), 2.5, 3.4, C.bread, SP)
	H.cylV(m, "Cone3", cf * CFrame.new(0, 5, 0), 2.5, 4.8, C.bread, SP)
	H.ball(m, "Scoop1", cf * CFrame.new(0, 9, 0), 6, C.pink, SP)
	H.ball(m, "Scoop2", cf * CFrame.new(0, 12.6, 0), 5.2, C.cream, SP)
	H.ball(m, "Cherry", cf * CFrame.new(0, 15.6, 0), 1.6, C.tomato, SP)
end

builders.sushi = function(m, cf)
	H.deco(m, "Board", Vector3.new(13, 0.8, 6.5), cf * CFrame.new(0, 0.4, 0), C.wood, Enum.Material.Wood)
	for _, x in ipairs({ -3.3, 3.3 }) do
		local b = cf * CFrame.new(x, 0.8, 0)
		H.cylV(m, "Rice", b, 3.6, 4.6, C.white, SP)
		H.cylV(m, "Nori", b * CFrame.new(0, 0.4, 0), 2.6, 4.9, C.nori, SP)
		H.cylV(m, "Salmon", b * CFrame.new(0, 3.6, 0), 0.5, 3.2, C.salmon, SP)
	end
	H.deco(m, "Chopstick", Vector3.new(0.3, 0.3, 11), cf * CFrame.new(-0.4, 5.5, 1) * CFrame.Angles(math.rad(25), math.rad(20), 0), Color3.fromRGB(150, 30, 30), SP)
	H.deco(m, "Chopstick", Vector3.new(0.3, 0.3, 11), cf * CFrame.new(0.4, 5.5, 1) * CFrame.Angles(math.rad(25), math.rad(28), 0), Color3.fromRGB(150, 30, 30), SP)
end

builders.coffee = function(m, cf)
	H.cylV(m, "Saucer", cf, 0.6, 11, C.white, SP)
	H.cylV(m, "Cup", cf * CFrame.new(0, 0.6, 0), 6, 7, C.white, SP)
	H.cylV(m, "Coffee", cf * CFrame.new(0, 6.5, 0), 0.2, 6.2, C.coffee, SP)
	H.deco(m, "Handle", Vector3.new(0.8, 3.4, 1), cf * CFrame.new(4.4, 3.6, 0), C.white, SP)
	H.deco(m, "HandleTop", Vector3.new(1.2, 0.8, 1), cf * CFrame.new(3.9, 5, 0), C.white, SP)
	H.deco(m, "HandleBottom", Vector3.new(1.2, 0.8, 1), cf * CFrame.new(3.9, 2.2, 0), C.white, SP)
	for i = 1, 3 do
		local s = H.ball(m, "Steam", cf * CFrame.new(math.sin(i) * 0.8, 7.5 + i * 1.6, 0), 1 + i * 0.4, C.white, SP)
		s.Transparency = 0.4 + i * 0.1
	end
end

builders.bread = function(m, cf)
	H.ellipsoid(m, "Bread", cf * CFrame.new(0, 2.6, 0), Vector3.new(13, 5.2, 6), C.bread, SP)
	for i = -1, 1 do
		local x = i * 3.5
		local y = 2.6 + 2.6 * math.sqrt(1 - (x / 6.5) ^ 2) + 0.05
		H.deco(m, "Cut", Vector3.new(0.5, 0.3, 4), cf * CFrame.new(x, y, 0) * CFrame.Angles(0, math.rad(30), 0), Color3.fromRGB(240, 200, 140), SP)
	end
end

builders.pastel = function(m, cf)
	H.cylV(m, "Pole", cf, 3, 0.6, C.silver, Enum.Material.Metal)
	local p = cf * CFrame.new(0, 5.5, 0) * CFrame.Angles(math.rad(-60), 0, 0)
	H.ellipsoid(m, "Pastel", p, Vector3.new(13, 2.6, 8), C.bun, SP)
	H.ellipsoid(m, "Borda", p * CFrame.new(0, 0, 3.4), Vector3.new(12, 1.4, 1.6), Color3.fromRGB(200, 135, 55), SP)
end

builders.skewer = function(m, cf)
	H.cylV(m, "Pole", cf, 4, 0.6, C.silver, Enum.Material.Metal)
	local s = cf * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(20))
	H.deco(m, "Stick", Vector3.new(15, 0.4, 0.4), s, C.wood, Enum.Material.Wood)
	local colors = { C.patty, C.tomato, C.lettuce, C.patty, C.cheese }
	for i = 1, 5 do
		H.ellipsoid(m, "Chunk", s * CFrame.new(-5 + (i - 1) * 2.6, 0, 0), Vector3.new(2.4, 2.6, 2.6), colors[i], SP)
	end
end

builders.marmita = function(m, cf)
	H.deco(m, "Box", Vector3.new(10, 3.4, 7), cf * CFrame.new(0, 1.7, 0), C.silver, Enum.Material.Metal)
	H.deco(m, "Rice", Vector3.new(4.4, 0.4, 6), cf * CFrame.new(-2.4, 3.4, 0), C.white, SP)
	H.deco(m, "Beans", Vector3.new(2.6, 0.4, 6), cf * CFrame.new(1.3, 3.4, 0), C.patty, SP)
	H.deco(m, "Salad", Vector3.new(2, 0.5, 6), cf * CFrame.new(3.7, 3.45, 0), C.lettuce, SP)
	H.deco(m, "Lid", Vector3.new(10.4, 0.3, 7.4), cf * CFrame.new(0, 7, 4.1) * CFrame.Angles(math.rad(80), 0, 0), C.silver, Enum.Material.Metal)
end

builders.cake = function(m, cf)
	H.cylV(m, "Plate", cf, 0.4, 13, C.white, SP)
	H.cylV(m, "Tier1", cf * CFrame.new(0, 0.4, 0), 3, 12, C.pink, SP)
	H.cylV(m, "Cream1", cf * CFrame.new(0, 3.4, 0), 0.5, 12.3, C.cream, SP)
	H.cylV(m, "Tier2", cf * CFrame.new(0, 3.9, 0), 3, 8.6, C.cream, SP)
	H.cylV(m, "Tier3", cf * CFrame.new(0, 6.9, 0), 2.6, 5.4, C.pink, SP)
	H.ball(m, "Cherry", cf * CFrame.new(0, 10.4, 0), 1.8, C.tomato, SP)
	for i = 0, 5 do
		local a = i * math.pi / 3
		H.ball(m, "Strawberry", cf * CFrame.new(math.cos(a) * 5, 4.4, math.sin(a) * 5), 1.2, C.tomato, SP)
	end
end

builders.chef = function(m, cf)
	H.cylV(m, "Band", cf, 3.4, 8, C.white, Enum.Material.Fabric)
	H.ellipsoid(m, "Puff", cf * CFrame.new(0, 6.5, 0), Vector3.new(11, 7, 11), C.white, Enum.Material.Fabric)
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		H.ellipsoid(m, "Puff", cf * CFrame.new(math.cos(a) * 3, 7.5, math.sin(a) * 3), Vector3.new(6, 5, 6), C.white, Enum.Material.Fabric)
	end
end

builders.bowl = function(m, cf)
	H.cylV(m, "Base", cf, 1, 6, C.white, SP)
	H.ellipsoid(m, "Bowl", cf * CFrame.new(0, 2.5, 0), Vector3.new(12, 5, 12), C.white, SP)
	H.cylV(m, "Rice", cf * CFrame.new(0, 3.9, 0), 0.8, 11, C.cream, SP)
	local toppings = { C.salmon, C.lettuce, C.cheese }
	for i = 0, 5 do
		local a = i * math.pi / 3
		H.deco(m, "Topping", Vector3.new(1.8, 1, 1.8), cf * CFrame.new(math.cos(a) * 3, 4.9, math.sin(a) * 3) * CFrame.Angles(0, a, 0), toppings[(i % 3) + 1], SP)
	end
end

function FoodProps.Build(parent: Instance, kind: string, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Mascote_" .. kind
	;(builders[kind] or builders.burger)(m, cf)
	m.Parent = parent
	return m
end

return FoodProps
