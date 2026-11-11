-- Garagem: compra (com estrelas) e escolha da moto. O cliente só pede; o servidor confere tudo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CosmeticConfig = require(Modules.CosmeticConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)
local MotoManager = require(script.Parent.MotoManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CosmeticManager = {}

local function owns(cosmetics, item): boolean
	return item.Cost == 0 or table.find(cosmetics.Owned, item.Id) ~= nil
end

-- O que está em uso em cada categoria (item que não existe mais ou não foi comprado volta para o padrão)
local function equippedOf(player: Player)
	local cosmetics = PlayerDataManager.GetCosmetics(player)
	local equipped = {}
	for _, cat in ipairs(CosmeticConfig.Categories) do
		local item = cosmetics and CosmeticConfig.Get(cosmetics.Equipped[cat.Id])
		equipped[cat.Id] = (item and item.Category == cat.Id and owns(cosmetics, item)) and item.Id or cat.Items[1].Id
	end
	return equipped
end

local function publish(player: Player)
	local cosmetics = PlayerDataManager.GetCosmetics(player)
	if not cosmetics then
		return
	end
	local owned = {}
	for _, id in ipairs(cosmetics.Owned) do
		if type(id) == "string" and CosmeticConfig.Get(id) and not table.find(owned, id) then
			table.insert(owned, id)
		end
	end
	cosmetics.Owned = owned
	player:SetAttribute("CosmeticsOwned", table.concat(owned, ","))
	for cat, id in pairs(equippedOf(player)) do
		player:SetAttribute("Equip_" .. cat, id)
	end
end

function CosmeticManager.Init()
	PlayerDataManager.PlayerLoaded:Connect(publish)

	-- action "buy" (gasta estrelas e já usa) ou "equip" (só o que já é dele)
	Remotes.RequestCosmetic.OnServerEvent:Connect(function(player: Player, action, id)
		if not AntiExploit.CheckRateLimit(player, "Cosmetic", 0.3) then
			return
		end
		local item = typeof(id) == "string" and CosmeticConfig.Get(id)
		local cosmetics = PlayerDataManager.GetCosmetics(player)
		if not item or not cosmetics then
			return
		end
		if not owns(cosmetics, item) then
			if action ~= "buy" or not PlayerDataManager.TrySpendStars(player, item.Cost) then
				return
			end
			table.insert(cosmetics.Owned, item.Id)
		end
		cosmetics.Equipped[item.Category] = item.Id
		publish(player)
		MotoManager.RefreshSkin(player) -- se estiver numa partida, troca a moto na hora
	end)
end

return CosmeticManager
