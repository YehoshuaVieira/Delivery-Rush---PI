-- Ponto de entrada do servidor: inicia os sistemas (a ordem importa).

local Players = game:GetService("Players")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local AntiExploit = require(script.Parent.AntiExploitValidation)
local MotoManager = require(script.Parent.MotoManager)
local OrderManager = require(script.Parent.OrderManager)
local ShopManager = require(script.Parent.ShopManager)
local IncidentManager = require(script.Parent.IncidentManager)
local DayNightCycle = require(script.Parent.DayNightCycle)
local WeatherManager = require(script.Parent.WeatherManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local SurvivalManager = require(script.Parent.SurvivalManager)
local MissionManager = require(script.Parent.MissionManager)
local CosmeticManager = require(script.Parent.CosmeticManager)

Players.RespawnTime = 2

AntiExploit.Init()
MotoManager.Init()
OrderManager.Init()
ShopManager.Init()
IncidentManager.Init()
DayNightCycle.Init()
WeatherManager.Init()
LeaderboardManager.Init()
SurvivalManager.Init()
MissionManager.Init()
CosmeticManager.Init()
PlayerDataManager.Init()

print("[GameServer] Delivery Rush iniciado!")
