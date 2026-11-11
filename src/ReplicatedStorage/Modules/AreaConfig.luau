-- Bairros: Cost, PayMultiplier (pagamento das entregas na área), pasta no Workspace e visual.

local AreaConfig = {}

AreaConfig.Areas = {
	{
		Id = 1, Name = "Centro", Cost = 0, PayMultiplier = 1.0,
		FolderName = "Area1_Centro",
		Color = Color3.fromRGB(150, 150, 160),
		Tint = Color3.fromRGB(255, 255, 255), Saturation = 0,
	},
	{
		Id = 2, Name = "Bairro Residencial", Cost = 3000, PayMultiplier = 1.4,
		FolderName = "Area2_Residencial",
		Color = Color3.fromRGB(110, 190, 90),
		Tint = Color3.fromRGB(255, 248, 230), Saturation = 0.1,
	},
	{
		Id = 3, Name = "Zona Comercial", Cost = 8000, PayMultiplier = 1.9,
		FolderName = "Area3_Comercial",
		Color = Color3.fromRGB(255, 170, 50),
		Tint = Color3.fromRGB(255, 240, 215), Saturation = 0.2,
	},
	{
		Id = 4, Name = "Bairro Nobre", Cost = 20000, PayMultiplier = 2.6,
		FolderName = "Area4_Nobre",
		Color = Color3.fromRGB(212, 175, 55),
		Tint = Color3.fromRGB(255, 245, 220), Saturation = 0.25,
	},
	{
		Id = 5, Name = "Centro Financeiro", Cost = 50000, PayMultiplier = 3.5,
		FolderName = "Area5_Financeiro",
		Color = Color3.fromRGB(80, 200, 255),
		Tint = Color3.fromRGB(215, 230, 255), Saturation = -0.05,
	},
}

AreaConfig.Count = #AreaConfig.Areas

AreaConfig.RequireSequentialUnlock = true

function AreaConfig.Get(id: number)
	return AreaConfig.Areas[id]
end

-- Converte o Attribute "UnlockedAreas" (ex.: "1,2,3") em um set { [1]=true, [2]=true, ... }
function AreaConfig.ParseUnlocked(text: string?)
	local set = { [1] = true }
	if type(text) == "string" then
		for id in string.gmatch(text, "%d+") do
			set[tonumber(id)] = true
		end
	end
	return set
end

return AreaConfig
