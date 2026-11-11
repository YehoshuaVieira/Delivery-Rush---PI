-- Janela da Oficina (upgrades). Só envia a intenção de compra; o ShopManager valida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local Format = require(Modules:WaitForChild("Format"))
local UI = require(Modules:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local C, F, new = UI.Color, UI.Font, UI.new
local MUTED = UI.Muted
local KMH = GameConfig.Moto.SpeedDisplayFactor
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("GuiObject") then
		child:Destroy()
	end
end

local uiScale = gui:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = gui })
local function updateScale()
	uiScale.Scale = UI.ScaleFor(Workspace.CurrentCamera.ViewportSize, TOUCH)
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

local window, face = UI.Panel({
	Name = "Window",
	Size = UDim2.fromOffset(440, 372),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Radius = 16,
	Visible = false,
	Parent = gui,
})

UI.IconImage("chave", 22, C.Accent, { Position = UDim2.fromOffset(22, 23), Parent = face })
UI.Text({
	Text = "OFICINA",
	Font = F.Title,
	TextSize = 22,
	Position = UDim2.fromOffset(54, 18),
	Size = UDim2.fromOffset(200, 32),
	Parent = face,
})
local closeHolder, closeFace = UI.Panel({
	Name = "Close",
	Size = UDim2.fromOffset(34, 34),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Color = C.Raised,
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 9,
	Parent = face,
})
closeHolder.ZIndex = 3
UI.IconImage("xis", 13, C.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = closeFace })
local closeButton = UI.Hit(closeHolder, closeFace)

local moneyLabel = UI.Text({
	Font = F.Number,
	TextSize = 18,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 22),
	Size = UDim2.fromOffset(160, 24),
	Parent = face,
})

local currentLabel = UI.Text({
	Font = F.Body,
	TextSize = 14,
	Transparency = MUTED,
	Position = UDim2.fromOffset(22, 62),
	Size = UDim2.new(1, -44, 0, 20),
	Parent = face,
})
local pipsRow = new("Frame", {
	Name = "Pips",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(22, 88),
	Size = UDim2.new(1, -44, 0, 8),
	ZIndex = 2,
	Parent = face,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = pipsRow,
})
local count = UpgradeConfig.MaxLevel + 1
local pips = {}
for level = 0, UpgradeConfig.MaxLevel do
	local pip = new("Frame", {
		Name = "Pip" .. level,
		LayoutOrder = level,
		BorderSizePixel = 0,
		Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0),
		ZIndex = 2,
		Parent = pipsRow,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
	pips[level] = pip
end

local nextHolder, nextFace = UI.Panel({
	Name = "NextCard",
	Size = UDim2.new(1, -44, 0, 136),
	Position = UDim2.fromOffset(22, 114),
	Color = C.Raised,
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 12,
	Parent = face,
})
nextHolder.ZIndex = 2
local nextTitle = UI.Text({
	Font = F.Title,
	TextSize = 13,
	Transparency = MUTED,
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -36, 0, 18),
	Parent = nextFace,
})
local nextSpeed = UI.Text({
	Font = F.Number,
	TextSize = 40,
	Position = UDim2.fromOffset(16, 32),
	Size = UDim2.new(1, -32, 0, 46),
	Parent = nextFace,
})
local nextGains = UI.Text({
	Font = F.Body,
	TextSize = 14,
	Transparency = MUTED,
	Position = UDim2.fromOffset(18, 80),
	Size = UDim2.new(1, -36, 0, 18),
	Parent = nextFace,
})
local costLabel = UI.Text({
	Font = F.Number,
	TextSize = 17,
	Position = UDim2.fromOffset(18, 102),
	Size = UDim2.new(1, -36, 0, 22),
	Parent = nextFace,
})

local buyHolder, buyFace = UI.Panel({
	Name = "Buy",
	Size = UDim2.new(1, -44, 0, 50),
	Position = UDim2.fromOffset(22, 266),
	Color = C.Accent,
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 10,
	Parent = face,
})
buyHolder.ZIndex = 2
local buyText = UI.Text({
	Font = F.Title,
	TextSize = 17,
	Color = C.AccentInk,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Parent = buyFace,
})
local buyButton = UI.Hit(buyHolder, buyFace)

local feedbackLabel = UI.Text({
	Font = F.Text,
	TextSize = 14,
	XAlign = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(22, 326),
	Size = UDim2.new(1, -44, 0, 22),
	Parent = face,
})

local busy = false

local function refresh()
	local level = player:GetAttribute("MotoLevel") or 0
	local money = player:GetAttribute("Money") or 0
	local current = UpgradeConfig.Get(level)
	currentLabel.Text = string.format("Sua moto: nível %d de %d  •  %d km/h", level, UpgradeConfig.MaxLevel, current.Speed * KMH)
	moneyLabel.Text = Format.Money(money)
	for l, pip in pairs(pips) do
		pip.BackgroundColor3 = l <= level and C.Accent or C.Text
		pip.BackgroundTransparency = l <= level and 0 or 0.86
	end

	if level >= UpgradeConfig.MaxLevel then
		nextTitle.Text = "NÍVEL MÁXIMO"
		nextSpeed.Text = string.format("%d km/h", current.Speed * KMH)
		nextGains.Text = "Você já tem a moto mais rápida da cidade."
		costLabel.Text = ""
		buyHolder.Visible = false
		return
	end

	local nextCfg = UpgradeConfig.Get(level + 1)
	local accelGain = math.floor((nextCfg.Acceleration / current.Acceleration - 1) * 100 + 0.5)
	nextTitle.Text = string.format("PRÓXIMA MOTO  •  NÍVEL %d", level + 1)
	nextSpeed.Text = string.format("%d km/h", nextCfg.Speed * KMH)
	nextGains.Text = string.format("+%d km/h de velocidade  •  +%d%% de aceleração", (nextCfg.Speed - current.Speed) * KMH, accelGain)
	costLabel.Text = "Custa " .. Format.Money(nextCfg.Cost)

	local canAfford = money >= nextCfg.Cost
	buyHolder.Visible = true
	buyFace.BackgroundColor3 = canAfford and C.Accent or C.Raised
	buyText.TextColor3 = canAfford and C.AccentInk or C.Text
	buyText.TextTransparency = canAfford and 0 or MUTED
	if busy then
		buyText.Text = "..."
	elseif canAfford then
		buyText.Text = "COMPRAR POR " .. Format.Money(nextCfg.Cost)
	else
		buyText.Text = "FALTAM " .. Format.Money(nextCfg.Cost - money)
	end
end

buyButton.Activated:Connect(function()
	if busy then
		return
	end
	local level = player:GetAttribute("MotoLevel") or 0
	if level >= UpgradeConfig.MaxLevel then
		return
	end
	if (player:GetAttribute("Money") or 0) < UpgradeConfig.Get(level + 1).Cost then
		UI.Show(buyHolder, 0.3)
		return
	end
	busy = true
	refresh()
	local ok, result = pcall(function()
		return Remotes.RequestBuyUpgrade:InvokeServer(level + 1)
	end)
	busy = false
	if ok and type(result) == "table" then
		feedbackLabel.Text = UI.StripEmoji(tostring(result.Message))
		feedbackLabel.TextColor3 = result.Success and C.Accent or C.Red
		if result.Success then
			UI.Show(nextHolder, 0.6)
		end
	else
		feedbackLabel.Text = "Erro de conexão. Tente de novo."
		feedbackLabel.TextColor3 = C.Red
	end
	refresh()
end)

closeButton.Activated:Connect(function()
	window.Visible = false
end)

window:GetPropertyChangedSignal("Visible"):Connect(function()
	if window.Visible and not window:GetAttribute("Hiding") then
		feedbackLabel.Text = ""
		refresh()
		UI.Show(window, 0.4)
	end
end)

player:GetAttributeChangedSignal("Money"):Connect(refresh)
player:GetAttributeChangedSignal("MotoLevel"):Connect(refresh)
refresh()
