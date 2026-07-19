local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local debugConfig = combatConfig.Debug or {}

if not RunService:IsStudio() or debugConfig.EnableStudioEnemySpawner ~= true then
	return
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local spawnEvent = ReplicatedStorage:WaitForChild("DebugEnemySpawnEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "DebugEnemySpawnerGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -18, 0, 190)
frame.Size = UDim2.fromOffset(254, 142)
frame.BackgroundColor3 = Color3.fromRGB(22, 25, 29)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "STUDIO MOB LOAD TEST"
title.TextColor3 = Color3.fromRGB(245, 196, 80)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local aliveLabel = Instance.new("TextLabel")
aliveLabel.Name = "AliveLabel"
aliveLabel.Position = UDim2.fromOffset(12, 34)
aliveLabel.Size = UDim2.new(1, -24, 0, 22)
aliveLabel.BackgroundTransparency = 1
aliveLabel.Font = Enum.Font.Gotham
aliveLabel.TextColor3 = Color3.fromRGB(220, 225, 230)
aliveLabel.TextSize = 14
aliveLabel.TextXAlignment = Enum.TextXAlignment.Left
aliveLabel.Parent = frame

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.Position = UDim2.fromOffset(12, 62)
buttonRow.Size = UDim2.new(1, -24, 0, 34)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = frame

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 7)
buttonLayout.Parent = buttonRow

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Position = UDim2.fromOffset(12, 102)
statusLabel.Size = UDim2.new(1, -24, 0, 28)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Adds moving Walkers. Studio damage protection is on."
statusLabel.TextColor3 = Color3.fromRGB(158, 168, 178)
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.Parent = frame

local function refreshAliveCount()
	local alive = math.max(0, math.floor(tonumber(Workspace:GetAttribute("AliveZombies")) or 0))
	aliveLabel.Text = ("Wave-tracked alive: %d"):format(alive)
end

local function createSpawnButton(count)
	local button = Instance.new("TextButton")
	button.Name = "Spawn" .. count
	button.Size = UDim2.fromOffset(72, 34)
	button.BackgroundColor3 = Color3.fromRGB(56, 112, 82)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = ("Spawn %d"):format(count)
	button.TextColor3 = Color3.fromRGB(245, 248, 246)
	button.TextSize = 13
	button.Parent = buttonRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		statusLabel.Text = ("Requesting %d mobs..."):format(count)
		spawnEvent:FireServer(count)
	end)
end

for _, count in ipairs({ 1, 10, 100 }) do
	createSpawnButton(count)
end

spawnEvent.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end

	statusLabel.Text = ("Spawned %d / %d mobs."):format(
		math.max(0, math.floor(tonumber(result.spawned) or 0)),
		math.max(0, math.floor(tonumber(result.requested) or 0))
	)
end)

Workspace:GetAttributeChangedSignal("AliveZombies"):Connect(refreshAliveCount)
refreshAliveCount()
