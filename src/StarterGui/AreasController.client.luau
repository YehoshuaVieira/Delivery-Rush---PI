-- Janela de Bairros. Só envia a intenção de desbloquear; o ShopManager valida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local Format = require(Modules:WaitForChild("Format"))
local UI = require(Modules:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local C, F, new = UI.Color, UI.Font, UI.new
local MUTED = UI.Muted
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

local ROW_H = 60
local areaCount = #AreaConfig.Areas

local window, face = UI.Panel({
	Name = "Window",
	Size = UDim2.fromOffset(480, 114 + areaCount * (ROW_H + 8) + 34),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Radius = 16,
	Visible = false,
	Parent = gui,
})

UI.IconImage("mapa", 22, C.Accent, { Position = UDim2.fromOffset(22, 23), Parent = face })
UI.Text({
	Text = "BAIRROS",
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
UI.Text({
	Text = "Bairros mais caros pagam mais por entrega. Os pedidos só aparecem nos bairros liberados.",
	Font = F.Body,
	TextSize = 14,
	Transparency = MUTED,
	Wrapped = true,
	Position = UDim2.fromOffset(22, 60),
	Size = UDim2.new(1, -44, 0, 38),
	Parent = face,
})

local list = new("Frame", {
	Name = "List",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(22, 108),
	Size = UDim2.new(1, -44, 1, -142),
	ZIndex = 2,
	Parent = face,
})
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
	Parent = list,
})

local feedbackLabel = UI.Text({
	Font = F.Text,
	TextSize = 14,
	XAlign = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 22, 1, -8),
	Size = UDim2.new(1, -44, 0, 22),
	Parent = face,
})

local cards = {}
local busy = false
local refresh

local function tryUnlock(area)
	local unlocked = AreaConfig.ParseUnlocked(player:GetAttribute("UnlockedAreas"))
	if busy or unlocked[area.Id] then
		return
	end
	busy = true
	refresh()
	local ok, result = pcall(function()
		return Remotes.RequestUnlockArea:InvokeServer(area.Id)
	end)
	busy = false
	if ok and type(result) == "table" then
		feedbackLabel.Text = UI.StripEmoji(tostring(result.Message))
		feedbackLabel.TextColor3 = result.Success and C.Accent or C.Red
		if result.Success and cards[area.Id] then
			UI.Show(cards[area.Id].Holder, 0.5)
		end
	else
		feedbackLabel.Text = "Erro de conexão. Tente de novo."
		feedbackLabel.TextColor3 = C.Red
	end
	refresh()
end

for _, area in ipairs(AreaConfig.Areas) do
	local holder, cardFace = UI.Panel({
		Name = "Area" .. area.Id,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Color = C.Raised,
		Transparency = 0,
		Shadow = false,
		Stroke = false,
		Radius = 10,
		LayoutOrder = area.Id,
		Parent = list,
	})
	local bar = new("Frame", {
		Name = "ColorBar",
		BackgroundColor3 = area.Color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(0, 5, 1, -24),
		ZIndex = 2,
		Parent = cardFace,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	UI.Text({
		Text = area.Name,
		Font = F.Number,
		TextSize = 17,
		Position = UDim2.fromOffset(28, 9),
		Size = UDim2.new(1, -210, 0, 22),
		Truncate = true,
		Parent = cardFace,
	})
	UI.Text({
		Text = "paga " .. UI.Multiplier(area.PayMultiplier) .. " por entrega",
		Font = F.Body,
		TextSize = 13,
		Transparency = MUTED,
		Position = UDim2.fromOffset(28, 31),
		Size = UDim2.new(1, -210, 0, 18),
		Parent = cardFace,
	})
	local actionHolder, actionFace = UI.Panel({
		Name = "Action",
		Size = UDim2.fromOffset(164, 38),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -11, 0.5, 0),
		Color = C.Accent,
		Transparency = 0,
		Shadow = false,
		Stroke = false,
		Radius = 8,
		Parent = cardFace,
	})
	actionHolder.ZIndex = 3
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = actionFace })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = row,
	})
	local actionIcon = UI.IconImage("check", 14, C.Accent, { LayoutOrder = 1, Parent = row })
	local actionText = UI.Text({
		Font = F.Title,
		TextSize = 14,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = row,
	})
	local hit = UI.Hit(actionHolder, actionFace)
	hit.Activated:Connect(function()
		tryUnlock(area)
	end)
	cards[area.Id] = { Holder = holder, Face = actionFace, Icon = actionIcon, Text = actionText }
end

refresh = function()
	local unlocked = AreaConfig.ParseUnlocked(player:GetAttribute("UnlockedAreas"))
	local money = player:GetAttribute("Money") or 0
	moneyLabel.Text = Format.Money(money)
	for id, card in pairs(cards) do
		local area = AreaConfig.Get(id)
		if unlocked[id] then
			card.Face.BackgroundTransparency = 1
			card.Icon.Visible = true
			card.Text.Text = "LIBERADO"
			card.Text.TextColor3 = C.Accent
			card.Text.TextTransparency = 0
		elseif AreaConfig.RequireSequentialUnlock and not unlocked[id - 1] then
			card.Face.BackgroundColor3 = C.Panel
			card.Face.BackgroundTransparency = 0
			card.Icon.Visible = false
			card.Text.Text = Format.Money(area.Cost)
			card.Text.TextColor3 = C.Text
			card.Text.TextTransparency = MUTED
		else
			local canAfford = money >= area.Cost
			card.Face.BackgroundColor3 = canAfford and C.Accent or C.Panel
			card.Face.BackgroundTransparency = 0
			card.Icon.Visible = false
			card.Text.Text = busy and "..." or ("LIBERAR " .. Format.Money(area.Cost))
			card.Text.TextColor3 = canAfford and C.AccentInk or C.Text
			card.Text.TextTransparency = canAfford and 0 or MUTED
		end
	end
end

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
player:GetAttributeChangedSignal("UnlockedAreas"):Connect(refresh)
refresh()
