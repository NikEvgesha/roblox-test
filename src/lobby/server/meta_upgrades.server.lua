local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local META_EVENT_NAME = "LobbyMetaEvent"

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local profileStore = require(sharedFolder:WaitForChild("ProfileStore"))

local metaConfig = combatConfig.MetaProgression or {}
local upgradesConfig = metaConfig.Upgrades or {}
local upgradeOrder = metaConfig.UpgradeOrder or { "Damage", "Health", "Speed" }

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

local metaEvent = ensureRemoteEvent(META_EVENT_NAME)

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

local function ensureCrystalsStat(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	return ensureIntValue(leaderstats, "Crystals", 0)
end

local function ensureMetaProgressionFolder(player)
	local folder = player:FindFirstChild("MetaProgression")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MetaProgression"
		folder.Parent = player
	end

	for _, upgradeKey in ipairs(upgradeOrder) do
		ensureIntValue(folder, upgradeKey, 0)
	end

	return folder
end

local function getUpgradeCost(upgradeKey, level)
	local config = upgradesConfig[upgradeKey] or {}
	local baseCost = math.max(1, math.floor(tonumber(config.BaseCost) or 1))
	local costStep = math.max(0, math.floor(tonumber(config.CostStep) or 0))
	return baseCost + math.max(0, level) * costStep
end

local function buildStatePayload(player, message)
	local crystals = ensureCrystalsStat(player)
	local metaFolder = ensureMetaProgressionFolder(player)
	local upgrades = {}

	for _, upgradeKey in ipairs(upgradeOrder) do
		local config = upgradesConfig[upgradeKey] or {}
		local value = ensureIntValue(metaFolder, upgradeKey, 0)
		local level = math.max(0, value.Value)
		local maxLevel = math.max(1, math.floor(tonumber(config.MaxLevel) or 1))
		local nextCost = 0
		if level < maxLevel then
			nextCost = getUpgradeCost(upgradeKey, level)
		end

		table.insert(upgrades, {
			key = upgradeKey,
			displayName = config.DisplayName or upgradeKey,
			level = level,
			maxLevel = maxLevel,
			nextCost = nextCost,
		})
	end

	return {
		type = "state",
		crystals = crystals.Value,
		upgrades = upgrades,
		message = message or "",
	}
end

local function sendState(player, message)
	metaEvent:FireClient(player, buildStatePayload(player, message))
end

local function tryUpgrade(player, upgradeKey)
	local config = upgradesConfig[upgradeKey]
	if not config then
		return "Unknown upgrade."
	end

	local crystals = ensureCrystalsStat(player)
	local metaFolder = ensureMetaProgressionFolder(player)
	local value = ensureIntValue(metaFolder, upgradeKey, 0)
	local level = math.max(0, value.Value)
	local maxLevel = math.max(1, math.floor(tonumber(config.MaxLevel) or 1))
	if level >= maxLevel then
		return "Upgrade is already maxed."
	end

	local cost = getUpgradeCost(upgradeKey, level)
	if crystals.Value < cost then
		return ("Need %d crystals."):format(cost)
	end

	crystals.Value -= cost
	value.Value = level + 1
	profileStore.MarkDirty(player)
	return ("%s upgraded to %d."):format(config.DisplayName or upgradeKey, value.Value)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		sendState(player, "")
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		sendState(player, "")
	end)
end

metaEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "open" or action == "refresh" then
		sendState(player, "")
		return
	end

	if action == "upgrade" then
		local upgradeKey = tostring(payload or "")
		local resultMessage = tryUpgrade(player, upgradeKey)
		sendState(player, resultMessage)
	end
end)
