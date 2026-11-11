-- Placar ao vivo da Sobrevivência: quem está jogando agora no servidor e quantas entregas tem na partida.
-- Só aparece com 2+ jogadores na Sobrevivência (sozinho não ocupa a tela). Lê atributos que o servidor já replica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent
local UI = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIKit"))
local C, F, new = UI.Color, UI.Font, UI.new

local TOUCH = UI.IsTouch()
local M, W, ROW, HEAD = 16, 180, 26, 34
local MAX_ROWS = 5

for _, c in ipairs(gui:GetChildren()) do
	if c:IsA("GuiObject") or c:IsA("UIScale") then
		c:Destroy()
	end
end
local uiScale = new("UIScale", { Parent = gui })

local holder, face = UI.Panel({ Name = "Placar", Size = UDim2.fromOffset(W, HEAD), Position = UDim2.fromOffset(M, M + 50 + 12), Parent = gui })
local dot = new("Frame", {
	Name = "AoVivo", BackgroundColor3 = C.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(14, 13), ZIndex = 2, Parent = face,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
UI.Text({ Text = "AO VIVO NO SERVIDOR", Font = F.Title, TextSize = 14, Transparency = UI.Muted, Position = UDim2.fromOffset(30, 7), Size = UDim2.new(1, -40, 0, 20), Parent = face })

local rows = {}
for i = 1, MAX_ROWS + 1 do
	local y = HEAD + (i - 1) * ROW
	local pos = UI.Text({ Font = F.Number, TextSize = 15, Transparency = UI.Muted, Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(22, ROW), Parent = face })
	local name = UI.Text({ Font = F.Text, TextSize = 15, Truncate = true, Position = UDim2.fromOffset(36, y), Size = UDim2.new(1, -86, 0, ROW), Parent = face })
	local count = UI.Text({ Font = F.Number, TextSize = 17, XAlign = Enum.TextXAlignment.Right, Position = UDim2.new(1, -46, 0, y), Size = UDim2.fromOffset(34, ROW), Parent = face })
	rows[i] = { Pos = pos, Name = name, Count = count }
end

local function playing(p: Player): boolean
	return p:GetAttribute("GameMode") == "Survival"
end

local function layout()
	uiScale.Scale = UI.ScaleFor(Workspace.CurrentCamera.ViewportSize, TOUCH)
	-- no toque a barra de habilidades fica embaixo da carteira: o placar desce junto
	local shift = (TOUCH and player:GetAttribute("Abilities")) and 120 or 0
	holder.Position = UDim2.fromOffset(M, M + 50 + 12 + shift)
end

local function refresh()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if playing(p) then
			table.insert(list, p)
		end
	end
	local show = playing(player) and #list >= (gui:GetAttribute("MinJogadores") or 2)
	gui.Enabled = show
	if not show then
		return
	end
	table.sort(list, function(a, b)
		local da, db = a:GetAttribute("SurvivalDeliveries") or 0, b:GetAttribute("SurvivalDeliveries") or 0
		if da ~= db then
			return da > db
		end
		return a.UserId < b.UserId
	end)
	-- os 5 primeiros e, se eu estiver fora deles, a minha linha no fim
	local shown, mine = {}, nil
	for i, p in ipairs(list) do
		if p == player then
			mine = i
		end
		if i <= MAX_ROWS then
			table.insert(shown, { i, p })
		end
	end
	if mine and mine > MAX_ROWS then
		table.insert(shown, { mine, player })
	end
	for i, row in ipairs(rows) do
		local entry = shown[i]
		local visible = entry ~= nil
		row.Pos.Visible, row.Name.Visible, row.Count.Visible = visible, visible, visible
		if visible then
			local rank, p = entry[1], entry[2]
			local me = p == player
			row.Pos.Text = tostring(rank)
			row.Name.Text = p.DisplayName
			row.Count.Text = tostring(p:GetAttribute("SurvivalDeliveries") or 0)
			row.Name.TextColor3 = me and C.Accent or C.Text
			row.Count.TextColor3 = me and C.Accent or C.Text
		end
	end
	holder.Size = UDim2.fromOffset(W, HEAD + #shown * ROW + 8)
	layout()
end

-- várias mudanças no mesmo quadro viram uma atualização só
local pending = false
local function schedule()
	if not pending then
		pending = true
		task.defer(function()
			pending = false
			refresh()
		end)
	end
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("GameMode"):Connect(schedule)
	p:GetAttributeChangedSignal("SurvivalDeliveries"):Connect(schedule)
	schedule()
end
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(schedule)
player:GetAttributeChangedSignal("Abilities"):Connect(layout)
gui:GetAttributeChangedSignal("MinJogadores"):Connect(schedule)
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
layout()
