-- Ciclo de dia e noite (só visual). Ajuste em GameConfig.World.DayNight.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

local DayNightCycle = {}

local DAY_START, DAY_END = 6, 18.5

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

function DayNightCycle.Init()
	local cfg = GameConfig.World.DayNight
	if not cfg or not cfg.Enabled then
		return
	end
	local dayHours = DAY_END - DAY_START
	local nightHours = 24 - dayHours
	local dayRate = dayHours / (cfg.DayMinutes * 60)
	local nightRate = nightHours / (cfg.NightMinutes * 60)
	Lighting.ClockTime = cfg.StartHour or 9

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0
		local clock = Lighting.ClockTime
		local isDay = clock >= DAY_START and clock < DAY_END
		clock = (clock + step * (isDay and dayRate or nightRate)) % 24
		Lighting.ClockTime = clock

		local daylight = math.clamp(math.min(clock - (DAY_START - 0.5), (DAY_END + 0.5) - clock) / 1.5, 0, 1)
		Lighting.Brightness = 1 + daylight * 2
		Lighting.Ambient = lerpColor(Color3.fromRGB(95, 100, 135), Color3.fromRGB(70, 70, 70), daylight)
		Lighting.OutdoorAmbient = lerpColor(Color3.fromRGB(105, 110, 150), Color3.fromRGB(128, 128, 128), daylight)
	end)
end

return DayNightCycle
