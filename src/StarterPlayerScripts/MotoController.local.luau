-- Pilotagem arcade da moto (física no cliente), câmera, grau/turbo, perigos e controles de toque.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local MotoSignals = require(Modules:WaitForChild("MotoSignals"))
local RoadMap = require(Modules:WaitForChild("RoadMap"))
local AbilityConfig = require(Modules:WaitForChild("AbilityConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MOTO = GameConfig.Moto
local CAM = GameConfig.Camera
local MAN = GameConfig.Maneuver
local OFFROAD = GameConfig.OffRoad
local FEES = GameConfig.Fees
local TOP_SPEED = UpgradeConfig.Get(UpgradeConfig.MaxLevel).Speed

local motosFolder = Workspace:WaitForChild("Motos")

local controls = nil
task.spawn(function()
	local moduleScript = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if not moduleScript then
		return
	end
	local ok, playerModule = pcall(require, moduleScript)
	if ok and playerModule then
		controls = playerModule:GetControls()
	end
end)

local touchButtons = nil
local touchGui = nil
local activeTouches = {}
local useJump, useGhost, useSiren, useSlow -- habilidades ativas (definidas mais abaixo)
local relayoutTouch = function() end
if UserInputService.TouchEnabled or require(Modules:WaitForChild("UIKit")).IsTouch() then
	local gui = Instance.new("ScreenGui")
	touchGui = gui
	gui.Name = "TouchControls"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 5
	local V = require(Modules:WaitForChild("UIKit"))
	local function button(name, face, ink, icon, iconRotation, label)
		local holder, faceFrame = V.Panel({
			Name = name,
			Size = UDim2.fromOffset(100, 100),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = face,
			Transparency = 0.12,
			Radius = 999,
			Parent = gui,
		})
		if label then
			local text = V.Text({
				Text = label,
				Font = V.Font.Title,
				Color = ink,
				XAlign = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.4),
				Parent = faceFrame,
			})
			text.TextScaled = true
		else
			local image = V.IconImage(icon, 40, ink, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = faceFrame,
			})
			image.Size = UDim2.fromScale(0.46, 0.46)
			image.Rotation = iconRotation or 0
		end
		return holder
	end
	local C = V.Color
	touchButtons = {
		Left = button("Esquerda", C.Panel, C.Text, "seta", -90),
		Right = button("Direita", C.Panel, C.Text, "seta", 90),
		Gas = button("Acelerar", C.Accent, C.AccentInk, "seta", 0),
		Brake = button("Freio", C.Red, C.Text, "seta", 180),
		Grau = button("Grau", C.Panel, C.Accent, nil, nil, "GRAU"),
		Jump = button("Salto", C.Panel, C.Accent, "salto"),
		Ghost = button("Fantasma", C.Panel, C.Accent, "fantasma"),
		Siren = button("Sirene", C.Panel, C.Accent, "sirene"),
		Slow = button("Lento", C.Panel, C.Accent, "caracol"),
	}
	-- habilidades ativas: aparecem só quando o jogador tem a habilidade
	for name, fire in pairs({
		Jump = function() return useJump() end, Ghost = function() return useGhost() end,
		Siren = function() return useSiren() end, Slow = function() return useSlow() end,
	}) do
		local holder = touchButtons[name]
		holder.Visible = false
		holder.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				fire()
			end
		end)
	end
	-- Botões logo acima do menu (esquerda) e do velocímetro (direita), na escala do HUD.
	local function hudScale(): number
		local hud = player.PlayerGui:FindFirstChild("HUD")
		local scale = hud and hud:FindFirstChildOfClass("UIScale")
		return scale and scale.Scale or 0.75
	end
	local function layout()
		local vp = Workspace.CurrentCamera.ViewportSize
		local s = math.clamp(vp.Y * 0.18, 56, 110)
		local B = touchButtons
		local k = hudScale()
		local leftReserve = (16 + 56 + 14) * k
		local rightReserve = (16 + 76 + 14) * k
		local leftY = -(leftReserve + s / 2)
		B.Left.Size = UDim2.fromOffset(s, s)
		B.Left.Position = UDim2.new(0, 16 + s / 2, 1, leftY)
		B.Right.Size = UDim2.fromOffset(s, s)
		B.Right.Position = UDim2.new(0, 16 + s * 1.65, 1, leftY)
		local rowY = -(rightReserve + s / 2)
		local bs = s * 0.82
		local gs = s * 0.75
		B.Gas.Size = UDim2.fromOffset(s, s)
		B.Gas.Position = UDim2.new(1, -(16 + s / 2), 1, rowY)
		B.Brake.Size = UDim2.fromOffset(bs, bs)
		B.Brake.Position = UDim2.new(1, -(16 + s + 12 + bs / 2), 1, rowY)
		B.Grau.Size = UDim2.fromOffset(gs, gs)
		B.Grau.Position = UDim2.new(1, -(16 + s + 12 + bs + 12 + gs / 2), 1, rowY)
		-- habilidades visíveis em fila acima das setas (à direita, em cima, fica o cartão do pedido)
		local upperY = leftY - s / 2 - 12 - gs / 2
		local x = 16 + gs / 2
		for _, name in ipairs({ "Jump", "Ghost", "Siren", "Slow" }) do
			local b = B[name]
			b.Size = UDim2.fromOffset(gs, gs)
			if b.Visible then
				b.Position = UDim2.new(0, x, 1, upperY)
				x += gs + 12
			end
		end
	end
	relayoutTouch = layout
	layout()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	task.spawn(function()
		local hud = player.PlayerGui:WaitForChild("HUD", 20)
		local scale = hud and hud:WaitForChild("UIScale", 10)
		if scale then
			scale:GetPropertyChangedSignal("Scale"):Connect(layout)
			layout()
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	UserInputService.TouchStarted:Connect(function(input)
		activeTouches[input] = true
	end)
	UserInputService.TouchEnded:Connect(function(input)
		activeTouches[input] = nil
	end)
	-- sem foco o TouchEnded pode não chegar: solta tudo para a moto não acelerar sozinha
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(activeTouches)
	end)
end

-- o botão está sendo apertado por algum dedo agora?
local function touchPressed(b: GuiObject): boolean
	local center = b.AbsolutePosition + b.AbsoluteSize / 2
	local radius = b.AbsoluteSize.X * 0.62
	local down = false
	for input in pairs(activeTouches) do
		if (Vector2.new(input.Position.X, input.Position.Y) - center).Magnitude <= radius then
			down = true
			break
		end
	end
	local pop = b:FindFirstChild("Pop")
	if pop then
		pop.Scale = down and 0.9 or 1
	end
	return down
end

local current = nil
local speed = 0
local yaw, lean, pitch = 0, 0, 0
local camYaw = 0
local lastCommanded = 0
local lastDirection = Vector3.new(0, 0, -1)
local bumpCooldown = 0
local usingCustomCamera = false

local grauActive = false
local grauTime = 0
local grauCooldown = 0
local needShiftRelease = false
local turboCharge = 0
local boostTime = 0
local boostPower = 0
local airTime = 0
local stunTime = 0
local shake = 0
local maneuverCounter = 0

local skidTime = 0
local skidDrift = 0
local flatTime = 0
local flatImmunity = 0

local lastDisplaySpeed, lastCharge, lastBoosting, lastFlat = -1, -1, nil, -1
local lastOffRoad = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Avisa o HUD (Attribute local, não replica)
local function announce(text: string)
	maneuverCounter += 1
	player:SetAttribute("Maneuver", text .. "#" .. maneuverCounter)
end

-- Habilidades da Sobrevivência (a lista vem do servidor no atributo "Abilities").
-- Os tempos ficam em atributos locais (relógio os.clock) para o HUD mostrar a recarga.
local abilities = {}
local shieldReadyAt, ghostUntil, ghostReadyAt, jumpReadyAt = 0, 0, 0, 0
local sirenReadyAt, slowReadyAt = 0, 0
local nitroUsedFor = nil
local lastGrounded = false
local knock, knockSpin = Vector3.zero, 0 -- empurrão de um carro que acertou a moto
local SHIELDABLE = { car = true, ped = true, ball = true, pothole = true, mud = true, oil = true, water = true, spike = true }

local function refreshAbilities()
	abilities = AbilityConfig.Parse(player:GetAttribute("Abilities"))
	if next(abilities) == nil then
		shieldReadyAt, ghostUntil, ghostReadyAt, jumpReadyAt, nitroUsedFor = 0, 0, 0, 0, nil
		sirenReadyAt, slowReadyAt = 0, 0
		for _, name in ipairs({ "ShieldReadyAt", "GhostUntil", "GhostReadyAt", "JumpReadyAt", "SirenUntil", "SirenReadyAt", "SlowUntil", "SlowReadyAt" }) do
			player:SetAttribute(name, nil)
		end
	end
	if touchButtons then
		touchButtons.Jump.Visible = abilities.jump == true
		touchButtons.Ghost.Visible = abilities.ghost == true
		touchButtons.Siren.Visible = abilities.siren == true
		touchButtons.Slow.Visible = abilities.slowmo == true
		relayoutTouch()
	end
end
player:GetAttributeChangedSignal("Abilities"):Connect(refreshAbilities)
refreshAbilities()

local function inSurvival(): boolean
	return player:GetAttribute("GameMode") == "Survival"
end

local function impact(kind: string, intensity: number)
	MotoSignals.Impact:Fire(kind, math.clamp(intensity, 0, 1))
end

-- Fantasma atravessa tudo; o escudo bloqueia um impacto e depois recarrega
local function absorbed(kind: string): boolean
	local now = os.clock()
	if now < ghostUntil then
		return true
	end
	if abilities.shield and SHIELDABLE[kind] and now >= shieldReadyAt then
		shieldReadyAt = now + AbilityConfig.Get("shield").Cooldown
		player:SetAttribute("ShieldReadyAt", shieldReadyAt)
		shake = math.max(shake, 0.25)
		announce("ESCUDO!")
		impact("shield", 1)
		return true
	end
	return false
end

-- Na Sobrevivência a batida só zera a sequência da Entrega Perfeita (não há multa); na História vira taxa
local function reportHit(storyKind: string?)
	if inSurvival() then
		Remotes.ReportIncident:FireServer("hit")
	elseif storyKind then
		Remotes.ReportIncident:FireServer(storyKind)
	end
end

local function yawFromCFrame(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function getInput(): (number, number)
	local throttle, steer = 0, 0
	if controls then
		local move = controls:GetMoveVector()
		throttle = -move.Z
		steer = move.X
	end
	if throttle == 0 and steer == 0 and UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.2 then
				steer = input.Position.X
				throttle = input.Position.Y
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 and input.Position.Z > 0.1 then
				throttle = input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 and input.Position.Z > 0.1 then
				throttle = -input.Position.Z
			end
		end
	end
	if throttle == 0 and steer == 0 and touchButtons then
		if touchPressed(touchButtons.Gas) then throttle += 1 end
		if touchPressed(touchButtons.Brake) then throttle -= 1 end
		if touchPressed(touchButtons.Right) then steer += 1 end
		if touchPressed(touchButtons.Left) then steer -= 1 end
	end
	if throttle == 0 and steer == 0 and not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			throttle += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			throttle -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			steer += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			steer -= 1
		end
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

local function isManeuverHeld(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or (touchButtons ~= nil and touchPressed(touchButtons.Grau))
		or (UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
			and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonX))
end

local function setFilter(c)
	local filter = { c.Model }
	if player.Character then
		table.insert(filter, player.Character)
	end
	local fx = Workspace:FindFirstChild("LocalWorldFX")
	if fx then
		table.insert(filter, fx)
	end
	rayParams.FilterDescendantsInstances = filter
end

local GROUND_RAY = Vector3.new(0, -2.9, 0)
local function isGrounded(c): boolean
	return Workspace:Raycast(c.Chassis.Position, GROUND_RAY, rayParams) ~= nil
end

local function findMoto()
	local moto = motosFolder:FindFirstChild("Moto_" .. player.UserId)
	local chassis = moto and moto:FindFirstChild("Chassis")
	if not chassis then
		return nil
	end
	local lv = chassis:FindFirstChild("LinearVelocity")
	local ao = chassis:FindFirstChild("AlignOrientation")
	if not lv or not ao then
		return nil
	end
	local exhaust = moto:FindFirstChild("Exhaust")
	local airForce = chassis:FindFirstChild("AirForce")
	if not airForce then
		airForce = Instance.new("VectorForce")
		airForce.Name = "AirForce"
		airForce.Attachment0 = chassis:FindFirstChild("RootAttachment")
		airForce.RelativeTo = Enum.ActuatorRelativeTo.World
		airForce.ApplyAtCenterOfMass = true
		airForce.Force = Vector3.zero
		airForce.Parent = chassis
	end
	return {
		Model = moto, Chassis = chassis, LV = lv, AO = ao, AirForce = airForce,
		ResetId = moto:GetAttribute("ResetId"),
		Flame = exhaust and exhaust:FindFirstChild("TurboFlame"),
		Tail = moto:FindFirstChild("LanternaBau", true),
	}
end

local function resetManeuver()
	grauActive, grauTime, boostTime, pitch, airTime, stunTime = false, 0, 0, 0, 0, 0
end

local function bind(entry)
	current = entry
	speed, lastCommanded, lean = 0, 0, 0
	flatTime, flatImmunity, skidTime = 0, 0, 0
	resetManeuver()
	yaw = yawFromCFrame(entry.AO.CFrame)
	camYaw = yaw
	lastDirection = CFrame.Angles(0, yaw, 0).LookVector
end

-- push (Vector3) = velocidade do carro quando é ELE que acerta a moto; sem push, foi a moto que bateu
MotoSignals.Bump.Event:Connect(function(kind, push)
	if not current then
		return
	end
	if kind == "cone" then
		if os.clock() >= ghostUntil then
			speed *= 0.85
			shake = math.max(shake, 0.15)
			impact("cone", math.abs(speed) / 50)
		end
		return
	end
	if absorbed(kind) then
		return
	end
	local intensity = math.clamp(math.abs(speed) / 60, 0.3, 1)
	local bumper = abilities.bumper and AbilityConfig.Get("bumper")
	if kind == "car" and typeof(push) == "Vector3" then
		-- o carro acertou a moto (parada ou atravessando): ela é empurrada para onde o carro ia
		reportHit(nil)
		impact("car", math.clamp(push.Magnitude / 40, 0.5, 1))
		local factor = bumper and bumper.PushFactor or 1
		knock = push * factor
		knockSpin = (push:Cross(CFrame.Angles(0, yaw, 0).LookVector).Y > 0 and 1 or -1) * 2.2 * factor
		speed *= bumper and bumper.KeepSpeed or 0.3
		stunTime = bumper and 0 or 0.45
		bumpCooldown = 0.6
		shake = bumper and 0.4 or 0.8
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		turboCharge *= 0.5
		announce("CARRO TE ACERTOU!")
	elseif kind == "car" then
		reportHit(math.abs(speed) >= FEES.CarCrashMinSpeed and "car" or nil)
		impact("car", intensity)
		if bumper then
			speed *= bumper.KeepSpeed
			shake = 0.3
		else
			local back = math.max(math.abs(speed) * 0.5, 8)
			speed = (speed >= 0) and -back or back
			stunTime = 0.35
			shake = 0.5
		end
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		turboCharge *= 0.5
		announce("BATEU!")
	elseif kind == "ped" then
		reportHit(nil)
		impact("ped", intensity)
		speed *= bumper and bumper.KeepSpeed or 0.5
		stunTime = bumper and 0 or 0.3
		shake = bumper and 0.35 or 0.7
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		announce("ATROPELOU!")
	elseif kind == "ball" then
		reportHit(nil)
		impact("ball", 1)
		if bumper then
			speed *= bumper.KeepSpeed
			shake = 0.5
		else
			local back = math.max(math.abs(speed) * 0.6, 14)
			speed = (speed >= 0) and -back or back
			stunTime = 0.5
			shake = 0.9
		end
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		announce("BOLADA!")
	end
end)

MotoSignals.Hazard.Event:Connect(function(kind, limit)
	if not current then
		return
	end
	local absSpeed = math.abs(speed)
	-- só gasta o escudo se o perigo fosse ter efeito nesta velocidade
	-- Tração Total anula óleo/água e suaviza a lama; Pneus Reforçados anulam o buraco
	local grip, tires = abilities.grip, abilities.tires
	local wouldHit = (kind == "oil" and not grip and skidTime <= 0 and absSpeed > 10)
		or (kind == "water" and not grip and skidTime <= 0 and absSpeed > 10)
		or (kind == "pothole" and not tires and absSpeed > 8)
		or (kind == "mud" and not grip and absSpeed > 8)
	if wouldHit then
		if absorbed(kind) then
			return
		end
		reportHit(nil)
		impact(kind, absSpeed / 60)
	end
	if kind == "oil" and wouldHit then
		skidTime = 1.3
		skidDrift = math.rad(math.random(55, 85)) * ((math.random() < 0.5) and -1 or 1)
		grauActive = false
		shake = 0.4
		announce("ÓLEO NA PISTA!")
	elseif kind == "pothole" and wouldHit then
		speed *= 0.6
		shake = 0.6
		local v = current.Chassis.AssemblyLinearVelocity
		current.Chassis.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + 14, v.Z)
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		announce("BURACO!")
	elseif kind == "mud" and wouldHit then
		speed *= 0.45
		shake = math.max(shake, 0.3)
		if grauActive then
			grauActive = false
			needShiftRelease = true
		end
		announce("LAMA!")
	elseif kind == "mud" and grip and absSpeed > 8 then
		speed *= AbilityConfig.Get("grip").MudFactor
		shake = math.max(shake, 0.1)
	elseif kind == "pothole" and tires and absSpeed > 8 then
		shake = math.max(shake, 0.12)
		impact("pothole", 0.2)
	elseif kind == "bump" and os.clock() >= ghostUntil then
		-- Lombada como na vida real: devagar a moto só balança (sem barulho e sem perder velocidade);
		-- quanto mais rápido, maior o tranco, o pulo e a perda de velocidade
		local ratio = absSpeed / (current.Model:GetAttribute("MaxSpeed") or 40)
		local v = current.Chassis.AssemblyLinearVelocity
		if ratio < 0.3 then
			shake = math.max(shake, 0.04)
		elseif ratio < 0.55 then
			current.Chassis.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + 5, v.Z)
			shake = math.max(shake, 0.15)
			impact("bump", 0.35)
		else
			local over = math.clamp((ratio - 0.55) / 0.45, 0, 1)
			speed *= 0.9 - 0.2 * over
			shake = 0.3 + 0.3 * over
			current.Chassis.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + 12 + 12 * over, v.Z)
			if grauActive and over > 0.5 then
				grauActive = false
				needShiftRelease = true
			end
			announce("LOMBADA! REDUZA")
			impact("bump", 0.65 + 0.35 * over)
		end
	elseif kind == "water" and wouldHit then
		skidTime = 0.8
		skidDrift = math.rad(math.random(45, 70)) * ((math.random() < 0.5) and -1 or 1)
		announce("ÁGUA NA PISTA!")
	elseif kind == "radar" and not inSurvival() and typeof(limit) == "number" and absSpeed > limit + 0.5 then
		Remotes.ReportIncident:FireServer("radar")
		announce("RADAR! MULTA")
	end
end)

MotoSignals.FlatTire.Event:Connect(function()
	if not current or flatTime > 0 or flatImmunity > 0 then
		return
	end
	if abilities.tires then
		flatImmunity = 1.5
		shake = math.max(shake, 0.12)
		announce("PNEU REFORÇADO!")
		return
	end
	if absorbed("spike") then
		return
	end
	flatTime = MOTO.FlatTireTime
	reportHit("spike")
	impact("spike", 1)
	grauActive = false
	boostTime = 0
	needShiftRelease = true
	shake = 0.7
	announce("PNEU FURADO!")
end)

local function updateManeuver(c, dt: number, grounded: boolean)
	grauCooldown = math.max(0, grauCooldown - dt)

	if grounded then
		if airTime >= MAN.JumpMinAirTime then
			turboCharge = math.min(1, turboCharge + MAN.JumpChargeBonus)
			announce("SALTO! +TURBO")
		end
		airTime = 0
	else
		airTime += dt
	end

	local held = isManeuverHeld()
	if not held then
		needShiftRelease = false
	end

	if grauActive then
		if not held or speed < MAN.GrauMinSpeed * 0.5 then
			grauActive = false
			grauCooldown = MAN.Cooldown
			if turboCharge >= MAN.MinChargeToBoost then
				boostPower = turboCharge
				boostTime = MAN.BoostDuration
				turboCharge = 0
				announce("TURBO!")
			end
		else
			grauTime += dt
			if grounded then
				turboCharge = math.min(1, turboCharge + dt / MAN.GrauChargeTime)
			end
			if grauTime > MAN.GrauMaxTime then
				grauActive = false
				grauCooldown = MAN.Cooldown * 1.5
				needShiftRelease = true
				turboCharge = 0
				speed *= MAN.FailSpeedFactor
				shake = 0.6
				announce("CAIU DO GRAU!")
			end
		end
	elseif held and not needShiftRelease and grauCooldown <= 0 and grounded and speed >= MAN.GrauMinSpeed and flatTime <= 0 then
		grauActive = true
		grauTime = 0
		announce("GRAU!")
	end

	boostTime = math.max(0, boostTime - dt)
end

-- Modo Fantasma: moto e piloto semitransparentes enquanto dura
local ghostShown = false
local function updateGhostLook(c)
	local on = os.clock() < ghostUntil
	if on == ghostShown then
		return
	end
	ghostShown = on
	for _, root in ipairs({ c.Model, player.Character }) do
		for _, d in ipairs(root and root:GetDescendants() or {}) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = on and 0.6 or 0
			end
		end
	end
end

-- Sirene: luz vermelha e azul piscando na moto enquanto dura
local function updateSirenLight(c)
	local on = os.clock() < (player:GetAttribute("SirenUntil") or 0)
	local light = c.Chassis:FindFirstChild("SireneLuz")
	if not on then
		if light then
			light:Destroy()
		end
		return
	end
	if not light then
		light = Instance.new("PointLight")
		light.Name = "SireneLuz"
		light.Range = 22
		light.Brightness = 4
		light.Parent = c.Chassis
	end
	light.Color = (os.clock() * 6) % 2 < 1 and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 110, 255)
end

local function drive(dt: number)
	local c = current
	local baseMax = c.Model:GetAttribute("MaxSpeed") or 16
	local accel = c.Model:GetAttribute("Acceleration") or 18
	local throttle, steer = getInput()
	if player:GetAttribute("PickingAbility") then
		-- escolhendo habilidade: a moto freia sozinha e espera
		throttle = speed > 1 and -1 or 0
		steer = 0
	end

	local resetId = c.Model:GetAttribute("ResetId")
	if resetId ~= c.ResetId then
		c.ResetId = resetId
		speed, lastCommanded = 0, 0
		resetManeuver()
		yaw = yawFromCFrame(c.AO.CFrame)
	end

	setFilter(c)
	local grounded = isGrounded(c)
	lastGrounded = grounded
	updateManeuver(c, dt, grounded)

	-- Nitro de Emergência: turbo automático quando o relógio está acabando (uma vez por pedido)
	if abilities.nitro then
		local deadline = player:GetAttribute("OrderDeadline")
		if deadline and nitroUsedFor ~= deadline then
			local cfg = AbilityConfig.Get("nitro")
			local left = deadline - Workspace:GetServerTimeNow()
			if left > 0 and left <= cfg.TriggerAt then
				nitroUsedFor = deadline
				boostPower = 1
				boostTime = math.max(boostTime, cfg.Duration)
				announce("NITRO!")
			end
		end
	end
	updateGhostLook(c)
	updateSirenLight(c)
	local offRoad = grounded and RoadMap.IsOffRoad(c.Chassis.Position)
	if offRoad ~= lastOffRoad then
		lastOffRoad = offRoad
		player:SetAttribute("OffRoad", offRoad)
	end

	if grounded then
		c.AirForce.Force = Vector3.zero
	else
		c.AirForce.Force = Vector3.new(0, c.Chassis.AssemblyMass * Workspace.Gravity * (1 - MAN.AirGravityScale), 0)
	end

	stunTime = math.max(0, stunTime - dt)
	if stunTime > 0 then
		throttle = 0
	end

	if skidTime > 0 then
		skidTime -= dt
		steer *= 0.15
		throttle *= 0.5
		yaw += skidDrift * dt
	end

	flatImmunity = math.max(0, flatImmunity - dt)
	if flatTime > 0 then
		flatTime -= dt
		throttle = 0
		steer *= 0.3
		if speed > 0 then
			speed = math.max(0, speed - 90 * dt)
		else
			speed = math.min(0, speed + 90 * dt)
		end
		if flatTime <= 0 then
			flatTime = 0
			flatImmunity = MOTO.FlatTireImmunity
			announce("PNEU TROCADO!")
		end
	end

	local boosting = boostTime > 0
	local maxSpeed = baseMax
	if boosting then
		maxSpeed = baseMax * (1 + (MAN.BoostMultiplier - 1) * boostPower)
		accel *= MAN.BoostAccelMultiplier
	end
	if offRoad then
		maxSpeed *= OFFROAD.SpeedFactor
	end

	bumpCooldown -= dt
	local velocity = c.Chassis.AssemblyLinearVelocity
	if bumpCooldown <= 0 and math.abs(lastCommanded) > MOTO.BumpMinSpeed and velocity.Y < 2 then
		local actual = velocity:Dot(lastDirection) * math.sign(lastCommanded)
		if actual < math.abs(lastCommanded) * 0.35 then
			speed = -lastCommanded * MOTO.BumpBounce
			bumpCooldown = 0.4
			shake = math.max(shake, 0.3)
			if grauActive then
				grauActive = false
				needShiftRelease = true
			end
		end
	end

	-- chuva: pista escorregadia (freia e vira menos). Tração Total anula.
	local WEATHER = GameConfig.World.Weather
	local wet = WEATHER and Workspace:GetAttribute("Clima") == "Chuva" and not abilities.grip
	local brakeDecel = MOTO.BrakeDeceleration * (wet and WEATHER.RainBrake or 1)
	if throttle > 0 then
		if speed < 0 then
			speed = math.min(speed + brakeDecel * dt, 0)
		elseif speed < maxSpeed then
			speed = math.min(speed + accel * throttle * dt, maxSpeed)
		end
	elseif throttle < 0 then
		if speed > 0 then
			speed = math.max(speed - brakeDecel * dt, 0)
		else
			speed = math.max(speed + accel * throttle * 0.6 * dt, -baseMax * MOTO.ReverseSpeedFactor)
		end
	else
		if speed > 0 then
			speed = math.max(speed - MOTO.CoastDeceleration * dt, 0)
		elseif speed < 0 then
			speed = math.min(speed + MOTO.CoastDeceleration * dt, 0)
		end
	end
	if speed > maxSpeed then
		local drop = offRoad and MOTO.BrakeDeceleration * 0.7 or MOTO.CoastDeceleration * 2
		speed = math.max(maxSpeed, speed - drop * dt)
	end
	speed = math.max(speed, -baseMax * MOTO.ReverseSpeedFactor)

	local turnFactor = math.clamp(math.abs(speed) / MOTO.FullTurnSpeed, MOTO.MinTurnFactor, 1)
	if grauActive then
		turnFactor *= MAN.GrauTurnFactor
	end
	local reverseSign = speed < -0.5 and -1 or 1
	yaw -= steer * math.rad(MOTO.TurnSpeed) * turnFactor * reverseSign * dt * (wet and WEATHER.RainTurn or 1)
	if knockSpin ~= 0 then
		yaw += knockSpin * dt
		knockSpin *= math.exp(-4 * dt)
		if math.abs(knockSpin) < 0.05 then
			knockSpin = 0
		end
	end

	local targetLean = -steer * math.rad(MOTO.LeanAngle) * math.clamp(math.abs(speed) / baseMax, 0, 1)
	lean += (targetLean - lean) * math.clamp(dt * 8, 0, 1)
	local targetPitch = grauActive and math.rad(MAN.GrauAngle) or 0
	pitch += (targetPitch - pitch) * math.clamp(dt * (grauActive and 6 or 12), 0, 1)

	local rotation = CFrame.Angles(0, yaw, 0)
	local direction = rotation.LookVector
	-- o empurrão de uma batida soma à velocidade e some aos poucos
	if knock ~= Vector3.zero then
		knock *= math.exp(-3.5 * dt)
		if knock.Magnitude < 0.5 then
			knock = Vector3.zero
		end
	end
	c.LV.PlaneVelocity = Vector2.new(direction.X * speed + knock.X, direction.Z * speed + knock.Z)
	local wobble = 0
	if flatTime > 0 then
		wobble = math.sin(os.clock() * 22) * math.rad(5)
	elseif skidTime > 0 then
		wobble = math.sin(os.clock() * 16) * math.rad(9)
	end
	c.AO.CFrame = rotation * CFrame.Angles(pitch, 0, lean + wobble)
	lastCommanded = speed
	lastDirection = direction

	if c.Flame then
		c.Flame.Enabled = boosting
	end
	if c.Tail then
		local braking = (throttle < 0 and speed > -0.5) or (throttle > 0 and speed < -0.5) or flatTime > 0
		if braking ~= c.Braking then
			c.Braking = braking
			c.Tail.Color = braking and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(120, 12, 18)
		end
	end

	local charge = math.floor(turboCharge * 50 + 0.5) / 50
	if charge ~= lastCharge then
		lastCharge = charge
		player:SetAttribute("TurboCharge", charge)
	end
	if boosting ~= lastBoosting then
		lastBoosting = boosting
		player:SetAttribute("Boosting", boosting)
	end
	local flatShown = math.ceil(flatTime * 10) / 10
	if flatShown ~= lastFlat then
		lastFlat = flatShown
		player:SetAttribute("FlatTire", flatShown)
	end
end

local function updateCamera(dt: number)
	local c = current
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	usingCustomCamera = true

	local diff = (yaw - camYaw + math.pi) % (2 * math.pi) - math.pi
	camYaw += diff * math.clamp(1 - math.exp(-CAM.YawSmoothing * dt), 0, 1)

	local focus = c.Chassis.Position + Vector3.new(0, 2.5, 0)
	local rotation = CFrame.Angles(0, camYaw, 0)
	local desired = focus + rotation:VectorToWorldSpace(Vector3.new(0, CAM.Height, CAM.Distance))
	local lookAt = focus + rotation.LookVector * CAM.LookAhead

	local offset = desired - focus
	local hit = Workspace:Raycast(focus, offset, rayParams)
	if hit then
		desired = hit.Position - offset.Unit * 0.8
	end

	if shake > 0 then
		shake = math.max(0, shake - dt * 2)
		local s = shake * 0.8
		desired += Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s)
	end
	camera.CFrame = CFrame.lookAt(desired, lookAt)

	local t = math.clamp(math.abs(speed) / TOP_SPEED, 0, 1)
	local targetFov = CAM.BaseFOV + (CAM.MaxFOV - CAM.BaseFOV) * t + (boostTime > 0 and 10 or 0)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.clamp(dt * 4, 0, 1)
end

local function restoreCamera()
	if not usingCustomCamera then
		return
	end
	usingCustomCamera = false
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = CAM.BaseFOV
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

RunService:BindToRenderStep("MotoController", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if current and not (current.Model.Parent and current.Chassis.Parent) then
		current = nil
	end
	if not current then
		local entry = findMoto()
		if entry then
			bind(entry)
		end
	end

	if touchGui and touchGui.Enabled ~= (current ~= nil) then
		touchGui.Enabled = current ~= nil -- no menu (sem moto) os botões somem
	end
	if current then
		drive(dt)
		updateCamera(dt)
	else
		speed = 0
		restoreCamera()
		if lastOffRoad then
			lastOffRoad = false
			player:SetAttribute("OffRoad", false)
		end
	end

	local display = math.floor(math.abs(speed) * 10 + 0.5) / 10
	if display ~= lastDisplaySpeed then
		lastDisplaySpeed = display
		player:SetAttribute("DisplaySpeed", display)
	end
end)

local wheelState = {}
RunService.RenderStepped:Connect(function(dt)
	for _, moto in ipairs(motosFolder:GetChildren()) do
		local chassis = moto:FindFirstChild("Chassis")
		local vis = moto:FindFirstChild("Visual")
		if chassis and vis then
			local v = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
			for _, name in ipairs({ "frontwheel", "rearwheel" }) do
				local wheel = vis:FindFirstChild(name)
				local weld = wheel and wheel:FindFirstChild("WheelWeld")
				if weld then
					local st = wheelState[weld]
					if not st then
						st = { Base = weld.C0, Angle = 0, R = weld:GetAttribute("Radius") or 1.2 }
						wheelState[weld] = st
						weld.Destroying:Connect(function()
							wheelState[weld] = nil
						end)
					end
					st.Angle = (st.Angle - v / st.R * dt) % (2 * math.pi)
					weld.C0 = CFrame.new(st.Base.Position) * CFrame.Angles(st.Angle, 0, 0) * st.Base.Rotation
				end
			end
		end
	end
end)

-- Personagem: nada de pular (sairia da moto), cair, ragdoll ou escalar
local function onCharacter(character: Model)
	current = nil
	local humanoid = character:WaitForChild("Humanoid")
	for _, state in ipairs({
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
	}) do
		humanoid:SetStateEnabled(state, false)
	end
end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		Remotes.RequestResetMoto:FireServer()
	end
end)

-- Habilidades ativas. Retornam true quando a tecla pertence à habilidade (mesmo em recarga).
useJump = function(): boolean
	if not current or not abilities.jump or not inSurvival() then
		return false
	end
	local now = os.clock()
	if now < jumpReadyAt or not lastGrounded or flatTime > 0 then
		return true
	end
	local cfg = AbilityConfig.Get("jump")
	jumpReadyAt = now + cfg.Cooldown
	player:SetAttribute("JumpReadyAt", jumpReadyAt)
	local v = current.Chassis.AssemblyLinearVelocity
	current.Chassis.AssemblyLinearVelocity = Vector3.new(v.X, cfg.Impulse, v.Z)
	announce("SALTO EXTREMO!")
	impact("jump", 1)
	return true
end

useGhost = function(): boolean
	if not current or not abilities.ghost or not inSurvival() then
		return false
	end
	local now = os.clock()
	if now < ghostReadyAt then
		return true
	end
	local cfg = AbilityConfig.Get("ghost")
	ghostUntil = now + cfg.Duration
	ghostReadyAt = now + cfg.Cooldown
	player:SetAttribute("GhostUntil", ghostUntil)
	player:SetAttribute("GhostReadyAt", ghostReadyAt)
	announce("MODO FANTASMA!")
	impact("ghost", 1)
	return true
end

useSiren = function(): boolean
	if not current or not abilities.siren or not inSurvival() then
		return false
	end
	local now = os.clock()
	if now < sirenReadyAt then
		return true
	end
	local cfg = AbilityConfig.Get("siren")
	sirenReadyAt = now + cfg.Cooldown
	player:SetAttribute("SirenUntil", now + cfg.Duration)
	player:SetAttribute("SirenReadyAt", sirenReadyAt)
	announce("SIRENE!")
	impact("siren", 1)
	return true
end

useSlow = function(): boolean
	if not current or not abilities.slowmo or not inSurvival() then
		return false
	end
	local now = os.clock()
	if now < slowReadyAt then
		return true
	end
	local cfg = AbilityConfig.Get("slowmo")
	slowReadyAt = now + cfg.Cooldown
	player:SetAttribute("SlowUntil", now + cfg.Duration)
	player:SetAttribute("SlowReadyAt", slowReadyAt)
	announce("CÂMERA LENTA!")
	impact("slowmo", 1)
	return true
end

-- Saída Rápida: turbo quando um pedido começa e quando a comida é coletada
local function launchBoost(order)
	if current and abilities.launch and type(order) == "table" and order.Survival then
		boostPower = 1
		boostTime = math.max(boostTime, AbilityConfig.Get("launch").Duration)
		announce("SAÍDA RÁPIDA!")
	end
end
Remotes.OrderAccepted.OnClientEvent:Connect(launchBoost)
Remotes.OrderPickedUp.OnClientEvent:Connect(launchBoost)

local function bindAbility(name: string, fire, ...)
	ContextActionService:BindActionAtPriority(name, function(_, state)
		-- escolhendo carta: os botões do controle (X/Y/B) são da tela de habilidades
		if state ~= Enum.UserInputState.Begin or player:GetAttribute("PickingAbility") then
			return Enum.ContextActionResult.Pass
		end
		return fire() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, ...)
end
bindAbility("MotoSalto", useJump, Enum.KeyCode.Space, Enum.KeyCode.ButtonY)
bindAbility("MotoFantasma", useGhost, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
bindAbility("MotoSirene", useSiren, Enum.KeyCode.Q, Enum.KeyCode.ButtonR1)
bindAbility("MotoCameraLenta", useSlow, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
