local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local debugConfig = combatConfig.Debug or {}

local spawnerAuthorized = RunService:IsStudio() and debugConfig.EnableStudioEnemySpawner == true
if not spawnerAuthorized and debugConfig.EnablePublishedEnemySpawner == true then
	for _, userId in ipairs(debugConfig.EnemySpawnerAuthorizedUserIds or {}) do
		if tonumber(userId) == Players.LocalPlayer.UserId then
			spawnerAuthorized = true
			break
		end
	end
end

if not spawnerAuthorized then
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
frame.Size = UDim2.fromOffset(254, 310)
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
title.Text = "MOB LOAD TEST"
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

local rosterRow = Instance.new("Frame")
rosterRow.Name = "RosterRow"
rosterRow.Position = UDim2.fromOffset(12, 102)
rosterRow.Size = UDim2.new(1, -24, 0, 34)
rosterRow.BackgroundTransparency = 1
rosterRow.Parent = frame

local bossLabel = Instance.new("TextLabel")
bossLabel.Name = "BossLabel"
bossLabel.Position = UDim2.fromOffset(12, 142)
bossLabel.Size = UDim2.new(1, -24, 0, 18)
bossLabel.BackgroundTransparency = 1
bossLabel.Font = Enum.Font.GothamBold
bossLabel.Text = "BOSS ABILITY PREVIEWS"
bossLabel.TextColor3 = Color3.fromRGB(232, 166, 116)
bossLabel.TextSize = 12
bossLabel.TextXAlignment = Enum.TextXAlignment.Left
bossLabel.Parent = frame

local bossRowOne = Instance.new("Frame")
bossRowOne.Name = "BossRowOne"
bossRowOne.Position = UDim2.fromOffset(12, 166)
bossRowOne.Size = UDim2.new(1, -24, 0, 34)
bossRowOne.BackgroundTransparency = 1
bossRowOne.Parent = frame

local bossRowTwo = bossRowOne:Clone()
bossRowTwo.Name = "BossRowTwo"
bossRowTwo.Position = UDim2.fromOffset(12, 206)
bossRowTwo.Parent = frame

for _, row in ipairs({ bossRowOne, bossRowTwo }) do
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Position = UDim2.fromOffset(12, 250)
statusLabel.Size = UDim2.new(1, -24, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Adds moving roster mobs. Test damage protection is on."
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

local function createPreviewButton(label, variantKey, color, parent, width)
	local button = Instance.new("TextButton")
	button.Name = "Preview" .. variantKey
	button.Size = UDim2.fromOffset(width or 72, 34)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = label
	button.TextColor3 = Color3.fromRGB(245, 248, 246)
	button.TextSize = 12
	button.Parent = parent or rosterRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button
	button.MouseButton1Click:Connect(function()
		statusLabel.Text = ("Requesting %s preview..."):format(label)
		spawnEvent:FireServer({ count = 1, variant = variantKey })
	end)
end

local mobPreviewOrder = combatConfig.Zombies.DebugMobPreviewOrder or {}
local mobPreviewIndex = 0
local nextMobButton = Instance.new("TextButton")
nextMobButton.Name = "NextRosterMob"
nextMobButton.Size = UDim2.fromOffset(230, 34)
nextMobButton.BackgroundColor3 = Color3.fromRGB(45, 105, 118)
nextMobButton.BorderSizePixel = 0
nextMobButton.Font = Enum.Font.GothamBold
nextMobButton.Text = ("Next roster mob (0/%d)"):format(#mobPreviewOrder)
nextMobButton.TextColor3 = Color3.fromRGB(245, 248, 246)
nextMobButton.TextSize = 12
nextMobButton.Parent = rosterRow
local nextMobCorner = Instance.new("UICorner")
nextMobCorner.CornerRadius = UDim.new(0, 7)
nextMobCorner.Parent = nextMobButton
nextMobButton.MouseButton1Click:Connect(function()
	if #mobPreviewOrder == 0 then
		statusLabel.Text = "No roster preview variants configured."
		return
	end
	mobPreviewIndex = (mobPreviewIndex % #mobPreviewOrder) + 1
	local variantKey = mobPreviewOrder[mobPreviewIndex]
	local variant = combatConfig.Zombies.Variants[variantKey] or {}
	local displayName = variant.DisplayName or variantKey
	nextMobButton.Text = ("Next: %s (%d/%d)"):format(displayName, mobPreviewIndex, #mobPreviewOrder)
	statusLabel.Text = ("Requesting %s preview..."):format(displayName)
	spawnEvent:FireServer({ count = 1, variant = variantKey })
end)

createPreviewButton("Stone Titan", "BossStoneTitan", Color3.fromRGB(123, 103, 78), bossRowOne, 111)
createPreviewButton("Storm", "BossStormColossus", Color3.fromRGB(55, 120, 166), bossRowOne, 111)
createPreviewButton("Flame", "BossFlameWarden", Color3.fromRGB(174, 73, 35), bossRowTwo, 111)
createPreviewButton("Brood Queen", "BossBroodQueen", Color3.fromRGB(121, 55, 131), bossRowTwo, 111)

spawnEvent.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then
		return
	end

	statusLabel.Text = ("Spawned %d / %d %s."):format(
		math.max(0, math.floor(tonumber(result.spawned) or 0)),
		math.max(0, math.floor(tonumber(result.requested) or 0)),
		tostring(result.variant or "Needleling")
	)
end)

Workspace:GetAttributeChangedSignal("AliveZombies"):Connect(refreshAliveCount)
refreshAliveCount()
