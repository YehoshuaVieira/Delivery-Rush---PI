-- Menu inicial em estilo lobby (personagem + moto em destaque) e tela de resultado da Sobrevivência.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local gui = script.Parent

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local AreaConfig = require(Modules:WaitForChild("AreaConfig"))
local UI = require(Modules:WaitForChild("UIKit"))
local CosmeticConfig = require(Modules:WaitForChild("CosmeticConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local motoTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("MotoVitrine", 10)
local vitrines = ReplicatedStorage.Assets:WaitForChild("MotoVitrines", 10) -- uma moto ancorada por modelo da Garagem
if vitrines then
	-- malhas e texturas das motos baixadas logo no começo (senão a 1ª prévia na Garagem aparece branca por alguns segundos)
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(vitrines:GetDescendants())
		end)
	end)
end

local C, F, new = UI.Color, UI.Font, UI.new
local MUTED = UI.Muted
local TOUCH = UI.IsTouch()
local SURVIVAL = GameConfig.Survival
local SIDE_W = 380
local GARAGE_W = 440

for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("GuiObject") or child:IsA("UIScale") then
		child:Destroy()
	end
end
local uiScale = new("UIScale", { Parent = gui })

local function hlist(parent: Instance?, props: { [string]: any })
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

local function column(name: string)
	local frame = new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIDE_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 12),
		Parent = frame,
	})
	return frame
end

-- Botão sólido (verde = ação principal). Retorna (clique, texto, face, holder).
local function button(props: { [string]: any })
	local holder, face = UI.Panel({
		Name = props.Name,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Color = props.Primary and C.Accent or C.Raised,
		Transparency = 0,
		Shadow = props.Shadow == true,
		Stroke = false,
		Radius = props.Radius or 12,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	holder.ZIndex = 3
	local row = hlist(face, { Size = UDim2.fromScale(1, 1), Align = Enum.HorizontalAlignment.Center, Padding = 12 })
	local label = UI.Text({
		Text = props.Text,
		Font = F.Title,
		TextSize = props.TextSize or 20,
		Color = props.Primary and C.AccentInk or C.Text,
		Size = UDim2.fromOffset(0, props.TextSize and props.TextSize + 8 or 28),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = row,
	})
	if props.Key then
		UI.Keycap(props.Key, {
			Gamepad = props.Pad,
			LayoutOrder = 2,
			Height = 24,
			TextSize = 15,
			Background = props.Primary and C.AccentInk or C.Panel,
			Color = props.Primary and C.Accent or C.Text,
			Parent = row,
		})
	end
	return UI.Hit(holder, face), label, face, holder
end

------------------------------------------------------------------ fundo (legibilidade sobre a cena 3D)
local function shade(name: string, anchorY: number, height: number, fromT: number, toT: number)
	local frame = new("Frame", {
		Name = name,
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, anchorY),
		Position = UDim2.fromScale(0, anchorY),
		Size = UDim2.fromScale(1, height),
		ZIndex = 0,
		Parent = gui,
	})
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(fromT, toT), Parent = frame })
	return frame
end
shade("TopShade", 0, 0.22, 0.3, 1)
local bottomShade = shade("BottomShade", 1, 0.55, 1, 0.1)
local dim = new("Frame", {
	Name = "Dim",
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 0,
	Parent = gui,
})

------------------------------------------------------------------ topo: marca e perfil
local brand = hlist(gui, { Name = "Brand", Size = UDim2.fromOffset(420, 54), Padding = 12 })
local badge = new("Frame", {
	Name = "Badge",
	BackgroundColor3 = C.Accent,
	Size = UDim2.fromOffset(50, 50),
	LayoutOrder = 1,
	ZIndex = 2,
	Parent = brand,
})
new("UICorner", { CornerRadius = UDim.new(0, 13), Parent = badge })
UI.IconImage("caixa", 30, C.AccentInk, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	ZIndex = 3,
	Parent = badge,
})
local brandText = new("Frame", {
	Name = "Wordmark",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(340, 54),
	LayoutOrder = 2,
	Parent = brand,
})
UI.Text({
	Text = "DELIVERY RUSH",
	Font = F.Display,
	TextSize = 32,
	Size = UDim2.new(1, 0, 0, 34),
	Parent = brandText,
})
UI.Text({
	Text = "ENTREGAS CONTRA O RELÓGIO",
	Font = F.Title,
	TextSize = 14,
	Color = C.Accent,
	Position = UDim2.fromOffset(2, 34),
	Size = UDim2.new(1, 0, 0, 18),
	Parent = brandText,
})

local chip, chipFace = UI.Panel({
	Name = "Profile",
	Size = UDim2.fromOffset(260, 62),
	AnchorPoint = Vector2.new(1, 0),
	Parent = gui,
})
local avatar = new("ImageLabel", {
	Name = "Avatar",
	BackgroundColor3 = C.Raised,
	Size = UDim2.fromOffset(42, 42),
	Position = UDim2.fromOffset(10, 10),
	ZIndex = 2,
	Parent = chipFace,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatar })
UI.Text({
	Text = player.DisplayName,
	Font = F.Text,
	TextSize = 18,
	Position = UDim2.fromOffset(64, 9),
	Size = UDim2.new(1, -136, 0, 24),
	Truncate = true,
	Parent = chipFace,
})
local chipRecord = UI.Text({
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(64, 32),
	Size = UDim2.new(1, -136, 0, 20),
	Truncate = true,
	Parent = chipFace,
})
task.spawn(function()
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		avatar.Image = image
	end
end)

------------------------------------------------------------------ esquerda: modo de jogo
local leftCol = column("Modes")
local modeLabel = UI.Text({
	Text = "MODO DE JOGO",
	Font = F.Title,
	TextSize = 15,
	Transparency = MUTED,
	Size = UDim2.new(1, 0, 0, 20),
	LayoutOrder = 1,
	Parent = leftCol,
})

local function modeTile(props: { [string]: any })
	local holder, face = UI.Panel({
		Name = props.Name,
		Size = UDim2.new(1, 0, 0, props.Height),
		Transparency = props.Locked and 0.2 or 0.04,
		LayoutOrder = props.Order,
		Parent = leftCol,
	})
	local disc = new("Frame", {
		Name = "Disc",
		BackgroundColor3 = props.Locked and C.Raised or C.Accent,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(props.Disc, props.Disc),
		ZIndex = 2,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = disc })
	UI.IconImage(props.Icon, math.floor(props.Disc * 0.5), props.Locked and C.Text or C.AccentInk, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Transparency = props.Locked and 0.4 or 0,
		ZIndex = 3,
		Parent = disc,
	})
	local x = 16 + props.Disc + 14
	UI.Text({
		Text = props.Title,
		Font = F.Title,
		TextSize = props.TitleSize,
		Transparency = props.Locked and 0.35 or 0,
		YAlign = Enum.TextYAlignment.Bottom,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, x, 0.5, 1),
		Size = UDim2.new(1, -x - 120, 0, props.TitleSize + 6),
		Parent = face,
	})
	UI.Text({
		Text = props.Sub,
		Font = F.Body,
		TextSize = props.SubSize,
		Transparency = props.Locked and 0.55 or 0.3,
		YAlign = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, x, 0.5, 4),
		Size = UDim2.new(1, -x - 16, 0, props.SubSize + 6),
		Truncate = true,
		Parent = face,
	})
	return holder, face
end

local survivalTile, survivalFace = modeTile({
	Name = "Survival",
	Order = 2,
	Height = 96,
	Disc = 56,
	Icon = "relogio",
	Title = "SOBREVIVÊNCIA",
	TitleSize = 23,
	Sub = "Entregas sem parar contra o relógio",
	SubSize = 16,
})
local edge = survivalFace:FindFirstChild("Edge")
if edge then
	-- selecionado: contorno verde
	edge.Color = C.Accent
	edge.Transparency = 0
	edge.Thickness = 2
end
UI.IconImage("check", 22, C.Accent, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	ZIndex = 3,
	Parent = survivalFace,
})

local storyTile, storyFace = modeTile({
	Name = "Story",
	Order = 3,
	Height = 74,
	Disc = 44,
	Icon = "cadeado",
	Title = "HISTÓRIA",
	TitleSize = 20,
	Sub = "Dinheiro, oficina e novos bairros",
	SubSize = 15,
	Locked = true,
})
local soonTag, soonFace = UI.Panel({
	Name = "Soon",
	Size = UDim2.fromOffset(104, 28),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Color = C.Raised,
	Transparency = 0,
	Shadow = false,
	Stroke = false,
	Radius = 8,
	Parent = storyFace,
})
soonTag.ZIndex = 3
UI.Text({
	Text = "EM BREVE",
	Font = F.Title,
	TextSize = 14,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	Parent = soonFace,
})
UI.Hit(storyTile, storyFace).Activated:Connect(function()
	UI.Show(soonTag, 1.6) -- ainda em desenvolvimento: só chama a atenção para o "EM BREVE"
end)

------------------------------------------------------------------ missões do dia (dão estrelas para a Garagem)
local navMissionsBadge = nil -- contador "1/3" no botão MISSÕES (criado na navegação)
local shortScreen = false -- tela baixa (celular deitado): linhas das missões mais finas e sem o modo História
local garagePanel = nil -- criado depois do palco 3D (ver "garagem")
local layoutGarage = nil
local missionsCard, missionsFace = UI.Panel({
	Name = "Missions",
	Size = UDim2.new(1, 0, 0, 252),
	LayoutOrder = 0,
	Parent = leftCol,
})
UI.Text({
	Text = "MISSÕES DO DIA",
	Font = F.Title,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -150, 0, 20),
	Parent = missionsFace,
})

-- estrela + número, alinhados à direita
local function starCount(parent: Instance, position: UDim2, size: number)
	local row = hlist(parent, {
		Name = "Stars",
		AnchorPoint = Vector2.new(1, 0),
		Position = position,
		Size = UDim2.fromOffset(120, size + 6),
		Align = Enum.HorizontalAlignment.Right,
		Padding = 6,
	})
	UI.IconImage("estrela", size, C.Accent, { LayoutOrder = 1, Parent = row })
	return UI.Text({
		Font = F.Number,
		TextSize = size + 2,
		Size = UDim2.fromOffset(0, size + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = row,
	})
end
local cardStars = starCount(missionsFace, UDim2.new(1, -18, 0, 11), 18)
local chipStars = starCount(chipFace, UDim2.new(1, -14, 0, 18), 18) -- saldo sempre à vista no perfil
-- lobby limpo: o modo vai junto do JOGAR e a História (em breve) sai do menu
modeLabel.Visible = false
survivalTile.Visible = false
storyTile.Visible = false
missionsCard.Visible = false

local missionRows = {}
for i = 1, 3 do
	local row = new("Frame", { Name = "Mission" .. i, BackgroundTransparency = 1, ZIndex = 2, Parent = missionsFace })
	local text = UI.Text({ Font = F.Body, TextSize = 16, Size = UDim2.new(1, -100, 0, 22), Truncate = true, Parent = row })
	local count = UI.Text({
		Font = F.Number,
		TextSize = 16,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 0),
		Size = UDim2.fromOffset(56, 22),
		Parent = row,
	})
	local reward = hlist(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 22),
		Align = Enum.HorizontalAlignment.Right,
		Padding = 2,
	})
	local rewardText = UI.Text({
		Font = F.Number,
		TextSize = 15,
		Color = C.Accent,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = reward,
	})
	UI.IconImage("estrela", 14, C.Accent, { LayoutOrder = 2, Parent = reward })
	local track = new("Frame", {
		Name = "Track",
		BackgroundColor3 = C.Raised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, 5),
		ZIndex = 2,
		Parent = row,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = C.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = track })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	missionRows[i] = { Row = row, Text = text, Count = count, Reward = rewardText, Track = track, Fill = fill }
end

local resetText = UI.Text({
	Font = F.Body,
	TextSize = 14,
	Transparency = MUTED,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -14),
	Size = UDim2.new(1, -200, 0, 20),
	Truncate = true,
	Parent = missionsFace,
})
local garageButton, _, _, garageButtonHolder = button({
	Name = "GarageButton",
	Text = "GARAGEM",
	TextSize = 17,
	Key = "G",
	Pad = "Y",
	Size = UDim2.fromOffset(164, 40),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -14),
	Parent = missionsFace,
})
garageButtonHolder.Visible = false -- a Garagem agora fica na navegação
resetText.Size = UDim2.new(1, -36, 0, 20)

local function resetIn(): string
	local reset = player:GetAttribute("MissionsReset")
	if type(reset) ~= "number" then
		return ""
	end
	local left = math.max(0, reset - Workspace:GetServerTimeNow())
	if left >= 3600 then
		return string.format("novas em %d h", math.floor(left / 3600))
	end
	return string.format("novas em %d min", math.max(1, math.ceil(left / 60)))
end

local function layoutMissions()
	local rowH = shortScreen and 36 or 50
	for i, r in ipairs(missionRows) do
		r.Row.Position = UDim2.fromOffset(18, 44 + (i - 1) * rowH)
		r.Row.Size = UDim2.new(1, -36, 0, rowH - 6)
		r.Text.TextSize = shortScreen and 15 or 16
		r.Track.Position = UDim2.new(0, 0, 1, shortScreen and -1 or -6)
	end
	missionsCard.Size = UDim2.new(1, 0, 0, 44 + #missionRows * rowH + 38)
end

local function refreshMissions()
	local ok, list = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Missions") or "[]")
	end)
	local missions = ok and type(list) == "table" and list or {}
	local done = 0
	for i, r in ipairs(missionRows) do
		local m = missions[i]
		r.Row.Visible = m ~= nil
		if m then
			done += m.Done and 1 or 0
			r.Text.Text = tostring(m.Text)
			r.Text.TextTransparency = m.Done and 0.45 or 0
			r.Count.Text = m.Done and "FEITA" or string.format("%d/%d", m.Progress or 0, m.Goal or 1)
			r.Count.TextColor3 = m.Done and C.Accent or C.Text
			r.Reward.Text = "+" .. tostring(m.Stars or 0)
			r.Fill.Size = UDim2.fromScale(math.clamp((m.Progress or 0) / math.max(1, m.Goal or 1), 0, 1), 1)
		end
	end
	cardStars.Text = tostring(player:GetAttribute("Stars") or 0)
	chipStars.Text = cardStars.Text
	resetText.Text = #missions > 0 and string.format("%d/%d feitas  •  %s", done, #missions, resetIn()) or ""
	if navMissionsBadge then
		navMissionsBadge.Text = #missions > 0 and string.format("%d/%d", done, #missions) or ""
	end
end
player:GetAttributeChangedSignal("Missions"):Connect(refreshMissions)
player:GetAttributeChangedSignal("Stars"):Connect(refreshMissions)
refreshMissions()

------------------------------------------------------------------ direita: modo + JOGAR (as regras viram o painel "Como jogar")
local rightCol = column("Play")
rightCol.AnchorPoint = Vector2.new(1, 1)

local level = UpgradeConfig.Get(SURVIVAL.MotoLevel)
local area = AreaConfig.Get(SURVIVAL.AreaId)
local RULES = {
	{ "relogio", string.format("Você começa com %d s no relógio", SURVIVAL.StartTime) },
	{ "alerta", string.format("Cada entrega soma de %d a %d s", SURVIVAL.BonusStart, SURVIVAL.BonusMin) },
	{ "pino", "A cidade enche: carros, gente e buracos" },
	{ "raio", string.format("Moto de %d km/h  •  bairro %s", level.Speed * GameConfig.Moto.SpeedDisplayFactor, area and area.Name or "Centro") },
}
-- a regra dos controles segue o dispositivo do momento
local function controlsRule(): string
	return ({ Touch = "Botões na tela pilotam  •  GRAU dá turbo", Gamepad = "Analógico pilota  •  X empina e dá turbo" })[UI.InputKind()]
		or "WASD pilota  •  SHIFT empina e dá turbo"
end
table.insert(RULES, { "seta", controlsRule(), Controls = true })
local Creditos = require(Modules:WaitForChild("Creditos"))
local CREDITS_Y = 48 + #RULES * 30 + 10
local INFO_H = CREDITS_Y + 30 + #Creditos * 20 + 14
local info, infoFace = UI.Panel({
	Name = "Info",
	Size = UDim2.new(1, 0, 0, INFO_H),
	LayoutOrder = 1,
	Visible = false,
	Parent = leftCol,
})
-- em tela baixa (celular deitado) o painel não cabe inteiro: o conteúdo rola
local infoBody = new("ScrollingFrame", {
	Name = "Body",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.fromOffset(0, INFO_H),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Text,
	ScrollBarImageTransparency = 0.6,
	Parent = infoFace,
})
UI.Text({
	Text = "COMO JOGAR",
	Font = F.Title,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -36, 0, 20),
	Parent = infoBody,
})
for i, rule in ipairs(RULES) do
	local y = 42 + (i - 1) * 30
	UI.IconImage(rule[1], 18, C.Accent, { Position = UDim2.fromOffset(18, y + 4), Parent = infoBody })
	local ruleText = UI.Text({
		Text = rule[2],
		Font = F.Body,
		TextSize = 16,
		Transparency = 0.12,
		Position = UDim2.fromOffset(46, y),
		Size = UDim2.new(1, -60, 0, 26),
		Truncate = true,
		Parent = infoBody,
	})
	if rule.Controls then
		pcall(function()
			UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
				ruleText.Text = controlsRule()
			end)
		end)
	end
end

-- créditos dos modelos 3D (licença CC BY): discretos, no pé do "Como jogar"
UI.Text({
	Text = "CRÉDITOS DOS MODELOS 3D (CC BY 4.0)",
	Font = F.Title,
	TextSize = 14,
	Transparency = MUTED,
	Position = UDim2.fromOffset(18, CREDITS_Y),
	Size = UDim2.new(1, -36, 0, 20),
	Parent = infoBody,
})
for i, c in ipairs(Creditos) do
	UI.Text({
		Text = string.format("%s: modelo de %s", c.Moto, c.Autor),
		Font = F.Body,
		TextSize = 14,
		Transparency = 0.35,
		Position = UDim2.fromOffset(18, CREDITS_Y + 6 + i * 20),
		Size = UDim2.new(1, -36, 0, 18),
		Truncate = true,
		Parent = infoBody,
	})
end

-- modo da partida logo acima do JOGAR
local modeCaption = new("Frame", { Name = "Modo", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, Parent = rightCol })
UI.Text({
	Text = "SOBREVIVÊNCIA",
	Font = F.Title,
	TextSize = 22,
	XAlign = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, -4, 0, 26),
	Parent = modeCaption,
})
UI.Text({
	Text = string.format("Bairro %s  •  entregas contra o relógio", area and area.Name or "Centro"),
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	XAlign = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, -4, 0, 20),
	Parent = modeCaption,
})

local playButton, playLabel, playFace, playHolder = button({
	Name = "PlayButton",
	Text = "JOGAR",
	TextSize = 32,
	Key = "Enter",
	Pad = "A",
	Primary = true,
	Shadow = true,
	Radius = 14,
	Size = UDim2.new(1, 0, 0, 76),
	LayoutOrder = 2,
	Parent = rightCol,
})
local playGlow = new("UIStroke", {
	Color = C.Accent,
	Thickness = 3,
	Transparency = 0.5,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Parent = playFace,
})

------------------------------------------------------------------ navegação: 3 botões de texto, um painel aberto por vez
local openPanel = nil -- "missoes", "ajuda" ou nil
local onPanelChanged = nil -- refaz o layout (definido no layout responsivo)
local showGarage = nil -- definido junto das telas (showView)
local navButtons = {}
local nav = new("Frame", { Name = "Nav", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 3 * 48 + 2 * 6), LayoutOrder = 10, Parent = leftCol })
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = nav })

local function refreshNav()
	for id, b in pairs(navButtons) do
		local on = openPanel == id
		b.Bar.Visible = on
		b.Button.BackgroundTransparency = on and 0.08 or (b.Hover and 0.2 or 0.4)
		b.Label.TextTransparency = (on or b.Hover) and 0 or 0.15
	end
end

local function setPanel(id: string?)
	openPanel = (openPanel ~= id) and id or nil
	missionsCard.Visible = openPanel == "missoes"
	info.Visible = openPanel == "ajuda"
	for _, p in ipairs({ missionsCard, info }) do
		if p.Visible then
			UI.Show(p, 0.5)
		end
	end
	refreshNav()
	if onPanelChanged then
		onPanelChanged()
	end
end

local function navButton(id: string, text: string, order: number, onClick)
	local b = new("TextButton", {
		Name = id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.4,
		Size = UDim2.new(0, 270, 0, 48),
		LayoutOrder = order,
		Parent = nav,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
	local bar = new("Frame", {
		Name = "Bar",
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(0, 4, 1, -20),
		Visible = false,
		ZIndex = 2,
		Parent = b,
	})
	local label = UI.Text({ Text = text, Font = F.Title, TextSize = 20, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -90, 1, 0), Parent = b })
	local badge = UI.Text({
		Font = F.Number,
		TextSize = 18,
		Color = C.Accent,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 70, 1, 0),
		Parent = b,
	})
	local entry = { Button = b, Bar = bar, Label = label, Badge = badge, Hover = false }
	navButtons[id] = entry
	b.MouseEnter:Connect(function()
		entry.Hover = true
		refreshNav()
	end)
	b.MouseLeave:Connect(function()
		entry.Hover = false
		refreshNav()
	end)
	b.Activated:Connect(onClick)
	return entry
end

navMissionsBadge = navButton("missoes", "MISSÕES", 1, function()
	setPanel("missoes")
end).Badge
navButton("garagem", "GARAGEM", 2, function()
	if showGarage then
		showGarage()
	end
end).Badge.Text = TOUCH and "" or "G"
navButton("ajuda", "COMO JOGAR", 3, function()
	setPanel("ajuda")
end)
navButtons.garagem.Badge.TextColor3 = C.Text
navButtons.garagem.Badge.TextTransparency = 0.5
refreshNav()
refreshMissions()

------------------------------------------------------------------ resultado da partida
local resultPanel, resultFace = UI.Panel({
	Name = "Result",
	Size = UDim2.fromOffset(480, 404),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Visible = false,
	Parent = gui,
})
local function centered(props: { [string]: any })
	props.XAlign = Enum.TextXAlignment.Center
	props.Position = UDim2.fromOffset(24, props.Y)
	props.Size = UDim2.new(1, -48, 0, props.H)
	props.Parent = resultFace
	return UI.Text(props)
end
centered({ Text = "FIM DE PARTIDA", Font = F.Title, TextSize = 15, Transparency = MUTED, Y = 24, H = 20 })
local resultTitle = centered({ Font = F.Title, TextSize = 38, Y = 46, H = 44 })
local resultReason = centered({ Font = F.Body, TextSize = 17, Transparency = MUTED, Y = 92, H = 24 })

local stats = new("Frame", {
	Name = "Stats",
	BackgroundColor3 = C.Raised,
	BackgroundTransparency = 0.35,
	Position = UDim2.fromOffset(24, 134),
	Size = UDim2.new(1, -48, 0, 120),
	ZIndex = 2,
	Parent = resultFace,
})
new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = stats })
new("Frame", {
	Name = "Divider",
	BackgroundColor3 = C.Text,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 1, 1, -32),
	ZIndex = 3,
	Parent = stats,
})
local function statCell(x: number, label: string)
	UI.Text({
		Text = label,
		Font = F.Title,
		TextSize = 15,
		Transparency = MUTED,
		XAlign = Enum.TextXAlignment.Center,
		Position = UDim2.new(x, 0, 0, 14),
		Size = UDim2.new(0.5, 0, 0, 20),
		ZIndex = 3,
		Parent = stats,
	})
	return UI.Text({
		Font = F.Number,
		TextSize = 68,
		XAlign = Enum.TextXAlignment.Center,
		Position = UDim2.new(x, 0, 0, 36),
		Size = UDim2.new(0.5, 0, 0, 72),
		ZIndex = 3,
		Parent = stats,
	})
end
local resultDeliveries = statCell(0, "ENTREGAS")
local resultBest = statCell(0.5, "RECORDE")

local recordBadge = new("Frame", {
	Name = "NewRecord",
	BackgroundColor3 = C.Accent,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 268),
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 2,
	Parent = resultFace,
})
new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = recordBadge })
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), Parent = recordBadge })
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
	Parent = recordBadge,
})
UI.IconImage("estrela", 17, C.AccentInk, { LayoutOrder = 1, ZIndex = 3, Parent = recordBadge })
UI.Text({
	Text = "NOVO RECORDE",
	Font = F.Title,
	TextSize = 16,
	Color = C.AccentInk,
	Size = UDim2.fromOffset(0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	ZIndex = 3,
	Parent = recordBadge,
})
local resultHint = centered({ Font = F.Body, TextSize = 16, Transparency = MUTED, Y = 272, H = 24 })

local againButton, againLabel = button({
	Name = "Again",
	Text = "JOGAR DE NOVO",
	TextSize = 22,
	Key = "Enter",
	Pad = "A",
	Primary = true,
	Size = UDim2.new(1, -48 - 150 - 12, 0, 64),
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -24),
	Parent = resultFace,
})
local backButton = button({
	Name = "Back",
	Text = "MENU",
	TextSize = 20,
	Key = "M",
	Pad = "B",
	Size = UDim2.fromOffset(150, 64),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -24),
	Parent = resultFace,
})

local REASONS = {
	tempo = { Title = "TEMPO ESGOTADO", Text = "O relógio zerou antes da entrega.", Color = C.Red },
	desistiu = { Title = "PARTIDA ENCERRADA", Text = "Você saiu da partida.", Color = C.Text },
	invalida = { Title = "ENTREGA INVALIDADA", Text = "O servidor detectou um movimento impossível.", Color = C.Red },
}

------------------------------------------------------------------ layout responsivo
local compact = false
local view = "main"
local function layout()
	local vp = Workspace.CurrentCamera.ViewportSize
	uiScale.Scale = UI.ScaleFor(vp, TOUCH)
	local w = vp.X / uiScale.Scale
	local h = vp.Y / uiScale.Scale
	compact = w < 940
	shortScreen = h < 600
	local m = compact and 20 or 32
	-- abaixo da barra do Roblox (botão do menu, chat, microfone)
	local top = math.max(m - 6, GuiService.TopbarInset.Max.Y / uiScale.Scale + 10)
	brand.Position = UDim2.fromOffset(m, top)
	-- tela baixa: com um painel aberto a marca sai do caminho
	brand.Visible = not ((compact and (shortScreen or view == "garage")) or (shortScreen and openPanel ~= nil))
	layoutMissions()
	local navH = shortScreen and 40 or 48
	nav.Size = UDim2.new(1, 0, 0, 3 * navH + 2 * 6)
	local panelRoom = h - top - m - (3 * navH + 2 * 6) - 12 - (compact and 76 + 12 or 0)
	info.Size = UDim2.new(1, 0, 0, math.clamp(INFO_H, 120, math.max(120, panelRoom)))
	if layoutGarage then
		layoutGarage(w, h, m, top)
	end
	chip.Position = UDim2.new(1, -m, 0, top)
	chip.Size = UDim2.fromOffset(compact and 220 or 260, 62)
	rightCol.Visible = view == "main" and not compact
	for _, b in pairs(navButtons) do
		b.Button.Size = compact and UDim2.new(1, 0, 0, navH) or UDim2.new(0, 270, 0, navH)
	end
	if compact then
		-- tela estreita: uma coluna só, centralizada embaixo
		leftCol.Size = UDim2.fromOffset(math.min(460, w - 2 * m), 0)
		leftCol.AnchorPoint = Vector2.new(0.5, 1)
		leftCol.Position = UDim2.new(0.5, 0, 1, -m)
		playHolder.Parent = leftCol
		playHolder.LayoutOrder = 20
	else
		leftCol.Size = UDim2.fromOffset(SIDE_W, 0)
		leftCol.AnchorPoint = Vector2.new(0, 1)
		leftCol.Position = UDim2.new(0, m, 1, -m)
		rightCol.Position = UDim2.new(1, -m, 1, -m)
		playHolder.Parent = rightCol
		playHolder.LayoutOrder = 2
	end
	resultPanel.Size = UDim2.fromOffset(math.min(480, w - 2 * m), 404)
end
onPanelChanged = layout
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
layout()

------------------------------------------------------------------ palco 3D: personagem + moto, câmera de vitrine
local FACING = Vector3.new(1, 0, 1).Unit -- de costas para a praça do spawn
local stage = nil
local applyStage = nil -- visual da Garagem na moto do palco (ver "garagem")
local placedCharacter = nil
local stageClock = 0
local hideClock = 0

local dof = new("DepthOfFieldEffect", {
	Name = "MenuFocus",
	FarIntensity = 0.45,
	FocusDistance = 16,
	InFocusRadius = 8,
	NearIntensity = 0,
})
local blur = new("BlurEffect", { Name = "MenuBlur", Size = 0 })

local function stageOrigin(): Vector3
	local spawnPart = Workspace:FindFirstChildWhichIsA("SpawnLocation")
	return spawnPart and spawnPart.Position or Vector3.zero
end

local function groundY(pos: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(pos + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local function ignoreList(): { Instance }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "Motos", "LocalWorldFX" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	return list
end

local function clearStage()
	if stage then
		stage.Model:Destroy()
		stage = nil
	end
	placedCharacter = nil
end

local function buildStage()
	clearStage()
	local origin = stageOrigin()
	local ignore = ignoreList()
	local floor = groundY(origin, ignore)
	local base = CFrame.lookAt(Vector3.new(origin.X, floor, origin.Z), Vector3.new(origin.X, floor, origin.Z) + FACING)
	local model = new("Model", { Name = "MenuStage" })
	-- luz de estúdio na frente (funciona também à noite) e um contorno verde atrás
	local key = new("Part", {
		Name = "KeyLight",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt((base * CFrame.new(-1.5, 9, -14)).Position, (base * CFrame.new(-2, 2.5, 0)).Position),
		Parent = model,
	})
	new("SpotLight", { Brightness = 2.2, Range = 40, Angle = 55, Color = Color3.fromRGB(255, 244, 230), Shadows = true, Parent = key })
	local rim = new("Part", {
		Name = "RimLight",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = base * CFrame.new(-2, 3, 5),
		Parent = model,
	})
	new("PointLight", { Brightness = 1.4, Range = 12, Color = C.Accent, Parent = rim })
	model.Parent = Workspace
	stage = { Model = model, Base = base }
	if applyStage then
		applyStage() -- coloca a moto escolhida na Garagem
	end
end

-- moto à esquerda do personagem (direita da tela), com o bico virado para a câmera e apoiada no chão
local function placeMoto(skin: string)
	if stage.Moto then
		stage.Moto:Destroy()
		stage.Moto = nil
	end
	stage.Skin = skin
	local template = (vitrines and vitrines:FindFirstChild(skin)) or motoTemplate
	if not template then
		return
	end
	local moto = template:Clone()
	local spot = (stage.Base * CFrame.new(-5, 0, 1.2)).Position
	local y = groundY(spot, ignoreList())
	moto:PivotTo(CFrame.new(spot.X, y + 4, spot.Z) * (stage.Base * CFrame.Angles(0, math.rad(-32), 0)).Rotation)
	local cf, size = moto:GetBoundingBox()
	moto:PivotTo(moto:GetPivot() - Vector3.new(0, cf.Position.Y - size.Y / 2 - y, 0))
	moto.Parent = stage.Model
	stage.Moto = moto
end

local function placeCharacter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not stage or placedCharacter == character then
		return
	end
	local spot = (stage.Base * CFrame.new(1.2, 0, 0)).Position
	if (root.Position - spot).Magnitude > 40 then
		return -- longe do palco (ainda voltando ao spawn): o servidor recarrega o personagem
	end
	local p = Vector3.new(spot.X, root.Position.Y, spot.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(p, p + FACING)
	placedCharacter = character
end

-- Outros jogadores no menu ficam no mesmo spawn: some com eles daqui para o palco ficar limpo
local function hideOthers(hide: boolean)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other ~= player and other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local near = hide and stage and (root.Position - stage.Base.Position).Magnitude < 30
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = near and 1 or 0
				end
			end
		end
	end
end

local missionClock = 0
local function stageStep(dt: number)
	if not stage then
		buildStage()
	end
	stageClock += dt
	hideClock += dt
	if hideClock > 0.5 then
		hideClock = 0
		placeCharacter()
		hideOthers(true)
	end
	missionClock += dt
	if missionClock > 20 then
		missionClock = 0
		refreshMissions() -- contagem até as missões novas
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = compact and 52 or 42
	local base = stage.Base
	local focus = (base * CFrame.new(-1.9, 2.8, 0)).Position
	local dist = compact and 19 or 17
	local sway = math.sin(stageClock * 0.2) * math.rad(9)
	local dir = (base * CFrame.Angles(0, math.rad(8) + sway, 0)).LookVector
	local eye = focus + dir * dist + Vector3.new(0, 2.2, 0)
	-- mira abaixo do centro: personagem e moto sobem na tela e ficam livres dos painéis de baixo
	camera.CFrame = CFrame.lookAt(eye, focus - Vector3.new(0, compact and 2.4 or 1.6, 0))
	dof.FocusDistance = dist
	local ready = player:GetAttribute("GameMode") == "Menu"
	playGlow.Transparency = ready and (0.45 + 0.35 * math.sin(stageClock * 2.6)) or 1
end

------------------------------------------------------------------ garagem: visuais da moto comprados com as estrelas das missões
local garageFace
garagePanel, garageFace = UI.Panel({
	Name = "Garage",
	Size = UDim2.fromOffset(GARAGE_W, 560),
	AnchorPoint = Vector2.new(0, 1),
	Visible = false,
	Parent = gui,
})
UI.Text({
	Text = "GARAGEM",
	Font = F.Title,
	TextSize = 28,
	Position = UDim2.fromOffset(24, 20),
	Size = UDim2.new(1, -48, 0, 34),
	Parent = garageFace,
})
local garageStars = starCount(garageFace, UDim2.new(1, -24, 0, 24), 20)
local garageSub = UI.Text({
	Text = "Ganhe estrelas nas missões do dia",
	Font = F.Body,
	TextSize = 15,
	Transparency = MUTED,
	Position = UDim2.fromOffset(24, 58),
	Size = UDim2.new(1, -48, 0, 20),
	Parent = garageFace,
})
local tabsRow = hlist(garageFace, { Name = "Tabs", Position = UDim2.fromOffset(24, 92), Size = UDim2.new(1, -48, 0, 40), Padding = 8 })
local grid = new("ScrollingFrame", {
	Name = "Grid",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Text,
	ScrollBarImageTransparency = 0.7,
	ZIndex = 2,
	Parent = garageFace,
})
new("UIGridLayout", {
	CellSize = UDim2.new(1 / 2, -6, 0, 104),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = grid,
})
new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), Parent = grid })
local garageBack = button({
	Name = "GarageBack",
	Text = "VOLTAR",
	TextSize = 20,
	Key = "M",
	Pad = "B",
	Size = UDim2.new(1, -48, 0, 56),
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -24),
	Parent = garageFace,
})

layoutGarage = function(w: number, h: number, m: number, top: number)
	garagePanel.Size = UDim2.fromOffset(math.min(GARAGE_W, w - 2 * m), shortScreen and h - top - m or math.min(600, h - top - m - 64))
	garagePanel.Position = UDim2.new(0, m, 1, -m) -- à esquerda: a moto do palco fica à vista
	garageSub.Visible = not shortScreen
	local tabsY = shortScreen and 60 or 92
	tabsRow.Position = UDim2.fromOffset(24, tabsY)
	grid.Position = UDim2.fromOffset(24, tabsY + 54)
	grid.Size = UDim2.new(1, -40, 1, -(tabsY + 54) - 96)
end

local currentTab = CosmeticConfig.Categories[1].Id
local armed = nil -- item esperando o 2º toque para comprar
local preview = {} -- [categoria] = item mostrado na moto do palco antes de comprar
local tabButtons, cards = {}, {}

local function equippedId(category: string): string
	return player:GetAttribute("Equip_" .. category) or CosmeticConfig.Default(category)
end

local function ownsItem(item): boolean
	return item.Cost == 0 or table.find(string.split(player:GetAttribute("CosmeticsOwned") or "", ","), item.Id) ~= nil
end

applyStage = function()
	if not stage then
		return
	end
	local skin = CosmeticConfig.SkinOf(preview.Moto or equippedId("Moto"))
	if stage.Skin ~= skin then
		placeMoto(skin)
	end
end

local renderGarage
-- Já é dele: usa. Não é: 1º toque mostra na moto, 2º toque compra (se tiver estrelas). Quem confere é o servidor.
local function onCard(item)
	local category = item.Category
	if ownsItem(item) then
		armed, preview[category] = nil, nil
		if equippedId(category) ~= item.Id then
			Remotes.RequestCosmetic:FireServer("equip", item.Id)
		end
	elseif armed == item.Id then
		armed, preview[category] = nil, nil
		Remotes.RequestCosmetic:FireServer("buy", item.Id)
	else
		preview[category] = item.Id
		armed = (player:GetAttribute("Stars") or 0) >= item.Cost and item.Id or nil
	end
	applyStage()
	renderGarage()
end

renderGarage = function()
	local stars = player:GetAttribute("Stars") or 0
	garageStars.Text = tostring(stars)
	for id, tab in pairs(tabButtons) do
		local on = id == currentTab
		tab.Face.BackgroundColor3 = on and C.Accent or C.Raised
		tab.Label.TextColor3 = on and C.AccentInk or C.Text
	end
	for _, card in ipairs(cards) do
		card:Destroy()
	end
	table.clear(cards)
	local category = CosmeticConfig.GetCategory(currentTab)
	for i, item in ipairs(category.Items) do
		local equipped = equippedId(category.Id) == item.Id
		local owned = ownsItem(item)
		local holder, face = UI.Panel({ Name = item.Id, Color = C.Raised, Transparency = 0.25, Shadow = false, LayoutOrder = i, Parent = grid })
		local edge = face:FindFirstChild("Edge")
		if edge and (equipped or preview[category.Id] == item.Id) then
			edge.Color = C.Accent
			edge.Transparency = equipped and 0 or 0.4
			edge.Thickness = 2
		end
		local swatch = new("Frame", {
			Name = "Swatch",
			BackgroundColor3 = item.Color or C.Panel,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 3,
			Parent = face,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = swatch })
		new("UIStroke", { Color = C.Text, Transparency = 0.8, Parent = swatch })
		if item.Rainbow then
			swatch.BackgroundColor3 = Color3.new(1, 1, 1)
			new("UIGradient", { Color = CosmeticConfig.Rainbow, Rotation = 45, Parent = swatch })
		elseif item.Icon then
			UI.IconImage(item.Icon, 18, C.Text, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Transparency = 0.2,
				ZIndex = 4,
				Parent = swatch,
			})
		end
		UI.Text({
			Text = item.Name,
			Font = F.Text,
			TextSize = 16,
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -24, 0, 22),
			Truncate = true,
			ZIndex = 3,
			Parent = face,
		})
		local status = hlist(face, { Name = "Status", Position = UDim2.fromOffset(12, 80), Size = UDim2.new(1, -24, 0, 22), Padding = 4 })
		status.ZIndex = 3
		local text, color, fade, star = "", C.Text, 0, false
		if equipped then
			text, color = "EM USO", C.Accent
		elseif owned then
			text, fade = "USAR", 0.3
		elseif armed == item.Id then
			text, color, star = "COMPRAR " .. item.Cost, C.Accent, true
		else
			text, star = tostring(item.Cost), true
			fade = stars >= item.Cost and 0 or 0.55
		end
		UI.Text({
			Text = text,
			Font = F.Title,
			TextSize = 14,
			Color = color,
			Transparency = fade,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = status,
		})
		if star then
			UI.IconImage("estrela", 14, color, { Transparency = fade, LayoutOrder = 2, ZIndex = 3, Parent = status })
		end
		UI.Hit(holder, face).Activated:Connect(function()
			onCard(item)
		end)
		table.insert(cards, holder)
	end
end

for i, cat in ipairs(CosmeticConfig.Categories) do
	local hit, label, face = button({ Name = cat.Id, Text = cat.Name, TextSize = 15, Size = UDim2.fromOffset(100, 40), Radius = 10, LayoutOrder = i, Parent = tabsRow })
	tabButtons[cat.Id] = { Face = face, Label = label }
	hit.Activated:Connect(function()
		currentTab = cat.Id
		armed = nil
		renderGarage()
	end)
end

------------------------------------------------------------------ estado
local menuOpen = false
local pending = false
local awaitingMenu = false -- a partida acabou e o servidor ainda vai trocar o modo para "Menu"
local controls = nil

local function refreshRecord()
	local best = player:GetAttribute("SurvivalBest") or 0
	chipRecord.Text = string.format("Recorde: %d %s", best, best == 1 and "entrega" or "entregas")
end
player:GetAttributeChangedSignal("SurvivalBest"):Connect(refreshRecord)
refreshRecord()

local function refreshButtons()
	local ready = player:GetAttribute("GameMode") == "Menu"
	playLabel.Text = pending and "ENTRANDO..." or (ready and "JOGAR" or "CARREGANDO")
	againLabel.Text = pending and "ENTRANDO..." or "JOGAR DE NOVO"
end

local function setControls()
	if controls then
		if menuOpen then
			controls:Disable()
		else
			controls:Enable()
		end
	end
end

local SLIDE = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local function slideIn(frame: GuiObject, dx: number, dy: number)
	if UI.ReducedMotion() then
		return
	end
	local final = frame.Position
	frame.Position = final + UDim2.fromOffset(dx, dy)
	TweenService:Create(frame, SLIDE, { Position = final }):Play()
end

local function showView(name: string)
	view = name
	local main = name == "main"
	local result = name == "result"
	layout()
	leftCol.Visible = main
	chip.Visible = main
	bottomShade.Visible = main
	dim.Visible = result
	resultPanel.Visible = result
	garagePanel.Visible = name == "garage"
	TweenService:Create(blur, TweenInfo.new(0.35), { Size = result and 14 or 0 }):Play()
	if name ~= "garage" then
		armed = nil
		table.clear(preview)
		applyStage()
	end
	if main then
		slideIn(leftCol, -60, 0)
		slideIn(rightCol, 60, 0)
		slideIn(chip, 0, -30)
		refreshNav()
	elseif result then
		UI.Show(resultPanel, 1.2)
	else
		renderGarage()
		UI.Show(garagePanel, 0.8)
		slideIn(garagePanel, -60, 0)
	end
end

showGarage = function()
	showView("garage")
end

local function setMenuOpen(open: boolean)
	if open == menuOpen then
		return
	end
	menuOpen = open
	gui.Enabled = open
	if open then
		dof.Parent = Workspace.CurrentCamera
		blur.Parent = Workspace.CurrentCamera
		RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 5, stageStep)
		showView(view)
	else
		RunService:UnbindFromRenderStep("MenuCamera")
		dof.Parent = nil
		blur.Parent = nil
		hideOthers(false)
		clearStage()
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = GameConfig.Camera.BaseFOV
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	setControls()
end

local function refresh()
	local mode = player:GetAttribute("GameMode")
	if mode == "Menu" then
		awaitingMenu = false
	end
	local inGame = mode == "Survival" or mode == "Story"
	if inGame and not awaitingMenu then
		pending = false
		setMenuOpen(false)
	else
		setMenuOpen(true)
	end
	refreshButtons()
end
player:GetAttributeChangedSignal("GameMode"):Connect(refresh)
player.CharacterAdded:Connect(function()
	placedCharacter = nil
end)

local function startSurvival()
	if not menuOpen or pending or player:GetAttribute("GameMode") ~= "Menu" then
		return
	end
	pending = true
	awaitingMenu = false
	refreshButtons()
	Remotes.RequestStartSurvival:FireServer()
	task.delay(4, function()
		if pending then
			pending = false
			refreshButtons()
		end
	end)
end

playButton.Activated:Connect(startSurvival)
againButton.Activated:Connect(startSurvival)
backButton.Activated:Connect(function()
	showView("main")
end)
garageButton.Activated:Connect(function()
	showView("garage")
end)
garageBack.Activated:Connect(function()
	showView("main")
end)
for _, name in ipairs({ "Stars", "CosmeticsOwned", "Equip_Moto" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		if view == "garage" then
			renderGarage()
		end
		applyStage()
	end)
end

Remotes.SurvivalEnded.OnClientEvent:Connect(function(result)
	local reason = REASONS[result.Reason] or REASONS.tempo
	local deliveries = result.Deliveries or 0
	resultTitle.Text = reason.Title
	resultTitle.TextColor3 = reason.Color
	resultReason.Text = reason.Text
	resultDeliveries.Text = tostring(deliveries)
	resultBest.Text = tostring(result.Best or 0)
	resultBest.TextColor3 = result.NewRecord and C.Accent or C.Text
	recordBadge.Visible = result.NewRecord == true
	resultHint.Visible = not result.NewRecord
	local missing = (result.Best or 0) - deliveries
	if (result.Best or 0) == 0 then
		resultHint.Text = "Faça uma entrega para marcar seu primeiro recorde"
	elseif missing <= 0 then
		resultHint.Text = "Igualou o seu recorde!"
	else
		resultHint.Text = string.format("Faltaram %d %s para o recorde", missing, missing == 1 and "entrega" or "entregas")
	end
	awaitingMenu = player:GetAttribute("GameMode") ~= "Menu"
	view = "result"
	if menuOpen then
		showView("result")
	else
		setMenuOpen(true)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not menuOpen then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.ButtonA then
		startSurvival()
	elseif (key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonB) and view ~= "main" then
		showView("main")
	elseif (key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonB) and openPanel then
		setPanel(openPanel) -- fecha o painel aberto
	elseif (key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonY) and view == "main" then
		showView("garage")
	end
end)

-- Sem andar a pé enquanto o menu está aberto
task.spawn(function()
	local moduleScript = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if not moduleScript then
		return
	end
	local ok, playerModule = pcall(require, moduleScript)
	if ok and playerModule then
		controls = playerModule:GetControls()
		setControls()
	end
end)

gui.Enabled = false
refresh()
