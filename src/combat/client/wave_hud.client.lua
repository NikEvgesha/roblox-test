local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local zombieConfig = combatConfig.Zombies or {}

local targetWaveCount = math.max(1, math.floor(tonumber(zombieConfig.TargetWaveCount) or 10))

local gui = Instance.new("ScreenGui")
gui.Name = "WaveHudGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "WaveHud"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.new(0.5, 0, 0, 96)
root.Size = UDim2.fromOffset(430, 66)
root.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
root.BackgroundTransparency = 0.18
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = root

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(72, 86, 104)
stroke.Transparency = 0.3
stroke.Thickness = 1
stroke.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -28, 0, 22)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(240, 244, 248)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Wave 0/10"
title.Parent = root

local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.BackgroundTransparency = 1
detail.Position = UDim2.fromOffset(14, 34)
detail.Size = UDim2.new(1, -28, 0, 22)
detail.Font = Enum.Font.Gotham
detail.TextColor3 = Color3.fromRGB(195, 204, 214)
detail.TextSize = 13
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.Text = "State: PreRun"
detail.Parent = root

local function getNumberAttribute(name, fallback)
	local value = Workspace:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function getStringAttribute(name, fallback)
	local value = Workspace:GetAttribute(name)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return fallback
end

local function render()
	local waveNumber = math.max(0, math.floor(getNumberAttribute("WaveNumber", 0)))
	local waveState = getStringAttribute("WaveState", "PreRun")
	local difficulty = getStringAttribute("SelectedDifficulty", getStringAttribute("Difficulty", "Medium"))
	local isBossWave = Workspace:GetAttribute("IsBossWave") == true
	local budget = math.max(0, math.floor(getNumberAttribute("WaveBudget", 0)))
	local spawnsRemaining = math.max(0, math.floor(getNumberAttribute("WaveSpawnsRemaining", 0)))
	local aliveZombies = math.max(0, math.floor(getNumberAttribute("AliveZombies", 0)))
	local aliveCap = math.max(0, math.floor(getNumberAttribute("AliveCap", 0)))
	local bossSpawnsRemaining = math.max(0, math.floor(getNumberAttribute("WaveBossSpawnsRemaining", 0)))

	title.Text = ("Wave %d/%d | %s%s"):format(waveNumber, targetWaveCount, difficulty, isBossWave and " | BOSS" or "")

	if waveState == "WaveActive" or waveState == "BossWaveActive" then
		detail.Text = ("Enemies: %d alive, %d spawn left / %d total | cap %d | boss left %d")
			:format(aliveZombies, spawnsRemaining, budget, aliveCap, bossSpawnsRemaining)
	elseif waveState == "Intermission" then
		detail.Text = "Intermission: buy upgrades and reposition."
	elseif waveState == "RunResult" then
		detail.Text = "Run result: returning to lobby or restarting."
	elseif waveState == "WipeWindow" then
		detail.Text = "Team wipe: revive window active."
	else
		detail.Text = ("State: %s"):format(waveState)
	end

	if isBossWave then
		stroke.Color = Color3.fromRGB(255, 163, 58)
		title.TextColor3 = Color3.fromRGB(255, 224, 168)
	else
		stroke.Color = Color3.fromRGB(72, 86, 104)
		title.TextColor3 = Color3.fromRGB(240, 244, 248)
	end
end

local observedAttributes = {
	"WaveNumber",
	"WaveState",
	"IsBossWave",
	"SelectedDifficulty",
	"Difficulty",
	"WaveBudget",
	"WaveSpawnsRemaining",
	"WaveBossSpawnsRemaining",
	"AliveZombies",
	"AliveCap",
}

for _, attributeName in ipairs(observedAttributes) do
	Workspace:GetAttributeChangedSignal(attributeName):Connect(render)
end

render()
