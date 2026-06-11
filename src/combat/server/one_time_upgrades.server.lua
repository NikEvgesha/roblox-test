local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local upgradeConfig = combatConfig.OneTimeUpgrades or {}
local progressionConfig = combatConfig.Progression or {}
local skillConfig = progressionConfig.Skills or {}

local SURVIVAL_EVENT_NAME = "SurvivalEvent"

local function ensureRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then
		return event
	end

	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local survivalEvent = ensureRemoteEvent(SURVIVAL_EVENT_NAME)

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureIntValue(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end

	value = Instance.new("IntValue")
	value.Name = name
	value.Value = defaultValue
	value.Parent = parent
	return value
end

local function getVector3FromArray(value, fallback)
	if type(value) ~= "table" then
		return fallback
	end

	return Vector3.new(
		tonumber(value[1]) or fallback.X,
		tonumber(value[2]) or fallback.Y,
		tonumber(value[3]) or fallback.Z
	)
end

local function getColorFromArray(value, fallback)
	if type(value) ~= "table" then
		return fallback
	end

	return Color3.fromRGB(
		tonumber(value[1]) or math.floor(fallback.R * 255 + 0.5),
		tonumber(value[2]) or math.floor(fallback.G * 255 + 0.5),
		tonumber(value[3]) or math.floor(fallback.B * 255 + 0.5)
	)
end

local function sendMessage(player, text)
	survivalEvent:FireClient(player, {
		type = "match",
		text = text,
	})
end

local function getMoneyValue(player)
	local leaderstats = ensureFolder(player, "leaderstats")
	return ensureIntValue(leaderstats, "Money", 0)
end

local function getProgression(player)
	local progression = ensureFolder(player, "Progression")
	ensureIntValue(progression, "RangedLevel", 0)
	ensureIntValue(progression, "MeleeLevel", 0)
	return progression
end

local function getRunUpgradeFlags(player)
	return ensureFolder(player, "RunOneTimeUpgrades")
end

local function hasPurchased(player, upgradeKey)
	local flags = getRunUpgradeFlags(player)
	local flag = flags:FindFirstChild(upgradeKey)
	return flag and flag:IsA("BoolValue") and flag.Value == true
end

local function markPurchased(player, upgradeKey)
	local flags = getRunUpgradeFlags(player)
	local flag = flags:FindFirstChild(upgradeKey)
	if not (flag and flag:IsA("BoolValue")) then
		flag = Instance.new("BoolValue")
		flag.Name = upgradeKey
		flag.Parent = flags
	end
	flag.Value = true
end

local function addSkillLevels(progression, statName, amount, maxLevel)
	if amount == 0 then
		return 0
	end

	local value = ensureIntValue(progression, statName, 0)
	local before = value.Value
	value.Value = math.clamp(before + amount, 0, maxLevel)
	return value.Value - before
end

local function applyUpgrade(player, upgradeKey, config)
	if hasPurchased(player, upgradeKey) then
		sendMessage(player, ("%s already purchased this run."):format(config.DisplayName or upgradeKey))
		return
	end

	local cost = math.max(0, math.floor(tonumber(config.Cost) or 0))
	local money = getMoneyValue(player)
	if money.Value < cost then
		sendMessage(player, ("Need $%d for %s."):format(cost, config.DisplayName or upgradeKey))
		return
	end

	local progression = getProgression(player)
	local rangedMax = math.max(0, math.floor(tonumber((skillConfig.RangedDamage or {}).MaxLevel) or 8))
	local meleeMax = math.max(0, math.floor(tonumber((skillConfig.MeleeDamage or {}).MaxLevel) or 8))
	local rangedAdded = addSkillLevels(progression, "RangedLevel", math.floor(tonumber(config.RangedLevels) or 0), rangedMax)
	local meleeAdded = addSkillLevels(progression, "MeleeLevel", math.floor(tonumber(config.MeleeLevels) or 0), meleeMax)

	if rangedAdded <= 0 and meleeAdded <= 0 then
		sendMessage(player, ("%s has no remaining effect."):format(config.DisplayName or upgradeKey))
		return
	end

	money.Value -= cost
	markPurchased(player, upgradeKey)
	sendMessage(
		player,
		("%s purchased: +%d ranged, +%d melee damage levels."):format(
			config.DisplayName or upgradeKey,
			rangedAdded,
			meleeAdded
		)
	)
end

local function createShrine(upgradeKey, config, parent)
	local shrine = parent:FindFirstChild(upgradeKey)
	if shrine and shrine:IsA("BasePart") then
		return shrine
	end

	shrine = Instance.new("Part")
	shrine.Name = upgradeKey
	shrine.Anchored = true
	shrine.CanCollide = true
	shrine.Material = Enum.Material.Neon
	shrine.Color = getColorFromArray(config.Color, Color3.fromRGB(255, 200, 90))
	shrine.Size = getVector3FromArray(config.Size, Vector3.new(7, 5, 7))
	shrine.Position = getVector3FromArray(config.Position, Vector3.new(36, 2, -24))
	shrine.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OneTimeUpgradePrompt"
	prompt.ActionText = config.PromptText or "Buy upgrade"
	prompt.ObjectText = ("%s ($%d)"):format(config.DisplayName or upgradeKey, math.max(0, math.floor(tonumber(config.Cost) or 0)))
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = shrine

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShrineLabel"
	billboard.Size = UDim2.fromOffset(220, 54)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = shrine

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 18, 12)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 236, 174)
	label.TextSize = 14
	label.TextWrapped = true
	label.Text = ("%s\nOne-time run boost"):format(config.DisplayName or upgradeKey)
	label.Parent = billboard

	prompt.Triggered:Connect(function(player)
		applyUpgrade(player, upgradeKey, config)
	end)

	return shrine
end

if upgradeConfig.Enabled ~= false then
	local folderName = tostring(upgradeConfig.FolderName or "OneTimeUpgrades")
	local folder = ensureFolder(Workspace, folderName)

	for upgradeKey, config in pairs(upgradeConfig.Upgrades or {}) do
		if type(config) == "table" then
			createShrine(tostring(upgradeKey), config, folder)
		end
	end
end
