-- Polimento das motos: baú com fita refletiva e logo da marca, placa Mercosul e pintura com brilho.
-- Pode rodar de novo: as peças criadas aqui têm o atributo "Polimento" e são refeitas.

local AcabamentoMoto = {}

local ICON_CAIXA = "rbxassetid://130992809257894"
local DISPLAY = Font.fromName("Sarpanch", Enum.FontWeight.Heavy)
local NUMBER = Font.fromName("RobotoCondensed", Enum.FontWeight.Bold)
local ACCENT = Color3.fromRGB(43, 213, 118)
local GRAPHITE = Color3.fromRGB(20, 22, 26)

local function new(class: string, props)
	local i = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			i[k] = v
		end
	end
	i.Parent = props.Parent
	return i
end

-- peça visual presa ao chassi (sem massa e sem colisão, como o resto do Visual)
local function attach(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = new("Part", {
		Name = name, Size = size, CFrame = cf, Color = color, Material = material,
		Anchored = false, Massless = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		Parent = model:FindFirstChild("Visual") or model,
	})
	p:SetAttribute("Polimento", true)
	new("WeldConstraint", { Part0 = model.Chassis, Part1 = p, Parent = p })
	return p
end

-- selo da marca: retângulo grafite com o ícone verde da caixa e "DELIVERY RUSH" (mesma marca do menu)
local function brand(part: BasePart, face: Enum.NormalId)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("SurfaceGui") then
			c:Destroy()
		end
	end
	local g = new("SurfaceGui", {
		Name = "Marca", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 140,
		LightInfluence = 0.5, Parent = part,
	})
	local tag = new("Frame", {
		BackgroundColor3 = GRAPHITE, BackgroundTransparency = 0.04, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.96, 0.86), Parent = g,
	})
	new("UICorner", { CornerRadius = UDim.new(0.18, 0), Parent = tag })
	new("UIStroke", { Color = ACCENT, Thickness = 3, Transparency = 0.15, Parent = tag })
	local icon = new("ImageLabel", {
		BackgroundTransparency = 1, Image = ICON_CAIXA, ImageColor3 = ACCENT, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.06, 0.5), Size = UDim2.fromScale(0.62, 0.62), Parent = tag,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = icon })
	new("TextLabel", {
		BackgroundTransparency = 1, Text = "DELIVERY\nRUSH", FontFace = DISPLAY, TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 0.86,
		Position = UDim2.fromScale(0.36, 0.14), Size = UDim2.fromScale(0.6, 0.72), Parent = tag,
	})
end

-- placa Mercosul: faixa azul "BRASIL" em cima e o código embaixo
local function plateGui(part: BasePart, code: string)
	local g = new("SurfaceGui", {
		Name = "Placa", Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 160,
		LightInfluence = 0.6, Parent = part,
	})
	local bg = new("Frame", { BackgroundColor3 = Color3.fromRGB(246, 246, 244), Size = UDim2.fromScale(1, 1), Parent = g })
	new("UIStroke", { Color = Color3.fromRGB(30, 30, 34), Thickness = 2, Parent = bg })
	local band = new("Frame", { BackgroundColor3 = Color3.fromRGB(0, 56, 168), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.27), Parent = bg })
	new("TextLabel", {
		BackgroundTransparency = 1, Text = "BRASIL", FontFace = NUMBER, TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
		Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0, 0.05), Parent = band,
	})
	new("TextLabel", {
		BackgroundTransparency = 1, Text = code, FontFace = NUMBER, TextColor3 = Color3.fromRGB(20, 20, 24), TextScaled = true,
		Position = UDim2.fromScale(0.04, 0.3), Size = UDim2.fromScale(0.92, 0.66), Parent = bg,
	})
end

function AcabamentoMoto.Polir(model: Model, level: number): string
	local visual = model:FindFirstChild("Visual") or model
	local chassis = model:FindFirstChild("Chassis")
	if not chassis then
		return model.Name .. ": sem Chassis"
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Polimento") then
			d:Destroy()
		end
	end
	local done = {}

	-- pintura com brilho de verniz (o plástico fosco deixava tudo apagado)
	for _, name in ipairs({ "body", "deliverybox" }) do
		local p = visual:FindFirstChild(name)
		if p and p:IsA("MeshPart") then
			if p:GetAttribute("OrigMaterial") == nil then
				p:SetAttribute("OrigMaterial", p.Material.Name)
			end
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	table.insert(done, "verniz")

	-- baú: fita refletiva em volta e selo da marca nos três lados
	local box = visual:FindFirstChild("deliverybox")
	if box then
		attach(model, "FitaRefletiva", Vector3.new(box.Size.X + 0.02, 0.06, box.Size.Z + 0.02), box.CFrame * CFrame.new(0, -box.Size.Y * 0.2, 0),
			Color3.fromRGB(222, 226, 232), Enum.Material.SmoothPlastic).Reflectance = 0.3
		table.insert(done, "fita")
	end
	for name, face in pairs({ LogoTras = Enum.NormalId.Back, LogoDireita = Enum.NormalId.Right, LogoEsquerda = Enum.NormalId.Left }) do
		local logo = visual:FindFirstChild(name)
		if logo then
			brand(logo, face)
		end
	end
	table.insert(done, "marca")

	-- hastes do bagageiro mais grossas (o baú parecia flutuar)
	for _, h in ipairs(visual:GetChildren()) do
		if h.Name == "BagageiroHaste" and h:IsA("BasePart") and h.Size.X < 0.25 then
			h.Size = Vector3.new(0.28, h.Size.Y, 0.28)
		end
	end

	-- placa Mercosul atrás, logo acima da roda traseira
	local rear = visual:FindFirstChild("rearwheel")
	if rear then
		local rl = chassis.CFrame:ToObjectSpace(rear.CFrame).Position
		local radius = rear.Size.Y / 2
		-- logo atrás da borda da roda, abaixo das lanternas do próprio modelo
		local cf = chassis.CFrame * CFrame.new(rl.X, rl.Y + radius + 0.12, rl.Z + rear.Size.Z * 0.5 + 0.12) * CFrame.Angles(math.rad(14), 0, 0)
		local plate = attach(model, "Placa", Vector3.new(1.05, 0.36, 0.05), cf, Color3.fromRGB(246, 246, 244), Enum.Material.SmoothPlastic)
		plateGui(plate, string.format("DLV%dR26", level))
		attach(model, "SuportePlaca", Vector3.new(0.14, 0.6, 0.14), cf * CFrame.new(0, 0.42, -0.1), Color3.fromRGB(24, 24, 28), Enum.Material.Metal)
		table.insert(done, "placa")
	end

	return model.Name .. ": " .. table.concat(done, ", ")
end

return AcabamentoMoto
