-- Clima do servidor (todos veem o mesmo): sol e, às vezes, chuva. Publica Workspace.Clima. Ajuste em GameConfig.World.Weather.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

local WeatherManager = {}

function WeatherManager.Set(weather: string)
	Workspace:SetAttribute("Clima", weather)
end

function WeatherManager.Init()
	local cfg = GameConfig.World.Weather
	WeatherManager.Set("Sol")
	if not cfg or not cfg.Enabled then
		return
	end
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(cfg.SunMinutes[1], cfg.SunMinutes[2]) * 60)
			if rng:NextNumber() < cfg.RainChance then
				WeatherManager.Set("Chuva")
				task.wait(rng:NextNumber(cfg.RainMinutes[1], cfg.RainMinutes[2]) * 60)
				WeatherManager.Set("Sol")
			end
		end
	end)
end

return WeatherManager
