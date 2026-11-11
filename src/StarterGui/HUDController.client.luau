-- HUD montado em código com o UIKit. Só exibe dados e envia intenções; o dinheiro é decidido no servidor.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local PaymentCalculator = require(Modules:WaitForChild("PaymentCalculator"))
local Format = require(Modules:WaitForChild("Format"))
local UI = require(Modules:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local C, F, new = UI.Color, UI.Font, UI.new
local MUTED = UI.Muted
local BEST_MULTIPLIER = GameConfig.Payment.SpeedCurve[1].Multiplier
local KMH = GameConfig.Moto.SpeedDisplayFactor
local MIN_BOOST = GameConfig.Maneuver.MinChargeToBoost

local M = 16
local WALLET_W, RIGHT_W = 180, 288
local centerWidth = 440

local TOUCH = UI.IsTouch()

-- "Menu", "Survival" ou "Story" (definido pelo servidor)
local function gameMode(): string
	return player:GetAttribute("GameMode") or "Menu"
end
local function survival(): boolean
	return gameMode() == "Survival"
end

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

local function unscaled(px: number): number
	return px / math.max(uiScale.Scale, 0.01)
end

local function stack(name: string, anchor: Vector2, position: UDim2, width: number, align: Enum.HorizontalAlignment)
	local frame = new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(width, 520),
		Parent = gui,
	})
	new("UIListLayout", {
		HorizontalAlignment = align,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = frame,
	})
	return frame
end

local function hlist(parent: Instance, props: { [string]: any })
	local frame = new("Frame", {
		Name = props.Name or "Row",
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.new(1, 0, 0, 22),
		ZIndex = 2,
		Parent = parent,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.Align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.Padding or 6),
		Parent = frame,
	})
	return frame
end

local topStack = stack("TopStack", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, M), centerWidth, Enum.HorizontalAlignment.Center)
local rightStack = stack("RightStack", Vector2.new(1, 0), UDim2.new(1, -M, 0, M), RIGHT_W, Enum.HorizontalAlignment.Right)

local wallet, walletFace = UI.Panel({
	Name = "Wallet",
	Size = UDim2.fromOffset(WALLET_W, 50),
	Position = UDim2.fromOffset(M, M),
	Parent = gui,
})
local moneyText = UI.Text({
	Name = "Money",
	Text = "$0",
	Font = F.Number,
	TextSize = 30,
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 1, 0),
	Parent = walletFace,
})

-- Sobrevivência: a carteira vira o placar (entregas da partida e recorde)
local scoreFrame = new("Frame", {
	Name = "Score",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 2,
	Parent = walletFace,
})
UI.IconImage("caixa", 20, C.Accent, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Parent = scoreFrame })
local scoreText = UI.Text({
	Name = "Deliveries",
	Text = "0",
	Font = F.Number,
	TextSize = 30,
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(0, 70, 1, 0),
	Parent = scoreFrame,
})
UI.Text({
	Text = "RECORDE",
	Font = F.Title,
	TextSize = 13,
	Transparency = MUTED,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 6),
	Size = UDim2.fromOffset(80, 16),
	Parent = scoreFrame,
})
local bestText = UI.Text({
	Font = F.Number,
	TextSize = 19,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 22),
	Size = UDim2.fromOffset(70, 20),
	Parent = scoreFrame,
})
local function refreshScore()
	scoreText.Text = tostring(player:GetAttribute("SurvivalDeliveries") or 0)
	bestText.Text = tostring(player:GetAttribute("SurvivalBest") or 0)
end
player:GetAttributeChangedSignal("SurvivalDeliveries"):Connect(refreshScore)
player:GetAttributeChangedSignal("SurvivalBest"):Connect(refreshScore)
refreshScore()

local delta, deltaFace = UI.Panel({
	Name = "MoneyDelta",
	Size = UDim2.fromOffset(90, 32),
	Position = UDim2.fromOffset(M, M + 50 + 8),
	Color = C.Accent,
	Stroke = false,
	Radius = 10,
	Visible = false,
	Parent = gui,
})
local deltaText = UI.Text({
	Font = F.Number,
	TextSize = 18,
	Color = C.AccentInk,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Parent = deltaFace,
})
deltaText:GetPropertyChangedSignal("TextBounds"):Connect(function()
	delta.Size = UDim2.fromOffset(math.max(64, unscaled(deltaText.TextBounds.X) + 24), 32)
end)

local shownMoney = Instance.new("NumberValue")
shownMoney.Changed:Connect(function(value)
	moneyText.Text = Format.Money(value)
end)

local deltaToken, deltaSum = 0, 0
local function showDelta(amount: number)
	if amount == 0 then
		return
	end
	if delta.Visible and not delta:GetAttribute("Hiding") and (deltaSum > 0) == (amount > 0) then
		deltaSum += amount
	else
		deltaSum = amount
	end
	deltaToken += 1
	local token = deltaToken
	local gain = deltaSum > 0
	deltaFace.BackgroundColor3 = gain and C.Accent or C.Red
	deltaText.TextColor3 = gain and C.AccentInk or C.Text
	deltaText.Text = (gain and "+" or "-") .. Format.Money(math.abs(deltaSum))
	UI.Show(delta, 0.8)
	task.delay(1.8, function()
		if token == deltaToken then
			UI.Hide(delta)
		end
	end)
end

local lastMoney = nil
local settledAt = nil
local function refreshMoney()
	local money = player:GetAttribute("Money") or 0
	if player:GetAttribute("DataLoaded") and not settledAt then
		settledAt = os.clock() + 1.5
	end
	if lastMoney == nil or not settledAt or os.clock() < settledAt then
		shownMoney.Value = money
		moneyText.Text = Format.Money(money)
	elseif money ~= lastMoney then
		showDelta(money - lastMoney)
		TweenService:Create(shownMoney, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Value = money }):Play()
	end
	lastMoney = money
end
player:GetAttributeChangedSignal("Money"):Connect(refreshMoney)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refreshMoney)
refreshMoney()

local offRoad, offRoadFace = UI.Panel({
	Name = "OffRoad",
	Size = UDim2.fromOffset(300, 44),
	Color = C.Red,
	Transparency = 0,
	Stroke = false,
	Radius = 10,
	LayoutOrder = 1,
	Visible = false,
	Parent = topStack,
})
UI.Tape(offRoadFace, C.Text, 10)
local offPlate, offPlateFace = UI.Panel({
	Name = "Plate",
	Size = UDim2.new(1, -28, 1, -12),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 7,
	Parent = offRoadFace,
})
offPlate.ZIndex = 3
local offRow = hlist(offPlateFace, { Size = UDim2.fromScale(1, 1), Align = Enum.HorizontalAlignment.Center, Padding = 8 })
UI.Text({
	Text = "FORA DA RUA",
	Font = F.Title,
	TextSize = 15,
	Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 1,
	Parent = offRow,
})
local offFeeText = UI.Text({
	Font = F.Number,
	TextSize = 18,
	Color = C.Red,
	Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	Parent = offRow,
})
local function refreshOffRoadFee()
	local fee = player:GetAttribute("OffRoadNextFee") or GameConfig.OffRoad.Fee
	offFeeText.Text = "-" .. Format.Money(fee)
	offFeeText.Visible = not survival()
end
refreshOffRoadFee()
player:GetAttributeChangedSignal("OffRoadNextFee"):Connect(refreshOffRoadFee)
player:GetAttributeChangedSignal("OffRoad"):Connect(function()
	UI.SetShown(offRoad, player:GetAttribute("OffRoad") == true, 0.6)
end)

local toast, toastFace = UI.Panel({
	Name = "Delivered",
	Size = UDim2.fromOffset(300, 116),
	LayoutOrder = 2,
	Visible = false,
	Parent = topStack,
})
local toastTitleRow = hlist(toastFace, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20), Padding = 6 })
local toastIcon = UI.IconImage("check", 16, C.Accent, { LayoutOrder = 1, Parent = toastTitleRow })
local toastTitle = UI.Text({
	Font = F.Title,
	TextSize = 15,
	Color = C.Accent,
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	Parent = toastTitleRow,
})
local toastAmount = UI.Text({
	Font = F.Number,
	TextSize = 42,
	Color = C.Accent,
	Position = UDim2.fromOffset(15, 32),
	Size = UDim2.new(1, -30, 0, 46),
	Parent = toastFace,
})
local toastDetails = UI.Text({
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(16, 82),
	Size = UDim2.new(1, -32, 0, 20),
	Truncate = true,
	Parent = toastFace,
})

local notice, noticeFace = UI.Panel({
	Name = "Notice",
	Size = UDim2.fromOffset(240, 40),
	LayoutOrder = 3,
	Visible = false,
	Parent = topStack,
})
local noticeIcon = UI.IconImage("alerta", 18, C.Accent, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Parent = noticeFace,
})
local noticeText = UI.Text({
	Font = F.Text,
	TextSize = 16,
	Position = UDim2.fromOffset(42, 0),
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	Parent = noticeFace,
})
local function fitNotice()
	if noticeText.AutomaticSize ~= Enum.AutomaticSize.X then
		return
	end
	local w = unscaled(noticeText.TextBounds.X)
	if w + 56 > centerWidth then
		noticeText.AutomaticSize = Enum.AutomaticSize.None
		noticeText.TextWrapped = true
		noticeText.Size = UDim2.new(1, -56, 1, 0)
		notice.Size = UDim2.fromOffset(centerWidth, 58)
	else
		notice.Size = UDim2.fromOffset(math.max(140, w + 56), 40)
	end
end
noticeText:GetPropertyChangedSignal("TextBounds"):Connect(fitNotice)
local NOTICE_TONES = {
	info = { Face = C.Panel, Text = C.Text, Icon = C.Accent },
	bad = { Face = C.Red, Text = C.Text, Icon = C.Text },
	good = { Face = C.Accent, Text = C.AccentInk, Icon = C.AccentInk },
}
local noticeToken = 0
local function showNotice(text: string, duration: number?, tone: string?, icon: string?)
	noticeToken += 1
	local token = noticeToken
	local style = NOTICE_TONES[tone or "info"] or NOTICE_TONES.info
	noticeFace.BackgroundColor3 = style.Face
	noticeText.TextColor3 = style.Text
	noticeIcon.ImageColor3 = style.Icon
	noticeIcon.Image = UI.Icon[icon or (tone == "good" and "check" or "alerta")]
	noticeText.AutomaticSize = Enum.AutomaticSize.X
	noticeText.TextWrapped = false
	noticeText.Size = UDim2.new(0, 0, 1, 0)
	noticeText.Text = UI.StripEmoji(text)
	task.defer(fitNotice)
	UI.Show(notice, 0.6)
	task.delay(duration or 3, function()
		if noticeToken == token then
			UI.Hide(notice)
		end
	end)
end

local tutorial, tutorialFace = UI.Panel({
	Name = "Tutorial",
	Size = UDim2.fromOffset(centerWidth, 58),
	LayoutOrder = 4,
	Visible = false,
	Parent = topStack,
})
new("Frame", {
	Name = "Bar",
	BackgroundColor3 = C.Accent,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.new(0, 4, 1, -24),
	ZIndex = 2,
	Parent = tutorialFace,
})
local tutorialText = UI.Text({
	Font = F.Text,
	TextSize = 16,
	Wrapped = true,
	Position = UDim2.fromOffset(26, 0),
	Size = UDim2.new(1, -40, 1, 0),
	Parent = tutorialFace,
})

-- Coluna central: ocupa o vão entre a carteira e o pedido. Em tela estreita desce para baixo da carteira.
local topLayout = topStack:FindFirstChildOfClass("UIListLayout")
local function layoutCenter()
	local canvas = unscaled(Workspace.CurrentCamera.ViewportSize.X)
	local gapLeft = M + WALLET_W + 16
	local gapRight = canvas - M - RIGHT_W - 16
	if gapRight - gapLeft >= 260 then
		centerWidth = math.min(gapRight - gapLeft, 460)
		local centerX = math.clamp(canvas / 2, gapLeft + centerWidth / 2, math.max(gapLeft + centerWidth / 2, gapRight - centerWidth / 2))
		topStack.AnchorPoint = Vector2.new(0.5, 0)
		topStack.Position = UDim2.new(0, centerX, 0, M)
		topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	else
		centerWidth = math.max(220, gapRight - M)
		topStack.AnchorPoint = Vector2.zero
		topStack.Position = UDim2.fromOffset(M, M + 50 + 50)
		topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
	topStack.Size = UDim2.fromOffset(centerWidth, 520)
	offRoad.Size = UDim2.fromOffset(math.min(300, centerWidth), 44)
	toast.Size = UDim2.fromOffset(math.min(300, centerWidth), 116)
	tutorial.Size = UDim2.fromOffset(centerWidth, centerWidth >= 400 and 58 or 76)
end
uiScale:GetPropertyChangedSignal("Scale"):Connect(layoutCenter)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCenter)
layoutCenter()

local waiting, waitingFace = UI.Panel({
	Name = "Waiting",
	Size = UDim2.fromOffset(214, 40),
	LayoutOrder = 1,
	Parent = rightStack,
})
UI.IconImage("lupa", 17, C.Text, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Transparency = MUTED,
	Parent = waitingFace,
})
local waitingText = UI.Text({
	Text = "Procurando pedidos",
	Font = F.Text,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(40, 0),
	Size = UDim2.new(1, -48, 1, 0),
	Parent = waitingFace,
})

local function specialBadge(parent: Instance, position: UDim2)
	local badge = new("Frame", {
		Name = "Special",
		BackgroundColor3 = C.Amber,
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 2,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = badge })
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), Parent = badge })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = badge,
	})
	UI.IconImage("estrela", 13, C.AmberInk, { LayoutOrder = 1, ZIndex = 3, Parent = badge })
	UI.Text({
		Text = "ESPECIAL",
		Font = F.Title,
		TextSize = 14,
		Color = C.AmberInk,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = badge,
	})
	return badge
end

local offer, offerFace = UI.Panel({
	Name = "Offer",
	Size = UDim2.fromOffset(RIGHT_W, 184),
	LayoutOrder = 2,
	Visible = false,
	Parent = rightStack,
})
UI.Text({
	Text = "NOVO PEDIDO",
	Font = F.Title,
	TextSize = 15,
	Color = C.Accent,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 20),
	Parent = offerFace,
})
local offerSpecial = specialBadge(offerFace, UDim2.new(1, -14, 0, 11))
UI.IconImage("sacola", 15, C.Text, { Position = UDim2.fromOffset(16, 40), Transparency = 0.2, Parent = offerFace })
local offerRestaurant = UI.Text({
	Font = F.Number,
	TextSize = 17,
	Position = UDim2.fromOffset(38, 37),
	Size = UDim2.new(1, -52, 0, 22),
	Truncate = true,
	Parent = offerFace,
})
UI.IconImage("casa", 15, C.Text, { Position = UDim2.fromOffset(16, 64), Transparency = MUTED, Parent = offerFace })
local offerCustomer = UI.Text({
	Font = F.Text,
	TextSize = 15,
	Transparency = 0.25,
	Position = UDim2.fromOffset(38, 61),
	Size = UDim2.new(1, -52, 0, 22),
	Truncate = true,
	Parent = offerFace,
})
local offerPay = UI.Text({
	Font = F.Number,
	TextSize = 30,
	Color = C.Accent,
	Position = UDim2.fromOffset(15, 88),
	Size = UDim2.new(0, 120, 0, 36),
	Parent = offerFace,
})
local offerInfo = UI.Text({
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 90),
	Size = UDim2.new(1, -150, 0, 16),
	Truncate = true,
	Parent = offerFace,
})
local offerPayMax = UI.Text({
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 107),
	Size = UDim2.new(1, -150, 0, 16),
	Parent = offerFace,
})

-- botões da oferta
local function offerButton(name: string, label: string, key: string, x: number, width: number, primary: boolean)
	local holder, face = UI.Panel({
		Name = name,
		Size = UDim2.fromOffset(width, 40),
		Position = UDim2.fromOffset(x, 132),
		Color = primary and C.Accent or C.Raised,
		Transparency = 0,
		Shadow = false,
		Stroke = false,
		Radius = 9,
		Parent = offerFace,
	})
	holder.ZIndex = 2
	local row = hlist(face, { Size = UDim2.fromScale(1, 1), Align = Enum.HorizontalAlignment.Center, Padding = 8 })
	UI.Text({
		Text = label,
		Font = F.Title,
		TextSize = 15,
		Color = primary and C.AccentInk or C.Text,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = row,
	})
	UI.Keycap(key, {
		LayoutOrder = 2,
		Background = primary and C.AccentInk or C.Panel,
		Color = primary and C.Accent or C.Text,
		Parent = row,
	})
	return UI.Hit(holder, face)
end
local acceptButton = offerButton("Accept", "ACEITAR", "E", 14, 146, true)
local declineButton = offerButton("Decline", "RECUSAR", "Q", 168, RIGHT_W - 168 - 14, false)

local orderPanel, orderFace = UI.Panel({
	Name = "Order",
	Size = UDim2.fromOffset(RIGHT_W, 168),
	LayoutOrder = 3,
	Visible = false,
	Parent = rightStack,
})
local disc = new("Frame", {
	Name = "Disc",
	BackgroundColor3 = C.Accent,
	Size = UDim2.fromOffset(42, 42),
	Position = UDim2.fromOffset(14, 14),
	ZIndex = 2,
	Parent = orderFace,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disc })
local arrowIcon = UI.IconImage("seta", 24, C.AccentInk, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	ZIndex = 3,
	Parent = disc,
})
local distanceText = UI.Text({
	Name = "Distance",
	Font = F.Number,
	TextSize = 28,
	Position = UDim2.fromOffset(66, 14),
	Size = UDim2.new(1, -116, 0, 42),
	Parent = orderFace,
})

local cancelHolder, cancelFace = UI.Panel({
	Name = "Cancel",
	Size = UDim2.fromOffset(30, 30),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Color = C.Raised,
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 8,
	Parent = orderFace,
})
cancelHolder.ZIndex = 3
local cancelIcon = UI.IconImage("xis", 12, C.Text, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Transparency = 0.3,
	Parent = cancelFace,
})
local cancelText = UI.Text({
	Text = "CANCELAR?",
	Font = F.Title,
	TextSize = 14,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = cancelFace,
})
local cancelButton = UI.Hit(cancelHolder, cancelFace)

-- etapas: a feita fica riscada com um check verde, a atual em destaque, a próxima apagada
local function stepRow(y: number, iconName: string)
	local row = new("Frame", {
		Name = "Step",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, 22),
		ZIndex = 2,
		Parent = orderFace,
	})
	local icon = UI.IconImage(iconName, 15, C.Text, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = row,
	})
	local text = UI.Text({
		Font = F.Text,
		TextSize = 16,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Truncate = true,
		Parent = row,
	})
	local strike = new("Frame", {
		Name = "Strike",
		BackgroundColor3 = C.Text,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 1),
		Size = UDim2.new(0, 60, 0, 2),
		ZIndex = 3,
		Parent = row,
	})
	local function fit()
		strike.Size = UDim2.new(0, math.min(unscaled(text.TextBounds.X), 230) + 4, 0, 2)
	end
	text:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	return { Icon = icon, IconName = iconName, Text = text, Strike = strike, Fit = fit }
end
local stepPickup = stepRow(66, "sacola")
local stepDeliver = stepRow(90, "casa")

local function setStep(step, state: string, label: string)
	step.Text.Text = label
	step.Strike.Visible = state == "done"
	if state == "done" then
		step.Icon.Image = UI.Icon.check
		step.Icon.ImageColor3 = C.Accent
		step.Icon.ImageTransparency = 0
		step.Text.TextTransparency = 0.55
	elseif state == "current" then
		step.Icon.Image = UI.Icon[step.IconName]
		step.Icon.ImageColor3 = C.Accent
		step.Icon.ImageTransparency = 0
		step.Text.TextTransparency = 0
	else
		step.Icon.Image = UI.Icon[step.IconName]
		step.Icon.ImageColor3 = C.Text
		step.Icon.ImageTransparency = 0.55
		step.Text.TextTransparency = 0.5
	end
	step.Fit()
end

local timerIcon = UI.IconImage("relogio", 14, C.Text, { Position = UDim2.fromOffset(16, 126), Transparency = MUTED, Parent = orderFace })
local timerText = UI.Text({
	Font = F.Number,
	TextSize = 17,
	Position = UDim2.fromOffset(36, 123),
	Size = UDim2.fromOffset(110, 20),
	Parent = orderFace,
})
local multiplierText = UI.Text({
	Font = F.Number,
	TextSize = 17,
	Position = UDim2.fromOffset(16, 143),
	Size = UDim2.fromOffset(120, 18),
	Parent = orderFace,
})
local estimateText = UI.Text({
	Font = F.Number,
	TextSize = 36,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 120),
	Size = UDim2.fromOffset(150, 40),
	Parent = orderFace,
})

-- Sobrevivência: barra do relógio restante no pé do cartão
local deadlineBar = new("Frame", {
	Name = "DeadlineBar",
	BackgroundColor3 = C.Text,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -10),
	Size = UDim2.new(1, -32, 0, 4),
	Visible = false,
	ZIndex = 2,
	Parent = orderFace,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = deadlineBar })
local deadlineFill = new("Frame", {
	Name = "Fill",
	BackgroundColor3 = C.Text,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 3,
	Parent = deadlineBar,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = deadlineFill })

local speedPanel, speedFace = UI.Panel({
	Name = "Speed",
	Size = UDim2.fromOffset(150, 76),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -M, 1, -M),
	Parent = gui,
})
local speedText = UI.Text({
	Text = "0",
	Font = F.Number,
	TextSize = 40,
	XAlign = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(8, 4),
	Size = UDim2.fromOffset(82, 44),
	Parent = speedFace,
})
local unitText = UI.Text({
	Text = "km/h",
	Font = F.Text,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(96, 22),
	Size = UDim2.fromOffset(50, 20),
	Parent = speedFace,
})
local turboBar = new("CanvasGroup", {
	Name = "TurboBar",
	BackgroundColor3 = C.Text,
	BackgroundTransparency = 0.88,
	Position = UDim2.fromOffset(14, 56),
	Size = UDim2.new(1, -28, 0, 6),
	ZIndex = 2,
	Parent = speedFace,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = turboBar })
local turboFill = new("Frame", {
	Name = "Fill",
	BackgroundColor3 = C.Text,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(0, 1),
	Parent = turboBar,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = turboFill })
local turboLabel = UI.Text({
	Font = F.Title,
	TextSize = 15,
	Color = C.Accent,
	XAlign = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 0, -6),
	Size = UDim2.fromOffset(150, 18),
	Visible = false,
	Parent = speedPanel,
})

local BUTTON = TOUCH and 56 or 52
local menuRow = hlist(gui, {
	Name = "Menu",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, M, 1, -M),
	Size = UDim2.fromOffset(3 * BUTTON + 20, BUTTON),
	Padding = 10,
})
local function menuButton(order: number, icon: string, name: string, key: string)
	local holder, face = UI.Panel({
		Name = name,
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		LayoutOrder = order,
		Parent = menuRow,
	})
	UI.IconImage(icon, 24, C.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = face })
	UI.Keycap(key, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Width = 18,
		Height = 18,
		TextSize = 13,
		Background = C.Raised,
		ZIndex = 5,
		Parent = face,
	})
	return UI.Hit(holder, face), holder, face
end
local shopButton, shopHolder = menuButton(1, "chave", "Oficina", "L")
local areasButton, areasHolder = menuButton(2, "mapa", "Areas", "M")
local resetButton = menuButton(3, "reset", "Reset", "R")
local quitButton, quitHolder, quitFace = menuButton(4, "xis", "Sair", "X")
quitHolder.Visible = false
local quitText = UI.Text({
	Text = "SAIR?",
	Font = F.Title,
	TextSize = 15,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = quitFace,
})

local function layoutMenu()
	local width, count = 0, 0
	for _, holder in ipairs(menuRow:GetChildren()) do
		if holder:IsA("GuiObject") and holder.Visible then
			width += holder.Size.X.Offset
			count += 1
		end
	end
	menuRow.Size = UDim2.fromOffset(width + math.max(0, count - 1) * 10, BUTTON)
end

-- Sair da partida pede confirmação (1º clique arma, 2º confirma)
local quitArmed, quitToken = false, 0
local function setQuitArmed(armed: boolean)
	quitArmed = armed
	quitFace.Icon.Visible = not armed
	local key = quitFace:FindFirstChild("Key")
	if key then
		key.Visible = not armed and UI.InputKind() == "Keyboard"
	end
	quitText.Visible = armed
	quitFace.BackgroundColor3 = armed and C.Red or C.Panel
	quitHolder.Size = UDim2.fromOffset(armed and 96 or BUTTON, BUTTON)
	layoutMenu()
end
local function requestQuit()
	if not survival() then
		return
	end
	quitToken += 1
	local token = quitToken
	if not quitArmed then
		setQuitArmed(true)
		task.delay(3, function()
			if quitToken == token then
				setQuitArmed(false)
			end
		end)
		return
	end
	setQuitArmed(false)
	Remotes.RequestQuitSurvival:FireServer()
end
quitButton.Activated:Connect(requestQuit)

local maneuver, maneuverFace = UI.Panel({
	Name = "Maneuver",
	Size = UDim2.fromOffset(300, 52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.66),
	Transparency = 0,
	Stroke = false,
	Radius = 10,
	Visible = false,
	Parent = gui,
})
local maneuverTape, maneuverStripes = UI.Tape(maneuverFace, C.Panel, 10)
local maneuverPlate, maneuverPlateFace = UI.Panel({
	Name = "Plate",
	Size = UDim2.new(1, -28, 1, -12),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 7,
	Parent = maneuverFace,
})
maneuverPlate.ZIndex = 3
local maneuverText = UI.Text({
	Font = F.Title,
	TextSize = 24,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Parent = maneuverPlateFace,
})
maneuverText:GetPropertyChangedSignal("TextBounds"):Connect(function()
	maneuver.Size = UDim2.fromOffset(math.max(200, unscaled(maneuverText.TextBounds.X) + 70), 52)
end)

local MANEUVER_STYLE = {
	good = { Face = C.Accent, Tape = false, Plate = nil, Text = C.AccentInk },
	hazard = { Face = C.Amber, Tape = true, Stripe = C.AmberInk, Plate = C.Panel, Text = C.Amber },
	bad = { Face = C.Red, Tape = true, Stripe = C.Text, Plate = C.Panel, Text = C.Text },
}
local MANEUVER_KIND = {
	["GRAU!"] = "good",
	["SALTO! +TURBO"] = "good",
	["PNEU TROCADO!"] = "good",
	["TURBO!"] = "good",
	["ÓLEO NA PISTA!"] = "hazard",
	["BURACO!"] = "hazard",
	["LAMA!"] = "hazard",
	["LOMBADA!"] = "hazard",
	["ÁGUA NA PISTA!"] = "hazard",
	["CAIU DO GRAU!"] = "bad",
	["BATEU!"] = "bad",
	["PNEU FURADO!"] = "bad",
	["RADAR! MULTA"] = "bad",
	["BOLADA!"] = "bad",
	["ATROPELOU!"] = "bad",
	["LOMBADA! REDUZA"] = "hazard",
	["ESCUDO!"] = "good",
	["NITRO!"] = "good",
	["MODO FANTASMA!"] = "good",
	["SALTO EXTREMO!"] = "good",
	["CARRO TE ACERTOU!"] = "bad",
	["PNEU REFORÇADO!"] = "good",
	["SIRENE!"] = "good",
	["CÂMERA LENTA!"] = "good",
	["SAÍDA RÁPIDA!"] = "good",
	["MULTA NA BLITZ!"] = "bad",
	["BLITZ: LIBERADO"] = "good",
}
local function styleManeuver(kind: string)
	local style = MANEUVER_STYLE[kind] or MANEUVER_STYLE.hazard
	maneuverFace.BackgroundColor3 = style.Face
	maneuverTape.Visible = style.Tape
	if style.Tape then
		maneuverStripes.ImageColor3 = style.Stripe
	end
	maneuverPlateFace.BackgroundTransparency = style.Plate and 0 or 1
	if style.Plate then
		maneuverPlateFace.BackgroundColor3 = style.Plate
	end
	maneuverText.TextColor3 = style.Text
end

-- aviso grande no meio da tela vindo do servidor (o MotoController usa o mesmo atributo)
local flashCount = 0
local function flashManeuver(text: string)
	flashCount += 1
	player:SetAttribute("Maneuver", text .. "#s" .. flashCount)
end

local maneuverToken = 0
player:GetAttributeChangedSignal("Maneuver"):Connect(function()
	local raw = player:GetAttribute("Maneuver") or ""
	local text = string.match(raw, "^(.-)#") or raw
	if text == "" then
		return
	end
	maneuverToken += 1
	local token = maneuverToken
	styleManeuver(MANEUVER_KIND[text] or "hazard")
	maneuverText.Text = text
	UI.Show(maneuver, 1.2)
	task.delay(1.1, function()
		if maneuverToken == token then
			UI.Hide(maneuver)
		end
	end)
end)

local marker = nil
local markerRing, markerFill = nil, nil
local markerChevrons = nil
local function clearMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
	markerRing, markerFill, markerChevrons = nil, nil, nil
	player:SetAttribute("RouteTarget", nil) -- a trilha no chão (RouteGuide) some junto
end

local function groundImage(parent: Instance, image: string, color: Color3, transparency: number, y: number, diameter: number)
	local part = new("Part", {
		Name = "Ground",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(diameter, 0.05, diameter),
		CFrame = CFrame.new(0, y, 0),
		Parent = parent,
	})
	local surface = new("SurfaceGui", {
		Face = Enum.NormalId.Top,
		LightInfluence = 0,
		Brightness = 1.4,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 16,
		Parent = part,
	})
	local img = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = color,
		ImageTransparency = transparency,
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = surface,
	})
	return part, img
end

-- coleta = âmbar (restaurante); entrega = verde (cliente: é onde você recebe)
local function setMarker(position: Vector3, isPickup: boolean, radius: number)
	clearMarker()
	local color = isPickup and C.Amber or C.Accent
	local model = new("Model", { Name = "OrderMarker" })
	local diameter = radius * 2
	local fillPart, fill = groundImage(model, UI.Texture.miolo, color, 0.35, 0.42, diameter)
	local ringPart, ring = groundImage(model, UI.Texture.anel, color, 0, 0.46, diameter)
	fillPart:PivotTo(CFrame.new(position.X, 0.42, position.Z))
	ringPart:PivotTo(CFrame.new(position.X, 0.46, position.Z))
	markerRing, markerFill = ring, fill
	-- marca no chão como nos jogos LEGO: quatro setas em volta do anel apontando para o centro, "chamando" o jogador
	local chevronPart = groundImage(model, "", color, 1, 0.5, diameter * 1.75)
	chevronPart:PivotTo(CFrame.new(position.X, 0.5, position.Z))
	local surface = chevronPart:FindFirstChildOfClass("SurfaceGui")
	markerChevrons = {}
	for _, def in ipairs({ { 0.5, 0, 180 }, { 0.5, 1, 0 }, { 0, 0.5, 90 }, { 1, 0.5, -90 } }) do
		local arrow = new("ImageLabel", {
			Name = "Seta",
			BackgroundTransparency = 1,
			Image = UI.Icon.seta,
			ImageColor3 = color,
			Size = UDim2.fromScale(0.15, 0.15),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = def[3],
			Parent = surface,
		})
		table.insert(markerChevrons, { Image = arrow, X = def[1], Y = def[2] })
	end
	new("PointLight", { Color = color, Brightness = 1.2, Range = radius * 1.6, Parent = chevronPart })
	model.Parent = Workspace
	marker = model
	-- destino da trilha no chão (RouteGuide)
	player:SetAttribute("RouteColor", color)
	player:SetAttribute("RouteRadius", radius)
	player:SetAttribute("RouteTarget", Vector3.new(position.X, 0, position.Z))
end

local currentOffer = nil
local activeOrders = {}
local lastStatus = nil

local function getPrimaryOrder()
	local best = nil
	for _, order in pairs(activeOrders) do
		if not best or order.Id < best.Id then
			best = order
		end
	end
	return best
end

local function formatDistance(studs: number): string
	if studs >= 1000 then
		return (string.format("%.1f km", studs / 1000):gsub("%.", ","))
	end
	return string.format("%d m", math.floor(studs))
end

local function refreshOrderPanel()
	local order = getPrimaryOrder()
	UI.SetShown(orderPanel, order ~= nil, 0.8)
	UI.SetShown(waiting, order == nil and currentOffer == nil, 0.4)
	if not order then
		lastStatus = nil
		clearMarker()
		return
	end
	cancelHolder.Visible = not order.Survival -- na Sobrevivência não dá para cancelar (só sair da partida)
	local toRestaurant = order.Status == "ToRestaurant"
	setStep(stepPickup, toRestaurant and "current" or "done", order.RestaurantName)
	setStep(stepDeliver, toRestaurant and "next" or "current", order.CustomerName .. "  •  " .. order.CustomerPlace)
	if toRestaurant then
		disc.BackgroundColor3 = C.Amber
		arrowIcon.ImageColor3 = C.AmberInk
		setMarker(order.RestaurantPosition, true, order.PointRadius)
	else
		disc.BackgroundColor3 = C.Accent
		arrowIcon.ImageColor3 = C.AccentInk
		setMarker(order.CustomerPosition, false, order.PointRadius)
	end
	if lastStatus and lastStatus ~= order.Status then
		UI.Show(orderPanel, 0.5)
	end
	lastStatus = order.Status
end

local function showOffer(order)
	currentOffer = order
	if order then
		offerSpecial.Visible = order.IsSpecial == true
		offerRestaurant.Text = order.RestaurantName
		offerCustomer.Text = order.CustomerName
		offerPay.Text = Format.Money(order.BasePay)
		offerInfo.Text = string.format("%s  •  prazo %s", formatDistance(order.StraightDistance), Format.Time(order.IdealTime))
		offerPayMax.Text = "até " .. Format.Money(order.BasePay * BEST_MULTIPLIER) .. " voando"
		UI.Show(offer, offer.Visible and 0.4 or 1)
	else
		UI.SetShown(offer, false)
	end
	refreshOrderPanel()
end

local function acceptOffer()
	if currentOffer then
		Remotes.RequestAcceptOrder:FireServer(currentOffer.Id)
	end
end

local function declineOffer()
	if currentOffer then
		Remotes.RequestDeclineOrder:FireServer()
		showOffer(nil)
	end
end

acceptButton.Activated:Connect(acceptOffer)
declineButton.Activated:Connect(declineOffer)

local cancelArmed = false
local cancelToken = 0
local function setCancelArmed(armed: boolean)
	cancelArmed = armed
	cancelIcon.Visible = not armed
	cancelText.Visible = armed
	cancelFace.BackgroundColor3 = armed and C.Red or C.Raised
	cancelHolder.Size = armed and UDim2.fromOffset(96, 30) or UDim2.fromOffset(30, 30)
end
cancelButton.Activated:Connect(function()
	local order = getPrimaryOrder()
	if not order then
		return
	end
	if not cancelArmed then
		setCancelArmed(true)
		cancelToken += 1
		local token = cancelToken
		task.delay(3, function()
			if cancelToken == token then
				setCancelArmed(false)
			end
		end)
		return
	end
	cancelToken += 1
	setCancelArmed(false)
	Remotes.RequestCancelOrder:FireServer(order.Id)
end)

local toastToken = 0
local function showToast(result)
	toastToken += 1
	local token = toastToken
	toastTitle.Text = result.IsSpecial and "ENTREGA ESPECIAL" or "ENTREGUE"
	toastIcon.Image = result.IsSpecial and UI.Icon.estrela or UI.Icon.check
	toastAmount.Text = "+" .. Format.Money(result.Total)
	local tipPercent = math.floor((result.Tip - 1) * 100 + 0.5)
	local parts = {
		string.format("%s de %s", Format.Time(result.RealTime), Format.Time(result.IdealTime)),
		UI.Multiplier(result.SpeedMultiplier),
		string.format("gorjeta %s%d%%", tipPercent >= 0 and "+" or "", tipPercent),
	}
	if (result.ComboBonus or 0) > 0 then
		table.insert(parts, string.format("combo x%d", result.Combo))
	end
	toastDetails.Text = table.concat(parts, "  •  ")
	UI.Show(toast, 1.3)
	task.delay(3.4, function()
		if toastToken == token then
			UI.Hide(toast)
		end
	end)
end

local function showSurvivalToast(result)
	toastToken += 1
	local token = toastToken
	local n = result.Deliveries or 0
	toastTitle.Text = result.RecordBroken and "NOVO RECORDE" or "ENTREGUE"
	toastIcon.Image = result.RecordBroken and UI.Icon.estrela or UI.Icon.check
	toastAmount.Text = string.format("%d %s", n, n == 1 and "entrega" or "entregas")
	local gained = string.format("+%d s no relógio", result.TimeBonus or 0)
	if result.PerfectBonus then
		toastDetails.Text = gained .. string.format("  •  sequência perfeita +%d", result.PerfectBonus)
	else
		toastDetails.Text = gained .. string.format("  •  relógio em %s", Format.Time(math.ceil(result.Clock or 0)))
	end
	UI.Show(toast, 1.3)
	UI.Show(wallet, 0.6)
	task.delay(2.4, function()
		if toastToken == token then
			UI.Hide(toast)
		end
	end)
end

Remotes.OrderOffered.OnClientEvent:Connect(showOffer)

Remotes.OrderAccepted.OnClientEvent:Connect(function(order)
	activeOrders[order.Id] = order
	if currentOffer and currentOffer.Id == order.Id then
		currentOffer = nil
		UI.SetShown(offer, false)
	end
	refreshOrderPanel()
end)

Remotes.OrderPickedUp.OnClientEvent:Connect(function(order)
	activeOrders[order.Id] = order
	refreshOrderPanel()
	local ev = order.Event
	if order.Survival and type(ev) == "table" and ev.Kind == "blitz" then
		showNotice(string.format("Coletado! Blitz no caminho: máx. %d km/h", GameConfig.Survival.Events.BlitzLimitKmh), 4, "info", "sirene")
	else
		showNotice("Pedido coletado! Leve até " .. order.CustomerName, 2.5, "good", "check")
	end
end)

Remotes.OrderDelivered.OnClientEvent:Connect(function(result)
	activeOrders[result.OrderId] = nil
	refreshOrderPanel()
	if result.Survival then
		showSurvivalToast(result)
	else
		showToast(result)
	end
end)

Remotes.OrderCancelled.OnClientEvent:Connect(function(orderId, reason)
	activeOrders[orderId] = nil
	setCancelArmed(false)
	refreshOrderPanel()
	showNotice(tostring(reason), 3.5, "bad", "xis")
end)

Remotes.Notify.OnClientEvent:Connect(function(text)
	text = tostring(text)
	local isCharge = string.find(text, "-%$") ~= nil
	local icon = isCharge and "alerta" or (string.find(text, "Aguarde") and "relogio" or "alerta")
	showNotice(text, isCharge and 2.5 or 3, isCharge and "bad" or "info", icon)
end)

local waitingClock = 0
local flatShown = false
RunService.RenderStepped:Connect(function(dt)
	local speed = player:GetAttribute("DisplaySpeed") or 0
	speedText.Text = tostring(math.floor(speed * KMH + 0.5))

	local flat = player:GetAttribute("FlatTire") or 0
	if flat > 0 then
		maneuverToken += 1
		styleManeuver("bad")
		maneuverText.Text = (string.format("PNEU FURADO  %.1fs", flat):gsub("%.", ","))
		if not flatShown then
			flatShown = true
			UI.Show(maneuver, 1)
		end
	elseif flatShown then
		flatShown = false
		UI.Hide(maneuver)
	end

	local charge = player:GetAttribute("TurboCharge") or 0
	local boosting = player:GetAttribute("Boosting") == true
	turboFill.Size = UDim2.fromScale(boosting and 1 or math.clamp(charge, 0, 1), 1)
	if boosting then
		turboFill.BackgroundColor3 = C.Accent
		turboFill.BackgroundTransparency = 0
		turboLabel.Visible = true
		turboLabel.Text = "TURBO!"
	elseif charge >= MIN_BOOST then
		turboFill.BackgroundColor3 = C.Accent
		turboFill.BackgroundTransparency = 0.25 + 0.25 * math.sin(os.clock() * 9)
		turboLabel.Visible = true
		turboLabel.Text = ({ Touch = "SOLTE O GRAU", Gamepad = "SOLTE O X" })[UI.InputKind()] or "SOLTE O SHIFT"
	else
		turboFill.BackgroundColor3 = C.Text
		turboFill.BackgroundTransparency = 0.45
		turboLabel.Visible = false
	end

	if waiting.Visible then
		waitingClock += dt
		waitingText.Text = (survival() and "Próximo pedido" or "Procurando pedidos") .. string.rep(".", math.floor(waitingClock / 0.4) % 4)
	end

	if markerRing then
		markerRing.Rotation = (markerRing.Rotation + dt * 18) % 360
		markerFill.ImageTransparency = 0.35 + 0.15 * math.sin(os.clock() * 3)
	end
	if markerChevrons then
		-- setas "respirando" para dentro do anel
		local wave = 0.5 + 0.5 * math.sin(os.clock() * 4.5)
		local d = 0.08 + 0.07 * wave
		for _, ch in ipairs(markerChevrons) do
			ch.Image.Position = UDim2.fromScale(ch.X + (0.5 - ch.X) * 2 * d, ch.Y + (0.5 - ch.Y) * 2 * d)
			ch.Image.ImageTransparency = 0.1 + 0.25 * wave
		end
	end

	local order = getPrimaryOrder()
	if not order then
		return
	end
	if order.Survival then
		-- relógio da partida: branco, âmbar quando está acabando, vermelho piscando nos últimos 5 s
		local left = math.max(0, order.DeadlineServerTime - Workspace:GetServerTimeNow())
		local frac = math.clamp(left / math.max(order.TimeAllowed, 0.1), 0, 1)
		local critical = left <= 5
		local color = critical and C.Red or (frac <= 0.35 and C.Amber or C.Text)
		estimateText.Text = left < 10 and (string.format("%.1f", left):gsub("%.", ",")) or Format.Time(math.ceil(left))
		estimateText.TextColor3 = color
		estimateText.TextTransparency = critical and (0.3 + 0.3 * math.sin(os.clock() * 14)) or 0
		timerText.Text = string.format("+%d s na entrega", order.NextBonus or 0)
		timerText.TextColor3 = C.Text
		timerIcon.ImageColor3 = color
		multiplierText.Text = string.format("entrega nº %d", (player:GetAttribute("SurvivalDeliveries") or 0) + 1)
		multiplierText.TextColor3 = C.Text
		deadlineFill.Size = UDim2.fromScale(frac, 1)
		deadlineFill.BackgroundColor3 = color
	else
		local elapsed = Workspace:GetServerTimeNow() - (order.AcceptedServerTime or Workspace:GetServerTimeNow())
		timerText.Text = string.format("%s / %s", Format.Time(elapsed), Format.Time(order.IdealTime))
		local late = elapsed > order.IdealTime
		timerText.TextColor3 = late and C.Red or C.Text
		timerIcon.ImageColor3 = late and C.Red or C.Text
		local estimate, multiplier = PaymentCalculator.Estimate(order.BasePay, order.IdealTime, elapsed)
		local color = multiplier >= 1.5 and C.Accent or (multiplier >= 1 and C.Text or C.Red)
		estimateText.Text = Format.Money(estimate)
		estimateText.TextColor3 = color
		estimateText.TextTransparency = 0
		multiplierText.Text = UI.Multiplier(multiplier)
		multiplierText.TextColor3 = color
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local target = order.Status == "ToRestaurant" and order.RestaurantPosition or order.CustomerPosition
		local deltaPos = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		distanceText.Text = formatDistance(deltaPos.Magnitude)
		local look = Workspace.CurrentCamera.CFrame.LookVector
		local angle = math.atan2(deltaPos.X, deltaPos.Z) - math.atan2(look.X, look.Z)
		arrowIcon.Rotation = -math.deg(angle)
	end
end)

local function toggleWindow(guiName: string)
	local target = playerGui:FindFirstChild(guiName)
	local window = target and target:FindFirstChild("Window")
	if not window then
		return
	end
	local open = not window.Visible
	for _, name in ipairs({ "ShopGui", "AreasGui" }) do
		local g = playerGui:FindFirstChild(name)
		local w = g and g:FindFirstChild("Window")
		if w then
			w.Visible = false
		end
	end
	window.Visible = open
end

shopButton.Activated:Connect(function()
	if gameMode() == "Story" then
		toggleWindow("ShopGui")
	end
end)
areasButton.Activated:Connect(function()
	if gameMode() == "Story" then
		toggleWindow("AreasGui")
	end
end)
resetButton.Activated:Connect(function()
	Remotes.RequestResetMoto:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		acceptOffer()
	elseif input.KeyCode == Enum.KeyCode.Q then
		declineOffer()
	elseif input.KeyCode == Enum.KeyCode.L and gameMode() == "Story" then
		toggleWindow("ShopGui")
	elseif input.KeyCode == Enum.KeyCode.M and gameMode() == "Story" then
		toggleWindow("AreasGui")
	elseif input.KeyCode == Enum.KeyCode.X then
		requestQuit()
	end
end)

player:GetAttributeChangedSignal("CurrentAreaId"):Connect(function()
	local area = AreaConfig.Get(player:GetAttribute("CurrentAreaId") or 0)
	if area and gameMode() == "Story" then
		showNotice(string.format("%s  •  paga %s", area.Name, UI.Multiplier(area.PayMultiplier)), 2.5, "info", "pino")
	end
end)

local tutorialActive = false
local tutorialToken = 0
local function tutorialStep(text: string, duration: number)
	if not tutorialActive then
		return
	end
	tutorialToken += 1
	local token = tutorialToken
	tutorialText.Text = text
	UI.Show(tutorial, 0.5)
	task.delay(duration, function()
		if tutorialToken == token then
			UI.Hide(tutorial)
		end
	end)
end
local TUTORIAL_START = TOUCH and "Um pedido vai aparecer à direita. Toque em ACEITAR."
	or "Um pedido vai aparecer à direita. Aperte E para aceitar."
-- O tutorial liga ao entrar num modo pela 1ª vez (História: nenhuma entrega; Sobrevivência: sem recorde)
local function startTutorial()
	local m = gameMode()
	tutorialActive = (m == "Story" and (player:GetAttribute("TotalDeliveries") or 0) == 0)
		or (m == "Survival" and (player:GetAttribute("SurvivalBest") or 0) == 0)
	if tutorialActive and m == "Story" then
		tutorialStep(TUTORIAL_START, 8)
	end
end
-- dicas de controle conforme o dispositivo do momento (teclado, controle ou toque)
local function controlsHint(): string
	return ({ Touch = "Use os botões para acelerar e virar.", Gamepad = "RT acelera, LT freia e o analógico vira." })[UI.InputKind()]
		or "W acelera, A e D viram, S freia."
end
local function grauHint(): string
	return ({ Touch = "Segure GRAU e solte para o turbo.", Gamepad = "Segure X e solte para o turbo." })[UI.InputKind()]
		or "Segure SHIFT e solte para o turbo."
end
Remotes.OrderAccepted.OnClientEvent:Connect(function()
	tutorialStep((survival() and "Siga as setas no chão até o restaurante antes do relógio zerar. " or "Siga as setas no chão até o restaurante. ") .. controlsHint(), 7)
end)
Remotes.OrderPickedUp.OnClientEvent:Connect(function()
	tutorialStep(survival() and "Agora siga as setas VERDES até o cliente. Se o relógio zerar, a partida acaba!"
		or "Agora siga as setas VERDES até o cliente. Quanto mais rápido, mais você ganha.", 7)
end)
Remotes.OrderCancelled.OnClientEvent:Connect(function()
	tutorialStep(TUTORIAL_START, 6)
end)
Remotes.OrderDelivered.OnClientEvent:Connect(function()
	if not tutorialActive then
		return
	end
	if survival() then
		tutorialStep("Boa! Cada entrega soma segundos no relógio, mas cada vez menos, e a cidade enche. " .. grauHint(), 8)
		tutorialActive = false
		return
	end
	tutorialStep("Primeira entrega! " .. grauHint() .. (UI.InputKind() == "Keyboard" and " L abre a Oficina." or ""), 8)
	tutorialActive = false
end)

------------------------------------------------------------------ habilidades (Sobrevivência)
local AbilityConfig = require(Modules:WaitForChild("AbilityConfig"))
local CHIP = 48
local CHIPS_PER_ROW = 7
-- no PC fica acima do velocímetro (cresce para cima); no toque fica abaixo da carteira (cresce para baixo)
local abilityRow = new("Frame", {
	Name = "Abilities",
	BackgroundTransparency = 1,
	AnchorPoint = TOUCH and Vector2.zero or Vector2.new(1, 1),
	Position = TOUCH and UDim2.fromOffset(M, M + 50 + 12) or UDim2.new(1, -M, 1, -(M + 76 + 12)),
	Size = UDim2.fromOffset(CHIPS_PER_ROW * CHIP + (CHIPS_PER_ROW - 1) * 8, 2 * CHIP + 12),
	Parent = gui,
})
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(CHIP, CHIP),
	CellPadding = UDim2.fromOffset(8, 12),
	FillDirection = Enum.FillDirection.Horizontal,
	StartCorner = TOUCH and Enum.StartCorner.TopLeft or Enum.StartCorner.BottomRight,
	HorizontalAlignment = TOUCH and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right,
	VerticalAlignment = TOUCH and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = abilityRow,
})
abilityRow.Visible = false
local chips = {}

local function makeChip(order: number, ability)
	local holder, face = UI.Panel({ Name = ability.Id, Size = UDim2.fromOffset(CHIP, CHIP), LayoutOrder = order, Parent = abilityRow })
	local icon = UI.IconImage(ability.Icon, 24, C.Text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = face,
	})
	-- cobertura de recarga: desce conforme o tempo passa
	local cover = new("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 4,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = cover })
	local count = UI.Text({
		Font = F.Number,
		TextSize = 18,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Visible = false,
		Parent = face,
	})
	local badge = UI.Text({
		Font = F.Number,
		TextSize = 13,
		XAlign = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 6,
		Visible = false,
		Parent = face,
	})
	if ability.Key then
		UI.Keycap(ability.Key == "Espaço" and "ESP" or ability.Key, {
			Gamepad = ability.Pad,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -6),
			Height = 18,
			TextSize = 12,
			Background = C.Raised,
			ZIndex = 7,
			Parent = face,
		})
	end
	return { Id = ability.Id, Ability = ability, Holder = holder, Face = face, Icon = icon, Cover = cover, Count = count, Badge = badge }
end

local function rebuildChips()
	for _, chip in ipairs(chips) do
		chip.Holder:Destroy()
	end
	table.clear(chips)
	local owned = AbilityConfig.Parse(player:GetAttribute("Abilities"))
	for i, ability in ipairs(AbilityConfig.List) do
		if owned[ability.Id] then
			local chip = makeChip(i, ability)
			table.insert(chips, chip)
			UI.Show(chip.Holder, 1.4)
		end
	end
end
player:GetAttributeChangedSignal("Abilities"):Connect(rebuildChips)

-- estado de cada habilidade (atributos locais do MotoController e do servidor)
local READY_ATTR = { shield = "ShieldReadyAt", jump = "JumpReadyAt", ghost = "GhostReadyAt", siren = "SirenReadyAt", slowmo = "SlowReadyAt" }
local ACTIVE_ATTR = { ghost = "GhostUntil", siren = "SirenUntil", slowmo = "SlowUntil" }
local function chipState(chip, now: number)
	local id = chip.Ability.Id
	local active = ACTIVE_ATTR[id]
	if active and (player:GetAttribute(active) or 0) > now then
		return 0, 1, true
	end
	local ready = READY_ATTR[id]
	if ready then
		local left = (player:GetAttribute(ready) or 0) - now
		return left > 0 and left or 0, chip.Ability.Cooldown
	end
	if id == "second" and player:GetAttribute("SecondChanceUsed") then
		return 1, 1
	end
	return 0, 1
end

local function updateChips()
	abilityRow.Visible = survival() and #chips > 0
	if not abilityRow.Visible then
		return
	end
	local now = os.clock()
	for _, chip in ipairs(chips) do
		local left, total, active = chipState(chip, now)
		local used = chip.Ability.Id == "second" and left > 0
		chip.Cover.Size = UDim2.fromScale(1, used and 1 or math.clamp(left / total, 0, 1))
		chip.Count.Visible = left > 0 and not used
		chip.Count.Text = tostring(math.ceil(left))
		chip.Icon.ImageColor3 = active and C.Accent or C.Text
		chip.Icon.ImageTransparency = (left > 0) and 0.6 or 0
		chip.Face.BackgroundColor3 = active and C.Raised or C.Panel
		if chip.Ability.Id == "perfect" then
			chip.Badge.Visible = true
			chip.Badge.Text = string.format("%d/%d", player:GetAttribute("PerfectStreak") or 0, chip.Ability.Streak)
		end
	end
end
RunService.RenderStepped:Connect(updateChips)

Remotes.OrderAccepted.OnClientEvent:Connect(function(order)
	if not order.Survival then
		return
	end
	local ev = order.Event
	if type(ev) == "table" and ev.Kind == "jam" then
		task.delay(0, showNotice, "Engarrafamento no caminho: passe pelo corredor entre os carros", 4, "info", "alerta")
	end
end)
Remotes.SurvivalUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	local order = data.OrderId and activeOrders[data.OrderId]
	if order and data.DeadlineServerTime then
		order.DeadlineServerTime = data.DeadlineServerTime
		order.TimeAllowed = data.TimeAllowed or order.TimeAllowed
	end
	if data.Type == "SecondChance" then
		showNotice(string.format("Segunda Chance! +%d s", data.Bonus or 0), 3, "good", "relogio")
	elseif data.Type == "Blitz" then
		if data.Fined then
			flashManeuver("MULTA NA BLITZ!")
			showNotice(string.format("Blitz: %d km/h (máx. %d). -%d s no relógio", data.Kmh or 0, data.Limit or 0, data.Penalty or 0), 3.5, "bad", "sirene")
		else
			flashManeuver("BLITZ: LIBERADO")
		end
	elseif data.Type == "Mission" then
		local stars = data.Stars or 0
		task.delay(1, showNotice, string.format("Missão concluída: %s  •  +%d %s", tostring(data.Text), stars, stars == 1 and "estrela" or "estrelas"), 4, "good", "estrela")
	end
end)

-- Clima do servidor (WeatherManager): avisa quando a pista muda
Workspace:GetAttributeChangedSignal("Clima"):Connect(function()
	if gameMode() == "Menu" then
		return
	end
	if Workspace:GetAttribute("Clima") == "Chuva" then
		showNotice("Começou a chover: a moto freia e vira um pouco menos", 4, "info", "alerta")
	else
		showNotice("A chuva parou: pista seca de novo", 3, "info", "check")
	end
end)

-- Menu: HUD desligado. Sobrevivência: placar no lugar do dinheiro, sem Oficina/Áreas e com Sair.
local function applyMode()
	local m = gameMode()
	local surv = m == "Survival"
	gui.Enabled = m ~= "Menu"
	moneyText.Visible = not surv
	scoreFrame.Visible = surv
	shopHolder.Visible = not surv
	areasHolder.Visible = not surv
	quitHolder.Visible = surv
	setQuitArmed(false)
	refreshOffRoadFee()
	refreshScore()
	orderPanel.Size = UDim2.fromOffset(RIGHT_W, surv and 180 or 168)
	deadlineBar.Visible = surv
	if m == "Menu" then
		table.clear(activeOrders)
		currentOffer = nil
		tutorialActive = false
		for _, holder in ipairs({ offer, toast, notice, tutorial, maneuver }) do
			holder.Visible = false
		end
		for _, name in ipairs({ "ShopGui", "AreasGui" }) do
			local g = playerGui:FindFirstChild(name)
			local w = g and g:FindFirstChild("Window")
			if w then
				w.Visible = false
			end
		end
	else
		startTutorial()
	end
	refreshOrderPanel()
end
player:GetAttributeChangedSignal("GameMode"):Connect(applyMode)
applyMode()

task.spawn(function()
	for _ = 1, 30 do
		local ok, state = pcall(function()
			return Remotes.GetOrderState:InvokeServer()
		end)
		if ok and state then
			for _, order in ipairs(state.Active) do
				activeOrders[order.Id] = order
			end
			if state.Offer and not currentOffer then
				showOffer(state.Offer)
			else
				refreshOrderPanel()
			end
			break
		end
		task.wait(1)
	end
	if player:GetAttribute("DataLoaded") and player:GetAttribute("DataSaving") == false then
		showNotice("DataStore indisponível: o progresso desta sessão NÃO será salvo.", 6, "bad", "alerta")
	end
end)

refreshOrderPanel()
