-- Compras de upgrade e de bairros: o cliente só pede, o servidor valida e debita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local AreaConfig = require(Modules.AreaConfig)
local Format = require(Modules.Format)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)
local MotoManager = require(script.Parent.MotoManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ShopManager = {}

local function fail(message: string)
	return { Success = false, Message = message }
end

local function isInteger(value): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0
end

-- Upgrades e bairros só existem no Modo História
local function inStory(player: Player): boolean
	return player:GetAttribute("GameMode") == "Story"
end

function ShopManager.BuyUpgrade(player: Player, targetLevel)
	if not AntiExploit.CheckRateLimit(player, "Shop", GameConfig.RateLimits.Shop) then
		return fail("Calma! Aguarde um instante.")
	end
	if not isInteger(targetLevel) then
		return fail("Pedido inválido.")
	end
	if not inStory(player) then
		return fail("A oficina só abre no Modo História.")
	end
	if not PlayerDataManager.IsLoaded(player) then
		return fail("Seus dados ainda estão carregando.")
	end

	local current = PlayerDataManager.GetMotoLevel(player)
	if current >= UpgradeConfig.MaxLevel then
		return fail("Sua moto já está no nível máximo!")
	end
	if targetLevel ~= current + 1 then
		return fail("Esse upgrade não está disponível.")
	end

	local cfg = UpgradeConfig.Levels[targetLevel]
	if not PlayerDataManager.TrySpend(player, cfg.Cost) then
		return fail("Dinheiro insuficiente (" .. Format.Money(cfg.Cost) .. ").")
	end

	PlayerDataManager.SetMotoLevel(player, targetLevel)
	MotoManager.ApplyStats(player)
	task.defer(MotoManager.RefreshSkin, player)
	return {
		Success = true,
		Message = string.format("Moto nova (nível %d)! Agora até %d km/h", targetLevel, cfg.Speed * GameConfig.Moto.SpeedDisplayFactor),
		NewLevel = targetLevel,
	}
end

function ShopManager.UnlockArea(player: Player, areaId)
	if not AntiExploit.CheckRateLimit(player, "Shop", GameConfig.RateLimits.Shop) then
		return fail("Calma! Aguarde um instante.")
	end
	if not isInteger(areaId) then
		return fail("Pedido inválido.")
	end
	if not inStory(player) then
		return fail("Bairros só podem ser liberados no Modo História.")
	end
	local area = AreaConfig.Get(areaId)
	if not area then
		return fail("Área inexistente.")
	end
	if not PlayerDataManager.IsLoaded(player) then
		return fail("Seus dados ainda estão carregando.")
	end
	if PlayerDataManager.IsAreaUnlocked(player, areaId) then
		return fail("Você já desbloqueou essa área.")
	end
	if AreaConfig.RequireSequentialUnlock and areaId > 1 and not PlayerDataManager.IsAreaUnlocked(player, areaId - 1) then
		return fail("Desbloqueie " .. AreaConfig.Get(areaId - 1).Name .. " primeiro.")
	end
	if not PlayerDataManager.TrySpend(player, area.Cost) then
		return fail("Dinheiro insuficiente (" .. Format.Money(area.Cost) .. ").")
	end

	PlayerDataManager.UnlockArea(player, areaId)
	return {
		Success = true,
		Message = string.format("%s desbloqueada! Pedidos de lá pagam %sx", area.Name, (string.format("%.1f", area.PayMultiplier):gsub("%.", ","))),
		AreaId = areaId,
	}
end

function ShopManager.Init()
	Remotes.RequestBuyUpgrade.OnServerInvoke = ShopManager.BuyUpgrade
	Remotes.RequestUnlockArea.OnServerInvoke = ShopManager.UnlockArea
end

return ShopManager
