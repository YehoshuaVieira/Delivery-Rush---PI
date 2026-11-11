-- Configuração da cidade: tamanho, grade, becos, obstáculos, estilos e nomes.
local H = require(script.Parent.Helpers)

local D = {}

D.SEED = 2026
D.AREA_SIZE = 2240              -- cada bairro tem 2240 x 2240 studs
D.HALF = D.AREA_SIZE / 2
D.ROAD_W = 32                   -- ruas principais (2 faixas de 16)
D.SPACINGS = { 136, 160, 160, 192, 224, 256 }
D.MERGE_CHANCE = 0.12           -- chance de juntar 2 quarteirões vizinhos (some um trecho de rua)
D.ALLEY_W = 14
D.ALLEY_MIN_SIZE = 150          -- lado interno mínimo do quarteirão para ganhar um beco
D.ALLEY_CHANCE = 0.55
D.LOT = 60                      -- cada construção ocupa um lote de 60 x 60
D.LOT_GAP = 8
D.PAD_OFFSET = 38               -- do centro do lote até o ponto de coleta/entrega (faixa mais próxima)
D.SIDEWALK_W = 4
D.RESTAURANTS_PER_AREA = 24
D.CUSTOMERS_PER_AREA = 60
D.RESTAURANT_SPACING = 300
D.EMPTY_LOT_CHANCE = 0.22
D.WORLD_LIMIT = 3500
D.MAX_OBRAS_PER_AREA = 10

D.OBSTACLE_CHANCE = {
	Obra = 0.03, Desvio = 0.07, Rampa = 0.15, Cones = 0.07, Carro = 0.05, Espinhos = 0.15,
	Oleo = 0.07, Buraco = 0.08, Lombada = 0.08, Lama = 0.06, Hidrante = 0.05, Radar = 0.06, Bola = 0.03,
}
D.OBSTACLE_ORDER = { "Obra", "Desvio", "Rampa", "Cones", "Carro", "Espinhos", "Oleo", "Buraco", "Lombada", "Lama", "Hidrante", "Radar", "Bola" }
D.MAX_BOLAS_PER_AREA = 6
D.END_MIN_LENGTH = 160
D.END_CHANCE = 0.6
D.END_ORDER = { "Espinhos", "Rampa", "Oleo", "Buraco", "Lombada", "Lama" }
D.END_WEIGHTS = { Espinhos = 0.28, Rampa = 0.34, Oleo = 0.08, Buraco = 0.1, Lombada = 0.1, Lama = 0.1 }
D.EXTRA_RAMP_MIN_LENGTH = 200
D.PAD_CLEARANCE = 30
D.TRAFFIC_HAZARD_CHANCE = 0.55 -- meio
D.TRAFFIC_END_CHANCE = 0.3     -- cada ponta
D.FLAT_ORDER = { "Espinhos", "Oleo", "Buraco", "Lombada", "Lama", "Radar" }
D.FLAT_WEIGHTS = { Espinhos = 0.35, Oleo = 0.15, Buraco = 0.2, Lombada = 0.15, Lama = 0.1, Radar = 0.05 }
D.TRAFFIC_ROUTES_PER_AREA = 10
D.EXTRA_TRAFFIC_ROUTES = 5
D.TRAFFIC_CARS_PER_ROUTE = 32
D.TRAFFIC_SPEED = 30
D.TRAFFIC_SPEED_MIN = 26
D.TRAFFIC_SPEED_MAX = 38

local S = D.AREA_SIZE
D.AREAS = {
	{ Id = 1, Folder = "Area1_Centro", Name = "Centro", C = Vector3.new(0, 0, 0), Style = "centro",
		Foods = { "pastel", "burger", "pizza", "acai", "bread", "coffee", "skewer", "icecream", "marmita" },
		Restaurants = {
			{ "Pastelaria do Zé", "pastel" }, { "Lanchonete Central", "burger" }, { "Pizzaria Bella Massa", "pizza" },
			{ "Açaí da Praça", "acai" }, { "Padaria Central", "bread" }, { "Café do Largo", "coffee" },
			{ "Espetinho do Tião", "skewer" }, { "Sorvetes Polar", "icecream" },
		} },
	{ Id = 2, Folder = "Area2_Residencial", Name = "Bairro Residencial", C = Vector3.new(0, 0, -S), Style = "residencial",
		Foods = { "bread", "marmita", "burger", "icecream", "pizza", "cake", "acai", "pastel" },
		Restaurants = {
			{ "Padaria Pão Quente", "bread" }, { "Marmitaria da Vó", "marmita" }, { "Hamburgueria do Bairro", "burger" },
			{ "Sorveteria Gelato", "icecream" }, { "Pizzaria Forno a Lenha", "pizza" }, { "Doces da Tia", "cake" },
			{ "Açaí Tropical", "acai" }, { "Pastel da Feira", "pastel" },
		} },
	{ Id = 3, Folder = "Area3_Comercial", Name = "Zona Comercial", C = Vector3.new(S, 0, 0), Style = "comercial",
		Foods = { "sushi", "skewer", "pastel", "burger", "pizza", "coffee", "marmita", "bowl" },
		Restaurants = {
			{ "Sushi Express", "sushi" }, { "Churrascaria Fogo Bom", "skewer" }, { "Temakeria House", "sushi" },
			{ "Esfiharia Sabor", "pastel" }, { "Burger Point", "burger" }, { "Pizza Rápida", "pizza" },
			{ "Café & Cia", "coffee" }, { "Marmita Express", "marmita" },
		} },
	{ Id = 4, Folder = "Area4_Nobre", Name = "Bairro Nobre", C = Vector3.new(0, 0, S), Style = "nobre",
		Foods = { "chef", "pizza", "skewer", "cake", "icecream", "coffee", "sushi" },
		Restaurants = {
			{ "Bistrô Le Chef", "chef" }, { "Cantina Nonna", "pizza" }, { "Steakhouse Prime", "skewer" },
			{ "Doceria Fina", "cake" }, { "Patisserie Belle", "cake" }, { "Trattoria Roma", "pizza" },
			{ "Gelateria Dolce", "icecream" }, { "Empório Gourmet", "chef" },
		} },
	{ Id = 5, Folder = "Area5_Financeiro", Name = "Centro Financeiro", C = Vector3.new(-S, 0, 0), Style = "financeiro",
		Foods = { "sushi", "bowl", "coffee", "burger", "cake", "chef" },
		Restaurants = {
			{ "Omakase Premium", "sushi" }, { "Poke & Co.", "bowl" }, { "Café Executivo", "coffee" },
			{ "Burger Lab Gourmet", "burger" }, { "Salad Box", "bowl" }, { "Sushi Tower", "sushi" },
			{ "Espresso Bar", "coffee" }, { "Brunch Club", "cake" },
		} },
}

local FOOD_PREFIX = {
	pizza = { "Pizzaria", "Cantina" }, burger = { "Hamburgueria", "Burger" }, sushi = { "Sushi", "Temakeria" },
	acai = { "Açaí" }, bread = { "Padaria", "Panificadora" }, coffee = { "Café", "Cafeteria" },
	skewer = { "Espetinho", "Churrascaria" }, icecream = { "Sorveteria", "Gelateria" }, pastel = { "Pastelaria", "Esfiharia" },
	marmita = { "Marmitaria", "Cozinha" }, cake = { "Doceria", "Confeitaria" }, chef = { "Bistrô", "Restaurante" },
	bowl = { "Poke", "Saladeria" },
}
local SUFFIXES = { "do Zé", "Central", "da Esquina", "Express", "da Vila", "do Porto", "Real", "Top", "Gourmet",
	"da Praça", "Nova Era", "Bom Sabor", "Delícia", "da Serra", "do Bairro", "Estrela", "Prime", "da Avenida",
	"Paulista", "Mineira", "Carioca", "da Lu", "do Chef", "Sabor Caseiro", "24h", "Imperial", "Aurora", "Tropical" }

function D.RestaurantInfo(area, index: number, used)
	local listed = area.Restaurants[index]
	if listed and not used[listed[1]] then
		used[listed[1]] = true
		return listed[1], listed[2]
	end
	for _ = 1, 50 do
		local food = H.pick(area.Foods)
		local name = H.pick(FOOD_PREFIX[food]) .. " " .. H.pick(SUFFIXES)
		if not used[name] then
			used[name] = true
			return name, food
		end
	end
	local food = H.pick(area.Foods)
	return FOOD_PREFIX[food][1] .. " " .. index, food
end

D.STORE_NAMES = { "💊 Farmácia", "🛒 Mercadinho", "👕 Moda & Cia", "🏋️ Academia", "🏦 Banco", "📱 Celulares", "✂️ Barbearia",
	"📚 Livraria", "🐾 Pet Shop", "🔧 Oficina", "👟 Calçados", "🎮 Games", "🛋️ Móveis", "💄 Beleza", "🌸 Floricultura", "🏨 Hotel" }

D.FIRST_NAMES = { "Ana", "Bruno", "Carla", "Diego", "Eduarda", "Felipe", "Gabriela", "Henrique", "Isabela", "João",
	"Karina", "Lucas", "Mariana", "Nicolas", "Olívia", "Pedro", "Rafaela", "Samuel", "Tatiana", "Vitor",
	"Beatriz", "Caio", "Daniela", "Enzo", "Fernanda", "Gustavo", "Helena", "Igor", "Júlia", "Leonardo",
	"Manuela", "Otávio", "Priscila", "Renan", "Sofia", "Thiago", "Valentina", "Wagner", "Yasmin", "Zeca",
	"Alice", "Bernardo", "Cecília", "Davi", "Elisa", "Fábio", "Giovana", "Heitor", "Laura", "Miguel" }
D.SURNAMES = { "Silva", "Souza", "Costa", "Lima", "Rocha", "Alves", "Pereira", "Ferreira", "Gomes", "Martins",
	"Araújo", "Ribeiro", "Carvalho", "Teixeira", "Moura", "Barbosa", "Cardoso", "Nunes", "Mendes", "Freitas" }

D.STYLE = {
	centro = {
		Lot = Color3.fromRGB(178, 176, 172), LotMat = Enum.Material.Concrete, Place = "Apartamento",
		Colors = { Color3.fromRGB(205, 185, 150), Color3.fromRGB(170, 95, 75), Color3.fromRGB(150, 150, 160), Color3.fromRGB(225, 215, 195), Color3.fromRGB(125, 115, 105) },
		Rest = { Color = Color3.fromRGB(172, 90, 68), Mat = Enum.Material.Brick, H = 18, Trim = Color3.fromRGB(235, 225, 205),
			AwningA = Color3.fromRGB(220, 40, 45), AwningB = H.WHITE, Sign = Color3.fromRGB(250, 245, 230), SignText = Color3.fromRGB(200, 30, 40),
			Umbrella = Color3.fromRGB(220, 40, 45), Table = Color3.fromRGB(120, 80, 50) },
	},
	residencial = {
		Lot = Color3.fromRGB(122, 172, 92), LotMat = Enum.Material.Grass, Place = "Casa",
		Colors = { Color3.fromRGB(250, 220, 180), Color3.fromRGB(200, 230, 250), Color3.fromRGB(250, 200, 210), Color3.fromRGB(215, 245, 205), Color3.fromRGB(255, 245, 200) },
		Roofs = { Color3.fromRGB(160, 70, 60), Color3.fromRGB(110, 80, 60), Color3.fromRGB(90, 90, 105) },
		Rest = { Color = Color3.fromRGB(250, 228, 190), Mat = Enum.Material.WoodPlanks, H = 11, Trim = H.WHITE,
			AwningA = Color3.fromRGB(60, 150, 80), AwningB = H.WHITE, Sign = Color3.fromRGB(150, 100, 60), SignText = H.WHITE,
			Umbrella = Color3.fromRGB(60, 150, 80), Table = Color3.fromRGB(150, 100, 60), Roof = Color3.fromRGB(160, 70, 60), SignY = 12.4 },
	},
	comercial = {
		Lot = Color3.fromRGB(196, 186, 168), LotMat = Enum.Material.Pavement, Place = "Escritório",
		Colors = { Color3.fromRGB(255, 170, 50), Color3.fromRGB(250, 210, 60), Color3.fromRGB(60, 180, 170), Color3.fromRGB(230, 90, 60), Color3.fromRGB(120, 160, 230) },
		Rest = { Color = Color3.fromRGB(255, 196, 70), Mat = H.SP, H = 15, Trim = Color3.fromRGB(210, 40, 40),
			AwningA = Color3.fromRGB(220, 40, 40), AwningB = Color3.fromRGB(255, 215, 60), Sign = Color3.fromRGB(215, 35, 35), SignText = Color3.fromRGB(255, 225, 80),
			Umbrella = Color3.fromRGB(255, 215, 60), Table = H.WHITE },
	},
	nobre = {
		Lot = Color3.fromRGB(86, 158, 76), LotMat = Enum.Material.Grass, Place = "Mansão",
		Colors = { Color3.fromRGB(245, 245, 240), Color3.fromRGB(240, 230, 210), Color3.fromRGB(230, 225, 215) },
		Rest = { Color = Color3.fromRGB(245, 240, 230), Mat = Enum.Material.Marble, H = 16, Trim = Color3.fromRGB(212, 175, 55),
			AwningA = Color3.fromRGB(30, 80, 50), AwningB = Color3.fromRGB(30, 80, 50), Sign = Color3.fromRGB(28, 58, 42), SignText = Color3.fromRGB(230, 195, 90),
			Umbrella = H.WHITE, Table = H.WHITE, SignY = 13.4 },
	},
	financeiro = {
		Lot = Color3.fromRGB(64, 66, 76), LotMat = Enum.Material.Slate, Place = "Cobertura",
		Colors = { Color3.fromRGB(40, 60, 90), Color3.fromRGB(30, 35, 45), Color3.fromRGB(70, 90, 120), Color3.fromRGB(20, 40, 70) },
		Rest = { Color = Color3.fromRGB(30, 45, 70), Mat = Enum.Material.Glass, H = 20, Trim = Color3.fromRGB(80, 220, 255),
			AwningA = Color3.fromRGB(40, 40, 48), AwningB = Color3.fromRGB(40, 40, 48), Sign = Color3.fromRGB(15, 20, 30), SignText = Color3.fromRGB(90, 230, 255),
			Umbrella = Color3.fromRGB(40, 40, 48), Table = Color3.fromRGB(230, 230, 235) },
	},
}

return D
