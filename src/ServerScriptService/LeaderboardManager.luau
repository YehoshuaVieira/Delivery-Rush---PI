-- Ranking global de recordes da Sobrevivência (OrderedDataStore) mostrado no Workspace.Map.PainelRanking.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Modules").Format)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local STORE_NAME = "TopSobrevivencia_v1"
local REFRESH = 60
local ACCENT_HEX = "#2BD576"

local LeaderboardManager = {}

function LeaderboardManager.Init()
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if not ok then
		warn("[Leaderboard] indisponível: " .. tostring(store))
		return
	end

	local lastWritten = {}
	local function write(player: Player)
		if not PlayerDataManager.IsSaving(player) then
			return
		end
		local data = PlayerDataManager.GetData(player)
		local value = data and data.SurvivalBest
		if not value or value <= 0 or lastWritten[player] == value then
			return
		end
		local saved = pcall(function()
			store:SetAsync(tostring(player.UserId), value)
		end)
		if saved then
			lastWritten[player] = value
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		write(player)
		lastWritten[player] = nil
	end)

	local names = {}
	local function nameOf(userId: number): string
		if not names[userId] then
			local got, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			names[userId] = got and name or ("Jogador " .. userId)
		end
		return names[userId]
	end

	local function refreshBoard()
		local map = Workspace:FindFirstChild("Map")
		local board = map and map:FindFirstChild("PainelRanking")
		local list = board and board:FindFirstChild("Lista", true)
		if not list then
			return
		end
		local got, pages = pcall(function()
			return store:GetSortedAsync(false, 10, 1)
		end)
		if not got then
			return
		end
		local entries = pages:GetCurrentPage()
		for i = 1, 10 do
			local row = list:FindFirstChild("Linha" .. string.format("%02d", i))
			local nameLabel = row and row:FindFirstChild("Nome")
			local totalLabel = row and row:FindFirstChild("Total")
			if nameLabel and totalLabel then
				local e = entries[i]
				if e then
					local value = tonumber(e.value) or 0
					nameLabel.Text = nameOf(tonumber(e.key))
					nameLabel.TextTransparency = 0
					totalLabel.Text = string.format('<font color="%s">%s</font> %s', ACCENT_HEX, Format.Number(value), value == 1 and "entrega" or "entregas")
				else
					nameLabel.Text = "—"
					nameLabel.TextTransparency = 0.7
					totalLabel.Text = ""
				end
			end
		end
	end

	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				write(player)
			end
			refreshBoard()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardManager
