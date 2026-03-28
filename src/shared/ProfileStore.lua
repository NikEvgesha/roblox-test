local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local combatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local metaConfig = combatConfig.MetaProgression or {}
local upgradesConfig = metaConfig.Upgrades or {}
local upgradeOrder = metaConfig.UpgradeOrder or { "Damage", "Health", "Speed" }
local classesConfig = combatConfig.Classes or {}
local classDefinitions = classesConfig.Definitions or {}
local classOrder = classesConfig.Order or { "Assault", "Builder", "Healer", "Melee" }

local STORE_NAME = tostring(metaConfig.DataStoreName or "HeroicSurvivalProfile_v1")
local AUTO_SAVE_INTERVAL = math.max(30, math.floor(tonumber(metaConfig.AutoSaveIntervalSeconds) or 90))

local profileStore = DataStoreService:GetDataStore(STORE_NAME)

local ProfileStore = {}

local dirtyByUserId = {}
local loadedByUserId = {}
local saveInFlight = {}
local connectionsByUserId = {}
local autoSaveStarted = false
local persistenceDisabled = false
local persistenceDisabledReason = nil

local function shouldDisablePersistence(errorMessage)
	local text = string.lower(tostring(errorMessage or ""))
	if string.find(text, "studio access to api services is not enabled", 1, true) then
		return true
	end
	if string.find(text, "studio access to apis is not allowed", 1, true) then
		return true
	end
	if string.find(text, "403", 1, true) then
		return true
	end
	if string.find(text, "forbidden", 1, true) then
		return true
	end
	return false
end

local function resolveDefaultClassKey()
	local requested = classesConfig.DefaultClass
	if type(requested) == "string" and classDefinitions[requested] then
		return requested
	end

	for _, classKey in ipairs(classOrder) do
		if classDefinitions[classKey] then
			return classKey
		end
	end

	for classKey in pairs(classDefinitions) do
		return classKey
	end

	return "Assault"
end

local DEFAULT_CLASS_KEY = resolveDefaultClassKey()

local function normalizeClassKey(classKey)
	if type(classKey) == "string" and classDefinitions[classKey] then
		return classKey
	end
	return DEFAULT_CLASS_KEY
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

local function ensureStringValue(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)
	if value and value:IsA("StringValue") then
		return value
	end

	value = Instance.new("StringValue")
	value.Name = name
	value.Value = defaultValue
	value.Parent = parent
	return value
end

local function clampUpgradeLevel(upgradeKey, level)
	local config = upgradesConfig[upgradeKey] or {}
	local maxLevel = math.max(0, math.floor(tonumber(config.MaxLevel) or 0))
	return math.clamp(math.floor(tonumber(level) or 0), 0, maxLevel)
end

local function buildDefaultProfile()
	local upgrades = {}
	for _, upgradeKey in ipairs(upgradeOrder) do
		upgrades[upgradeKey] = 0
	end

	return {
		version = 1,
		crystals = 0,
		selectedClass = DEFAULT_CLASS_KEY,
		upgrades = upgrades,
		updatedAt = os.time(),
	}
end

local function normalizeProfile(raw)
	local normalized = buildDefaultProfile()
	if type(raw) ~= "table" then
		return normalized
	end

	normalized.version = math.max(1, math.floor(tonumber(raw.version) or 1))
	normalized.crystals = math.max(0, math.floor(tonumber(raw.crystals) or 0))
	normalized.selectedClass = normalizeClassKey(raw.selectedClass)

	if type(raw.upgrades) == "table" then
		for _, upgradeKey in ipairs(upgradeOrder) do
			normalized.upgrades[upgradeKey] = clampUpgradeLevel(upgradeKey, raw.upgrades[upgradeKey])
		end
	end

	normalized.updatedAt = math.floor(tonumber(raw.updatedAt) or os.time())
	return normalized
end

local function ensureContainers(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local progression = player:FindFirstChild("Progression")
	if not progression then
		progression = Instance.new("Folder")
		progression.Name = "Progression"
		progression.Parent = player
	end

	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression then
		metaProgression = Instance.new("Folder")
		metaProgression.Name = "MetaProgression"
		metaProgression.Parent = player
	end

	local money = ensureIntValue(leaderstats, "Money", 0)
	local xp = ensureIntValue(leaderstats, "XP", 0)
	local level = ensureIntValue(leaderstats, "Level", 1)
	local crystals = ensureIntValue(leaderstats, "Crystals", 0)

	local skillPoints = ensureIntValue(progression, "SkillPoints", 0)
	local speedLevel = ensureIntValue(progression, "SpeedLevel", 0)
	local meleeLevel = ensureIntValue(progression, "MeleeLevel", 0)
	local rangedLevel = ensureIntValue(progression, "RangedLevel", 0)
	local healthLevel = ensureIntValue(progression, "HealthLevel", 0)

	local upgradeValues = {}
	for _, upgradeKey in ipairs(upgradeOrder) do
		upgradeValues[upgradeKey] = ensureIntValue(metaProgression, upgradeKey, 0)
	end
	local selectedClass = ensureStringValue(metaProgression, "SelectedClass", DEFAULT_CLASS_KEY)

	return {
		leaderstats = leaderstats,
		progression = progression,
		metaProgression = metaProgression,
		money = money,
		xp = xp,
		level = level,
		crystals = crystals,
		skillPoints = skillPoints,
		speedLevel = speedLevel,
		meleeLevel = meleeLevel,
		rangedLevel = rangedLevel,
		healthLevel = healthLevel,
		upgrades = upgradeValues,
		selectedClass = selectedClass,
	}
end

local function disconnectUserConnections(userId)
	local list = connectionsByUserId[userId]
	if not list then
		return
	end

	for _, connection in ipairs(list) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	connectionsByUserId[userId] = nil
end

local function bindDirtySignals(player, containers)
	disconnectUserConnections(player.UserId)

	local connections = {}
	table.insert(connections, containers.crystals:GetPropertyChangedSignal("Value"):Connect(function()
		dirtyByUserId[player.UserId] = true
	end))

	for _, value in pairs(containers.upgrades) do
		table.insert(connections, value:GetPropertyChangedSignal("Value"):Connect(function()
			dirtyByUserId[player.UserId] = true
		end))
	end
	table.insert(connections, containers.selectedClass:GetPropertyChangedSignal("Value"):Connect(function()
		local normalized = normalizeClassKey(containers.selectedClass.Value)
		if normalized ~= containers.selectedClass.Value then
			containers.selectedClass.Value = normalized
			return
		end
		player:SetAttribute("SelectedClass", normalized)
		dirtyByUserId[player.UserId] = true
	end))

	connectionsByUserId[player.UserId] = connections
end

local function getProfileKey(userId)
	return ("u_%d"):format(userId)
end

function ProfileStore.EnsureContainers(player)
	return ensureContainers(player)
end

function ProfileStore.Load(player)
	local containers = ensureContainers(player)

	containers.money.Value = 0
	containers.xp.Value = 0
	containers.level.Value = 1
	containers.skillPoints.Value = 0
	containers.speedLevel.Value = 0
	containers.meleeLevel.Value = 0
	containers.rangedLevel.Value = 0
	containers.healthLevel.Value = 0

	local profile = buildDefaultProfile()
	local key = getProfileKey(player.UserId)

	if not persistenceDisabled then
		local ok, result = pcall(function()
			return profileStore:GetAsync(key)
		end)

		if ok then
			profile = normalizeProfile(result)
		else
			warn("[ProfileStore] GetAsync failed:", result)
			if shouldDisablePersistence(result) then
				persistenceDisabled = true
				persistenceDisabledReason = tostring(result)
				warn("[ProfileStore] Persistence disabled for this server:", persistenceDisabledReason)
			end
		end
	end

	containers.crystals.Value = profile.crystals
	containers.selectedClass.Value = normalizeClassKey(profile.selectedClass)
	player:SetAttribute("SelectedClass", containers.selectedClass.Value)
	for upgradeKey, value in pairs(containers.upgrades) do
		value.Value = profile.upgrades[upgradeKey] or 0
	end

	loadedByUserId[player.UserId] = true
	dirtyByUserId[player.UserId] = false
	bindDirtySignals(player, containers)
	player:SetAttribute("PersistentProfileLoaded", true)

	return profile
end

function ProfileStore.Capture(player)
	local containers = ensureContainers(player)
	local profile = buildDefaultProfile()
	profile.crystals = math.max(0, containers.crystals.Value)
	profile.selectedClass = normalizeClassKey(containers.selectedClass.Value)

	for upgradeKey, value in pairs(containers.upgrades) do
		profile.upgrades[upgradeKey] = clampUpgradeLevel(upgradeKey, value.Value)
	end

	profile.updatedAt = os.time()
	return profile
end

function ProfileStore.MarkDirty(player)
	if player and loadedByUserId[player.UserId] then
		dirtyByUserId[player.UserId] = true
	end
end

function ProfileStore.Save(player, force)
	if not player then
		return false
	end

	local userId = player.UserId
	if not loadedByUserId[userId] then
		return false
	end

	if persistenceDisabled then
		dirtyByUserId[userId] = false
		return false
	end

	if not force and not dirtyByUserId[userId] then
		return true
	end

	if saveInFlight[userId] then
		return false
	end

	saveInFlight[userId] = true
	local key = getProfileKey(userId)
	local snapshot = ProfileStore.Capture(player)

	local ok, err = pcall(function()
		profileStore:UpdateAsync(key, function(previous)
			local merged = normalizeProfile(previous)
			merged.version = snapshot.version
			merged.crystals = snapshot.crystals
			merged.selectedClass = snapshot.selectedClass
			merged.upgrades = snapshot.upgrades
			merged.updatedAt = snapshot.updatedAt
			return merged
		end)
	end)

	saveInFlight[userId] = nil
	if ok then
		dirtyByUserId[userId] = false
		return true
	end

	warn("[ProfileStore] UpdateAsync failed:", err)
	if shouldDisablePersistence(err) then
		persistenceDisabled = true
		persistenceDisabledReason = tostring(err)
		warn("[ProfileStore] Persistence disabled for this server:", persistenceDisabledReason)
	end
	return false
end

function ProfileStore.Unload(player)
	if not player then
		return
	end

	ProfileStore.Save(player, true)
	dirtyByUserId[player.UserId] = nil
	loadedByUserId[player.UserId] = nil
	disconnectUserConnections(player.UserId)
end

function ProfileStore.StartAutoSave()
	if autoSaveStarted then
		return
	end
	autoSaveStarted = true

	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if loadedByUserId[player.UserId] and dirtyByUserId[player.UserId] then
					ProfileStore.Save(player, false)
				end
			end
		end
	end)
end

return ProfileStore
