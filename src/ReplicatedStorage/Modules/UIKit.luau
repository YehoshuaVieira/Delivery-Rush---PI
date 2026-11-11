-- Visual de toda a interface: cores, fontes, ícones, painéis e animações. Mude aqui para mudar o jogo todo.

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UIKit = {}

-- Celular/tablet. No Studio dá para simular com o atributo SimularCelular = true no Workspace (antes do Play).
local SIMULATED_TOUCH = RunService:IsStudio() and workspace:GetAttribute("SimularCelular") == true
function UIKit.IsTouch(): boolean
	return SIMULATED_TOUCH or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

UIKit.Color = {
	Panel = Color3.fromRGB(22, 24, 29),
	Raised = Color3.fromRGB(40, 44, 52),
	Text = Color3.fromRGB(245, 246, 247),
	Accent = Color3.fromRGB(43, 213, 118),
	AccentInk = Color3.fromRGB(8, 32, 18),
	Red = Color3.fromRGB(255, 77, 87),
	Amber = Color3.fromRGB(255, 176, 32),
	AmberInk = Color3.fromRGB(38, 26, 4),
}

UIKit.Muted = 0.42

-- Só famílias nativas do Roblox (uma família inexistente cai numa fonte reserva borrada)
UIKit.Font = {
	Display = Font.fromName("Sarpanch", Enum.FontWeight.Heavy), -- só a marca e títulos grandes
	Title = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold),
	Number = Font.fromName("RobotoCondensed", Enum.FontWeight.Bold), -- algarismos de largura fixa
	Text = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
	Body = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
}

UIKit.Icon = {
	sacola = "rbxassetid://129354397808901",
	casa = "rbxassetid://109018356707600",
	relogio = "rbxassetid://99967857552815",
	seta = "rbxassetid://92417096397705",
	chave = "rbxassetid://126789240046612",
	mapa = "rbxassetid://121737235188477",
	reset = "rbxassetid://84741384550745",
	raio = "rbxassetid://97367165565439",
	alerta = "rbxassetid://114914260418678",
	estrela = "rbxassetid://112919832427233",
	check = "rbxassetid://119783856606731",
	xis = "rbxassetid://101020117727471",
	pino = "rbxassetid://126848606124250",
	lupa = "rbxassetid://112145426490552",
	chama = "rbxassetid://126745432048853",
	caixa = "rbxassetid://130992809257894",
	cadeado = "rbxassetid://139580238587776",
	escudo = "rbxassetid://104523881178162",
	ima = "rbxassetid://92288589498192",
	fantasma = "rbxassetid://89237818175339",
	salto = "rbxassetid://82081786489788",
	pneu = "rbxassetid://127371052111301",
	tracao = "rbxassetid://111030689410020",
	parachoque = "rbxassetid://127499411604783",
	avanco = "rbxassetid://99102005625003",
	ampulheta = "rbxassetid://115890799293823",
	sirene = "rbxassetid://78418901753455",
	caracol = "rbxassetid://110347200166297",
}
UIKit.Texture = {
	listras = "rbxassetid://108391551613274",
	sombra = "rbxassetid://79633253267165",
	anel = "rbxassetid://120077628945828",
	miolo = "rbxassetid://133847158321691",
}

UIKit.Radius = 12

local function new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
UIKit.new = new

-- Escala da UI: referência 1280×720 (toque: 1000×520), sem descer do ponto em que o texto fica miúdo
function UIKit.ScaleFor(viewport: Vector2, touch: boolean): number
	local s
	if touch then
		s = math.clamp(math.min(viewport.X / 1000, viewport.Y / 520), 0.85, 1.4)
	else
		s = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.9, 1.6)
	end
	return math.floor(s * 20 + 0.5) / 20
end

function UIKit.ReducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

-- 2.1 -> "2,1x"
function UIKit.Multiplier(m: number): string
	return (string.format("%.1fx", m):gsub("%.", ","))
end

-- remove emojis/símbolos gráficos de textos vindos do servidor (os ícones da UI são próprios)
function UIKit.StripEmoji(text: string): string
	local out = {}
	local ok = pcall(function()
		for _, code in utf8.codes(text) do
			local emoji = (code >= 0x1F000 and code <= 0x1FAFF)
				or (code >= 0x2600 and code <= 0x27BF)
				or (code >= 0x2B00 and code <= 0x2BFF)
				or (code >= 0x2190 and code <= 0x21FF)
				or code == 0xFE0F
				or code == 0x200D
				or (code >= 0x231A and code <= 0x23FF)
			if not emoji then
				table.insert(out, utf8.char(code))
			end
		end
	end)
	if not ok then
		return text -- UTF-8 inválido: mostra como veio
	end
	return (table.concat(out):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " "))
end

function UIKit.Text(props: { [string]: any })
	local size = props.TextSize or 15
	return new("TextLabel", {
		Name = props.Name or "Text",
		BackgroundTransparency = 1,
		FontFace = props.Font or UIKit.Font.Text,
		TextSize = size,
		TextColor3 = props.Color or UIKit.Color.Text,
		TextTransparency = props.Transparency or 0,
		Text = props.Text or "",
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrapped or false,
		TextTruncate = props.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
		RichText = props.RichText or false,
		Size = props.Size or UDim2.new(1, 0, 0, size + 4),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 2,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
end

function UIKit.IconImage(name: string, size: number, color: Color3?, props: { [string]: any }?)
	props = props or {}
	return new("ImageLabel", {
		Name = props.Name or "Icon",
		BackgroundTransparency = 1,
		Image = UIKit.Icon[name] or "",
		ImageColor3 = color or UIKit.Color.Text,
		ImageTransparency = props.Transparency or 0,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 2,
		Parent = props.Parent,
	})
end

-- Painel: retorna (holder, face). O holder posiciona e anima; o conteúdo vai na face.
function UIKit.Panel(opts: { [string]: any })
	local holder = new("Frame", {
		Name = opts.Name or "Panel",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(100, 40),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		Visible = opts.Visible ~= false,
	})
	new("UIScale", { Name = "Pop", Parent = holder })
	if opts.Shadow ~= false then
		new("ImageLabel", {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = UIKit.Texture.sombra,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(40, 40, 88, 88),
			ImageTransparency = 0.45,
			Size = UDim2.new(1, 26, 1, 26),
			Position = UDim2.new(0.5, 0, 0.5, 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 0,
			Parent = holder,
		})
	end
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = opts.Color or UIKit.Color.Panel,
		BackgroundTransparency = opts.Transparency or 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, opts.Radius or UIKit.Radius), Parent = face })
	if opts.Stroke ~= false then
		new("UIStroke", {
			Name = "Edge",
			Color = UIKit.Color.Text,
			Transparency = 0.9,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = face,
		})
	end
	holder.Parent = opts.Parent
	return holder, face
end

-- Fita de alerta zebrada dentro de uma face (CanvasGroup recorta as listras nos cantos).
function UIKit.Tape(face: GuiObject, stripeColor: Color3, radius: number?, tile: number?)
	tile = tile or 22
	local group = new("CanvasGroup", {
		Name = "Tape",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = face,
	})
	new("UICorner", { CornerRadius = UDim.new(0, radius or UIKit.Radius), Parent = group })
	local stripes = new("ImageLabel", {
		Name = "Stripes",
		BackgroundTransparency = 1,
		Image = UIKit.Texture.listras,
		ImageColor3 = stripeColor,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile, tile),
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	})
	return group, stripes
end

-- Dispositivo preferido do jogador: "Keyboard", "Gamepad" ou "Touch" (UserInputService.PreferredInput)
function UIKit.InputKind(): string
	if SIMULATED_TOUCH then
		return "Touch"
	end
	local ok, pref = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and pref then
		if pref == Enum.PreferredInput.Gamepad or pref == Enum.PreferredInput.MicroGamepad then
			return "Gamepad"
		end
		return pref == Enum.PreferredInput.Touch and "Touch" or "Keyboard"
	end
	return UIKit.IsTouch() and "Touch" or "Keyboard"
end

-- Dicas de tecla que seguem o dispositivo: no controle mostram o botão equivalente (props.Gamepad)
-- ou somem se não houver; no toque somem. Trocou de dispositivo no meio do jogo? Elas se atualizam sozinhas.
local keycaps = setmetatable({}, { __mode = "k" })
local function applyKeycap(cap: TextLabel, info)
	local kind = UIKit.InputKind()
	local text = (kind == "Keyboard" and info.Key) or (kind == "Gamepad" and info.Pad) or nil
	cap.Visible = text ~= nil
	if text then
		cap.Text = text
		cap.Size = UDim2.fromOffset(info.Width or math.max(20, 10 + utf8.len(text) * 9), cap.Size.Y.Offset)
	end
end
pcall(function()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		for cap, info in pairs(keycaps) do
			applyKeycap(cap, info)
		end
	end)
end)

function UIKit.Keycap(letter: string, props: { [string]: any }?)
	props = props or {}
	local cap = new("TextLabel", {
		Name = props.Name or "Key",
		BackgroundColor3 = props.Background or UIKit.Color.Raised,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		TextColor3 = props.Color or UIKit.Color.Text,
		FontFace = UIKit.Font.Number,
		TextSize = props.TextSize or 14,
		Text = letter,
		Size = UDim2.fromOffset(props.Width or 20, props.Height or 20),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 3,
		Parent = props.Parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = cap })
	local info = { Key = letter, Pad = props.Gamepad, Width = props.Width }
	keycaps[cap] = info
	applyKeycap(cap, info)
	return cap
end

-- Botão invisível por cima da face, com resposta (cresce no hover, afunda no clique)
function UIKit.Hit(holder: GuiObject, face: GuiObject): TextButton
	local button = new("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		AutoButtonColor = false,
		Parent = face,
	})
	local pop = holder:FindFirstChild("Pop")
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local hovering = false
	local function to(scale)
		if pop then
			TweenService:Create(pop, quick, { Scale = scale }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		to(1.04)
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.95)
	end)
	button.MouseButton1Up:Connect(function()
		to(hovering and 1.04 or 1)
	end)
	return button
end

local POP = TweenInfo.new(0.18, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- strength 0..1.5 (quanto maior, maior o "pulo" de entrada)
function UIKit.Show(holder: GuiObject, strength: number?)
	holder.Visible = true
	holder:SetAttribute("Hiding", false)
	local pop = holder:FindFirstChild("Pop")
	if UIKit.ReducedMotion() or not pop then
		if pop then
			pop.Scale = 1
		end
		return
	end
	pop.Scale = 1 + 0.1 * (strength or 1)
	TweenService:Create(pop, POP, { Scale = 1 }):Play()
end

function UIKit.Hide(holder: GuiObject, onDone: (() -> ())?)
	if not holder.Visible then
		if onDone then
			onDone()
		end
		return
	end
	local pop = holder:FindFirstChild("Pop")
	holder:SetAttribute("Hiding", true)
	local function finish()
		if holder:GetAttribute("Hiding") then
			holder.Visible = false
			holder:SetAttribute("Hiding", false)
			if pop then
				pop.Scale = 1
			end
			if onDone then
				onDone()
			end
		end
	end
	if UIKit.ReducedMotion() or not pop then
		finish()
		return
	end
	local tween = TweenService:Create(pop, HIDE, { Scale = 0.92 })
	tween.Completed:Once(finish)
	tween:Play()
end

-- Mostra/esconde sem repetir a animação se o estado não mudou
function UIKit.SetShown(holder: GuiObject, shown: boolean, strength: number?)
	local visibleNow = holder.Visible and not holder:GetAttribute("Hiding")
	if shown and not visibleNow then
		UIKit.Show(holder, strength)
	elseif not shown and visibleNow then
		UIKit.Hide(holder)
	end
end

return UIKit
