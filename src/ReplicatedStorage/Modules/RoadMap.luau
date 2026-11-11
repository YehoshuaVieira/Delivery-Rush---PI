-- Diz se uma posição está na rua ou fora dela (calçada/lote), pelos BlockRects de cada bairro.

local Workspace = game:GetService("Workspace")

local RoadMap = {}

local DEFAULT_TOLERANCE = 0.8
local RELOAD_EVERY = 5

local areas = {}
local loadedCount = -1
local lastCheck = -math.huge

local function load()
	lastCheck = os.clock()
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Areas")
	if not folder then
		return
	end
	local children = folder:GetChildren()
	if #children == loadedCount then
		return
	end
	local list = {}
	for _, a in ipairs(children) do
		local text, center, size = a:GetAttribute("BlockRects"), a:GetAttribute("Center"), a:GetAttribute("Size")
		if type(text) == "string" and typeof(center) == "Vector3" and type(size) == "number" then
			local entry = { Center = center, Half = size / 2 + 40, Rects = {} }
			for x0, z0, x1, z1 in string.gmatch(text, "(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)") do
				table.insert(entry.Rects, { tonumber(x0), tonumber(z0), tonumber(x1), tonumber(z1) })
			end
			table.insert(list, entry)
		end
	end
	areas = list
	loadedCount = #children
end

function RoadMap.IsOffRoad(pos: Vector3, tolerance: number?): boolean
	if os.clock() - lastCheck > RELOAD_EVERY then
		load()
	end
	local t = tolerance or DEFAULT_TOLERANCE
	local x, z = pos.X, pos.Z
	for _, a in ipairs(areas) do
		if math.abs(x - a.Center.X) <= a.Half and math.abs(z - a.Center.Z) <= a.Half then
			for _, r in ipairs(a.Rects) do
				if x > r[1] + t and x < r[3] - t and z > r[2] + t and z < r[4] - t then
					return true
				end
			end
		end
	end
	return false
end

return RoadMap
