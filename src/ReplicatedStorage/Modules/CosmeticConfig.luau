-- Motos da Garagem, compradas com as estrelas das missões do dia. A 1ª é a padrão (grátis).
-- Skin = modelo em ServerStorage.MotoSkins (montado pelo Tools.MotoBuilder). Créditos dos modelos 3D: Modules.Creditos.

local CosmeticConfig = {}

CosmeticConfig.Categories = {
	{
		Id = "Moto", Name = "MOTOS", Items = {
			{ Id = "naked3", Name = "Naked 3", Cost = 0, Skin = "Naked3", Color = Color3.fromRGB(200, 24, 30), Desc = "Naked de rua, 3 cilindros" },
			{ Id = "scooter_retro", Name = "Scooter Retrô", Cost = 10, Skin = "ScooterRetro", Color = Color3.fromRGB(86, 190, 204), Desc = "Scooter clássica" },
			{ Id = "cafe_racer", Name = "Café Racer", Cost = 20, Skin = "CafeRacer", Color = Color3.fromRGB(238, 200, 46), Desc = "Clássica de garagem" },
			{ Id = "hiper_eletrica", Name = "Hiper Elétrica", Cost = 35, Skin = "HiperEletrica", Color = Color3.fromRGB(246, 172, 24), Desc = "Superesportiva elétrica" },
			{ Id = "conceito_cyber", Name = "Conceito Cyber", Cost = 50, Skin = "ConceitoCyber", Color = Color3.fromRGB(96, 102, 110), Desc = "Moto-conceito futurista" },
		},
	},
}

CosmeticConfig.DefaultSkin = "Naked3"

local byId, catById = {}, {}
for _, cat in ipairs(CosmeticConfig.Categories) do
	catById[cat.Id] = cat
	for _, item in ipairs(cat.Items) do
		item.Category = cat.Id
		byId[item.Id] = item
	end
end

function CosmeticConfig.Get(id: string?)
	return id and byId[id] or nil
end

function CosmeticConfig.GetCategory(id: string)
	return catById[id]
end

function CosmeticConfig.Default(categoryId: string): string
	return catById[categoryId].Items[1].Id
end

-- nome do modelo (MotoSkins / Assets.MotoVitrines) da moto escolhida
function CosmeticConfig.SkinOf(id: string?): string
	local item = byId[id or ""]
	return item and item.Skin or CosmeticConfig.DefaultSkin
end

return CosmeticConfig
