-- Níveis da moto: Speed (studs/s), Acceleration (studs/s²) e Cost. O nível 0 é grátis.

local UpgradeConfig = {}

UpgradeConfig.Levels = {
	[0] = { Speed = 40, Acceleration = 30, Cost = 0 },
	[1] = { Speed = 50, Acceleration = 37, Cost = 500 },
	[2] = { Speed = 62, Acceleration = 45, Cost = 1500 },
	[3] = { Speed = 76, Acceleration = 54, Cost = 4000 },
	[4] = { Speed = 92, Acceleration = 64, Cost = 9000 },
	[5] = { Speed = 110, Acceleration = 76, Cost = 20000 },
}

UpgradeConfig.MaxLevel = 5

-- Retorna a config de um nível (limitado entre 0 e MaxLevel)
function UpgradeConfig.Get(level: number)
	level = math.clamp(math.floor(tonumber(level) or 0), 0, UpgradeConfig.MaxLevel)
	return UpgradeConfig.Levels[level]
end

return UpgradeConfig
