-- Escolha de habilidade da Sobrevivência: 3 cartas a cada 10 entregas (inspirado em Hades / Vampire Survivors).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AbilityConfig = require(Modules:WaitForChild("AbilityConfig"))
local UI = require(Modules:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local C, F, new = UI.Color, UI.Font, UI.new
local MUTED = UI.Muted
local TOUCH = UI.IsTouch()
local CARD_H = 352
local SHORT_CARD_H = 240 -- tela larga e baixa (celular deitado): cartas lado a lado, mais baixas

-- string.upper não mexe em letras acentuadas (UTF-8)
local ACCENTS = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç" }
local function caps(s: string): string
	return (string.upper(s):gsub("[\195][\128-\191]", ACCENTS))
end

for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("GuiObject") or child:IsA("UIScale") then
		child:Destroy()
	end
end
local uiScale = new("UIScale", { Parent = gui })

local dim = new("Frame", {
	Name = "Dim",
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 0,
	Parent = gui,
})

local column = new("Frame", {
	Name = "Column",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(860, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
})
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 10),
	Parent = column,
})
local kicker = UI.Text({
	Font = F.Title,
	TextSize = 16,
	Color = C.Accent,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 20),
	LayoutOrder = 1,
	Parent = column,
})
UI.Text({
	Text = "ESCOLHA UMA HABILIDADE",
	Font = F.Title,
	TextSize = 34,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 40),
	LayoutOrder = 2,
	Parent = column,
})
local subtitle = UI.Text({
	Text = "Ela vale até o fim da partida. O próximo pedido só começa depois da escolha.",
	Font = F.Body,
	TextSize = 16,
	Transparency = MUTED,
	XAlign = Enum.TextXAlignment.Center,
	Wrapped = true,
	Size = UDim2.new(1, 0, 0, 22),
	LayoutOrder = 3,
	Parent = column,
})
local timerBar = new("Frame", {
	Name = "Timer",
	BackgroundColor3 = C.Text,
	BackgroundTransparency = 0.85,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(240, 4),
	LayoutOrder = 4,
	Parent = column,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = timerBar })
local timerFill = new("Frame", {
	BackgroundColor3 = C.Accent,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = timerBar,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = timerFill })
new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 8), LayoutOrder = 5, Parent = column })

local row = new("Frame", {
	Name = "Cards",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, CARD_H),
	LayoutOrder = 6,
	Parent = column,
})
local rowLayout = new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 16),
	Parent = row,
})

local KIND_TEXT = { Passiva = "PASSIVA", ["Automática"] = "AUTOMÁTICA", Ativa = "ATIVA" }

local cards = {}
local current = nil -- oferta aberta: { Ids, Deadline, Timeout }
local cardWidth, listMode, shortMode = 260, false, false

local function layout()
	local vp = Workspace.CurrentCamera.ViewportSize
	uiScale.Scale = UI.ScaleFor(vp, TOUCH)
	local w = vp.X / uiScale.Scale
	local h = vp.Y / uiScale.Scale
	local available = math.min(860, w - 32)
	column.Size = UDim2.fromOffset(available, 0)
	cardWidth = math.min(260, math.floor((available - 32) / 3))
	-- tela estreita: cartas viram faixas horizontais, uma embaixo da outra; tela baixa: cartas compactas
	listMode = cardWidth < 190
	shortMode = not listMode and h < 560
	subtitle.Visible = h >= 560
	rowLayout.FillDirection = listMode and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, listMode and 10 or 16)
	local count = math.max(#cards, 1)
	row.Size = UDim2.new(1, 0, 0, listMode and (count * 124 + (count - 1) * 10) or (shortMode and SHORT_CARD_H or CARD_H))
	for _, card in ipairs(cards) do
		card.Layout()
	end
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

local function pick(id: string)
	if not current then
		return
	end
	current = nil
	Remotes.RequestPickAbility:FireServer(id)
	for _, card in ipairs(cards) do
		if card.Id == id then
			card.Edge.Color = C.Accent
			card.Edge.Transparency = 0
			card.Edge.Thickness = 3
			UI.Show(card.Holder, 1.5)
		else
			UI.Hide(card.Holder)
		end
	end
	task.delay(0.55, function()
		if not current then
			gui.Enabled = false
			player:SetAttribute("PickingAbility", nil)
		end
	end)
end

local function makeCard(index: number, ability)
	local rarity = AbilityConfig.Rarity[ability.Rarity]
	local holder, face = UI.Panel({
		Name = "Card" .. index,
		Size = UDim2.fromOffset(260, CARD_H),
		LayoutOrder = index,
		Parent = row,
	})
	local edge = face:FindFirstChild("Edge")
	-- faixa da raridade no topo
	local band = new("Frame", {
		Name = "Band",
		BackgroundColor3 = rarity.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = 2,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 2), Parent = band })
	local disc = new("Frame", {
		Name = "Disc",
		BackgroundColor3 = C.Raised,
		ZIndex = 2,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disc })
	new("UIStroke", { Color = rarity.Color, Thickness = 2, Transparency = 0.2, Parent = disc })
	local icon = UI.IconImage(ability.Icon, 36, rarity.Color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = disc,
	})
	local rarityText = UI.Text({
		Text = caps(ability.Rarity),
		Font = F.Title,
		TextSize = 14,
		Color = rarity.Color,
		Parent = face,
	})
	local name = UI.Text({
		Text = ability.Name,
		Font = F.Title,
		TextSize = 22,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Parent = face,
	})
	local tagline = UI.Text({
		Text = ability.Tagline,
		Font = F.Body,
		TextSize = 15,
		Transparency = MUTED,
		Parent = face,
	})
	local description = UI.Text({
		Text = ability.Description,
		Font = F.Body,
		TextSize = 16,
		Transparency = 0.08,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Parent = face,
	})
	local kindText = KIND_TEXT[ability.Kind] or caps(ability.Kind)
	local input = UI.InputKind()
	if ability.Key and input == "Keyboard" then
		kindText ..= "  •  TECLA " .. caps(ability.Key)
	elseif ability.Pad and input == "Gamepad" then
		kindText ..= "  •  BOTÃO " .. ability.Pad
	end
	local kind = UI.Text({
		Text = kindText,
		Font = F.Title,
		TextSize = 13,
		Transparency = MUTED,
		Parent = face,
	})
	local keycap = UI.Keycap(tostring(index), { Height = 24, Width = 24, TextSize = 15, Gamepad = AbilityConfig.PadPick[index], Parent = face })
	local hit = UI.Hit(holder, face)
	hit.Activated:Connect(function()
		pick(ability.Id)
	end)
	hit.MouseEnter:Connect(function()
		edge.Color = rarity.Color
		edge.Transparency = 0.1
	end)
	hit.MouseLeave:Connect(function()
		edge.Color = C.Text
		edge.Transparency = 0.9
	end)

	local card = { Id = ability.Id, Holder = holder, Edge = edge }
	function card.Layout()
		if listMode then
			holder.Size = UDim2.new(1, 0, 0, 124)
			disc.Size = UDim2.fromOffset(56, 56)
			disc.Position = UDim2.fromOffset(16, 16)
			icon.Size = UDim2.fromOffset(30, 30)
			rarityText.Position = UDim2.fromOffset(86, 12)
			rarityText.Size = UDim2.new(1, -140, 0, 18)
			name.Position = UDim2.fromOffset(86, 30)
			name.Size = UDim2.new(1, -140, 0, 26)
			name.TextWrapped = false
			name.TextTruncate = Enum.TextTruncate.AtEnd
			tagline.Visible = false
			description.Position = UDim2.fromOffset(86, 58)
			description.Size = UDim2.new(1, -100, 0, 56)
			description.TextSize = 15
			kind.Visible = false
			if keycap then
				keycap.AnchorPoint = Vector2.new(1, 0)
				keycap.Position = UDim2.new(1, -14, 0, 14)
			end
		elseif shortMode then
			holder.Size = UDim2.fromOffset(cardWidth, SHORT_CARD_H)
			disc.Size = UDim2.fromOffset(52, 52)
			disc.Position = UDim2.fromOffset(14, 16)
			icon.Size = UDim2.fromOffset(28, 28)
			rarityText.Position = UDim2.fromOffset(78, 22)
			rarityText.Size = UDim2.new(1, -120, 0, 18)
			kind.Visible = true
			kind.Position = UDim2.fromOffset(78, 42)
			kind.Size = UDim2.new(1, -92, 0, 18)
			name.Position = UDim2.fromOffset(14, 80)
			name.Size = UDim2.new(1, -28, 0, 48)
			name.TextWrapped = true
			name.TextTruncate = Enum.TextTruncate.None
			tagline.Visible = false
			description.Position = UDim2.fromOffset(14, 130)
			description.Size = UDim2.new(1, -28, 0, 100)
			description.TextSize = 15
			if keycap then
				keycap.AnchorPoint = Vector2.new(1, 0)
				keycap.Position = UDim2.new(1, -12, 0, 12)
			end
		else
			holder.Size = UDim2.fromOffset(cardWidth, CARD_H)
			disc.Size = UDim2.fromOffset(68, 68)
			disc.Position = UDim2.fromOffset(18, 24)
			icon.Size = UDim2.fromOffset(36, 36)
			rarityText.Position = UDim2.fromOffset(18, 104)
			rarityText.Size = UDim2.new(1, -36, 0, 18)
			name.Position = UDim2.fromOffset(18, 124)
			name.Size = UDim2.new(1, -36, 0, 54)
			name.TextWrapped = true
			name.TextTruncate = Enum.TextTruncate.None
			tagline.Visible = true
			tagline.Position = UDim2.fromOffset(18, 180)
			tagline.Size = UDim2.new(1, -36, 0, 20)
			description.Position = UDim2.fromOffset(18, 208)
			description.Size = UDim2.new(1, -36, 0, 100)
			description.TextSize = 16
			kind.Visible = true
			kind.Position = UDim2.new(0, 18, 1, -32)
			kind.Size = UDim2.new(1, -60, 0, 18)
			if keycap then
				keycap.AnchorPoint = Vector2.new(1, 1)
				keycap.Position = UDim2.new(1, -14, 1, -14)
			end
		end
	end
	return card
end

local function open(data)
	for _, card in ipairs(cards) do
		card.Holder:Destroy()
	end
	table.clear(cards)
	local ids = data and data.Ids or {}
	for i, id in ipairs(ids) do
		local ability = AbilityConfig.Get(id)
		if ability then
			table.insert(cards, makeCard(i, ability))
		end
	end
	if #cards == 0 then
		return
	end
	local timeout = data.Timeout or AbilityConfig.PickTimeout
	current = { Ids = ids, Deadline = os.clock() + timeout, Timeout = timeout }
	kicker.Text = string.format("%d ENTREGAS!", data.Milestone or 0)
	player:SetAttribute("PickingAbility", true)
	gui.Enabled = true
	layout()
	-- cartas "distribuídas" uma a uma
	for i, card in ipairs(cards) do
		card.Holder.Visible = false
		task.delay(0.08 * (i - 1), function()
			UI.Show(card.Holder, 1.3)
		end)
	end
end

local function close()
	current = nil
	gui.Enabled = false
	player:SetAttribute("PickingAbility", nil)
end

Remotes.AbilityOffer.OnClientEvent:Connect(open)
Remotes.SurvivalEnded.OnClientEvent:Connect(close)
player:GetAttributeChangedSignal("GameMode"):Connect(function()
	if player:GetAttribute("GameMode") ~= "Survival" then
		close()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not current then
		return
	end
	local index = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
		[Enum.KeyCode.ButtonX] = 1, [Enum.KeyCode.ButtonY] = 2, [Enum.KeyCode.ButtonB] = 3 })[input.KeyCode]
	if index and cards[index] then
		pick(cards[index].Id)
	end
end)

RunService.RenderStepped:Connect(function()
	if current then
		local left = math.max(0, current.Deadline - os.clock())
		timerFill.Size = UDim2.fromScale(left / current.Timeout, 1)
		timerFill.BackgroundColor3 = left < 6 and C.Amber or C.Accent
	end
end)

layout()
