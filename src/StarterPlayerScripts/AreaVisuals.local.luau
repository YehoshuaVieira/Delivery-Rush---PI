-- Barreiras dos bairros bloqueados e clima visual de cada bairro (só estética).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Format = require(Modules:WaitForChild("Format"))
local UI = require(Modules:WaitForChild("UIKit"))
local TOUCH = UI.IsTouch()

local areasFolder = Workspace:WaitForChild("Map"):WaitForChild("Areas")

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "AreaTint"
colorCorrection.Parent = Lighting

local function survival(): boolean
	return player:GetAttribute("GameMode") == "Survival"
end

-- Na Sobrevivência só o bairro do modo fica aberto, independente do que o jogador liberou
local function isLocked(areaId: number): boolean
	if survival() then
		return areaId ~= GameConfig.Survival.AreaId
	end
	return not AreaConfig.ParseUnlocked(player:GetAttribute("UnlockedAreas"))[areaId]
end

local function signInfo(area): string
	if survival() then
		return "Fora da área da Sobrevivência"
	end
	return string.format("%s  •  paga %s  •  libere em Áreas%s", Format.Money(area.Cost), UI.Multiplier(area.PayMultiplier), TOUCH and "" or " (M)")
end

-- Placa da barreira no visual do UIKit (painel grafite + cadeado), montada uma vez por placa
local function styleSign(gui: BillboardGui, area)
	if gui:GetAttribute("Styled") then
		return
	end
	gui:SetAttribute("Styled", true)
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	gui.Size = UDim2.fromOffset(330, 84)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 350
	local _, face = UI.Panel({
		Name = "Placa",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Shadow = false,
		Parent = gui,
	})
	UI.IconImage("cadeado", 28, UI.Color.Text, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Parent = face,
	})
	UI.Text({
		Text = area.Name,
		Font = UI.Font.Number,
		TextSize = 22,
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -72, 0, 28),
		Truncate = true,
		Parent = face,
	})
	UI.Text({
		Name = "Info",
		Text = signInfo(area),
		Font = UI.Font.Body,
		TextSize = 14,
		Transparency = UI.Muted,
		Position = UDim2.fromOffset(60, 44),
		Size = UDim2.new(1, -72, 0, 20),
		Truncate = true,
		Parent = face,
	})
end

-- Aplica o estado (bloqueada/liberada) numa peça ou placa da barreira
local function applyBarrier(inst: Instance, area)
	local locked = isLocked(area.Id)
	if inst:IsA("BasePart") and inst.Name == "Wall" then
		inst.CanCollide = locked
		inst.Color = UI.Color.Red
		inst.Transparency = locked and 0.72 or 1
	elseif inst:IsA("BillboardGui") then
		inst.Enabled = locked
		styleSign(inst, area)
		local info = inst:FindFirstChild("Info", true)
		if info then
			info.Text = signInfo(area)
		end
	elseif inst:IsA("TextLabel") and inst.Parent and inst.Parent:IsA("BillboardGui") and inst.Name == "Text" then
		applyBarrier(inst.Parent, area)
	end
end

local function refreshArea(area)
	local folder = areasFolder:FindFirstChild(area.FolderName)
	local barrier = folder and folder:FindFirstChild("Barrier")
	if barrier then
		for _, d in ipairs(barrier:GetDescendants()) do
			applyBarrier(d, area)
		end
	end
end

local function refreshAll()
	for _, area in ipairs(AreaConfig.Areas) do
		refreshArea(area)
	end
end

for _, area in ipairs(AreaConfig.Areas) do
	task.spawn(function()
		local folder = areasFolder:WaitForChild(area.FolderName, 30)
		if not folder then
			return
		end
		-- escuta só a barreira: o bairro inteiro chega aos poucos pelo streaming (milhares de peças)
		local function hook(barrier)
			barrier.DescendantAdded:Connect(function(d)
				applyBarrier(d, area)
			end)
			refreshArea(area)
		end
		local barrier = folder:FindFirstChild("Barrier")
		if barrier then
			hook(barrier)
		else
			folder.ChildAdded:Connect(function(c)
				if c.Name == "Barrier" then
					hook(c)
				end
			end)
		end
	end)
end
player:GetAttributeChangedSignal("UnlockedAreas"):Connect(refreshAll)
player:GetAttributeChangedSignal("GameMode"):Connect(refreshAll)

local function areaAt(position: Vector3)
	for _, area in ipairs(AreaConfig.Areas) do
		local folder = areasFolder:FindFirstChild(area.FolderName)
		local center = folder and folder:GetAttribute("Center")
		local size = folder and folder:GetAttribute("Size")
		if center and size then
			local half = size / 2
			if math.abs(position.X - center.X) <= half and math.abs(position.Z - center.Z) <= half then
				return area
			end
		end
	end
	return nil
end

local currentAreaId = -1
while true do
	task.wait(0.5)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local area = areaAt(root.Position)
		local id = area and area.Id or 0
		if id ~= currentAreaId then
			currentAreaId = id
			player:SetAttribute("CurrentAreaId", id)
			TweenService:Create(colorCorrection, TweenInfo.new(1.5), {
				TintColor = area and area.Tint or Color3.new(1, 1, 1),
				Saturation = area and area.Saturation or 0,
			}):Play()
		end
	end
end
