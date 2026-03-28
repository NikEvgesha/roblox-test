local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local SKILL_EVENT_NAME = "SkillEvent"
local progressionConfig = combatConfig.Progression
local skillsConfig = progressionConfig.Skills
local metaProgressionConfig = combatConfig.MetaProgression or {}
local metaUpgradeConfig = metaProgressionConfig.Upgrades or {}

local skillToStatName = {
	Speed = "SpeedLevel",
	MeleeDamage = "MeleeLevel",
	RangedDamage = "RangedLevel",
	Health = "HealthLevel",
}

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

local skillEvent = ensureRemoteEvent(SKILL_EVENT_NAME)

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

local function ensureProgression(player)
	local progression = player:FindFirstChild("Progression")
	if not progression then
		progression = Instance.new("Folder")
		progression.Name = "Progression"
		progression.Parent = player
	end

	ensureIntValue(progression, "SkillPoints", 0)
	ensureIntValue(progression, "SpeedLevel", 0)
	ensureIntValue(progression, "MeleeLevel", 0)
	ensureIntValue(progression, "RangedLevel", 0)
	ensureIntValue(progression, "HealthLevel", 0)

	return progression
end

local function getSkillLevel(progression, skillKey)
	local statName = skillToStatName[skillKey]
	if not statName then
		return 0
	end

	local value = progression:FindFirstChild(statName)
	if not value or not value:IsA("IntValue") then
		return 0
	end

	return value.Value
end

local function setSkillLevel(progression, skillKey, level)
	local statName = skillToStatName[skillKey]
	if not statName then
		return
	end

	local value = ensureIntValue(progression, statName, 0)
	value.Value = level
end

local function getMetaUpgradeLevel(player, upgradeKey)
	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression then
		return 0
	end

	local value = metaProgression:FindFirstChild(upgradeKey)
	if not value or not value:IsA("IntValue") then
		return 0
	end

	return math.max(0, value.Value)
end

local function applyCharacterDerivedStats(player, character)
	local progression = ensureProgression(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speedLevel = getSkillLevel(progression, "Speed")
	local healthLevel = getSkillLevel(progression, "Health")
	local metaSpeedLevel = getMetaUpgradeLevel(player, "Speed")
	local metaHealthLevel = getMetaUpgradeLevel(player, "Health")

	local walkSpeed = progressionConfig.BaseWalkSpeed
	walkSpeed += speedLevel * (skillsConfig.Speed.WalkSpeedPerLevel or 0)
	walkSpeed += metaSpeedLevel * (tonumber((metaUpgradeConfig.Speed or {}).WalkSpeedPerLevel) or 0)

	local maxHealth = progressionConfig.BaseMaxHealth
	maxHealth += healthLevel * (skillsConfig.Health.MaxHealthPerLevel or 0)
	maxHealth += metaHealthLevel * (tonumber((metaUpgradeConfig.Health or {}).MaxHealthPerLevel) or 0)
	local oldMax = math.max(1, humanoid.MaxHealth)
	local oldRatio = math.clamp(humanoid.Health / oldMax, 0, 1)

	humanoid.WalkSpeed = walkSpeed
	humanoid.MaxHealth = maxHealth
	humanoid.Health = math.max(1, maxHealth * oldRatio)
end

local function buildSkillStatePayload(player, message)
	local progression = ensureProgression(player)
	local points = ensureIntValue(progression, "SkillPoints", 0).Value
	local skills = {}

	for _, skillKey in ipairs(progressionConfig.SkillOrder or {}) do
		local skill = skillsConfig[skillKey]
		if skill then
			table.insert(skills, {
				key = skillKey,
				displayName = skill.DisplayName or skillKey,
				level = getSkillLevel(progression, skillKey),
				maxLevel = skill.MaxLevel or 1,
			})
		end
	end

	return {
		type = "state",
		points = points,
		skills = skills,
		message = message or "",
	}
end

local function sendSkillState(player, message)
	skillEvent:FireClient(player, buildSkillStatePayload(player, message))
end

local function tryUpgradeSkill(player, skillKey)
	local progression = ensureProgression(player)
	local points = ensureIntValue(progression, "SkillPoints", 0)
	local skill = skillsConfig[skillKey]
	if not skill then
		return "Unknown skill."
	end

	local currentLevel = getSkillLevel(progression, skillKey)
	local maxLevel = skill.MaxLevel or 1
	if currentLevel >= maxLevel then
		return "Skill is already maxed."
	end

	if points.Value <= 0 then
		return "Not enough skill points."
	end

	points.Value -= 1
	setSkillLevel(progression, skillKey, currentLevel + 1)

	if skillKey == "Speed" or skillKey == "Health" then
		applyCharacterDerivedStats(player, player.Character)
	end

	return ("Upgraded %s to level %d."):format(skill.DisplayName or skillKey, currentLevel + 1)
end

local function setupPlayer(player)
	ensureProgression(player)

	local function bindMetaSignals()
		local metaProgression = player:FindFirstChild("MetaProgression")
		if not metaProgression then
			return
		end

		for _, upgradeKey in ipairs({ "Speed", "Health" }) do
			local value = metaProgression:FindFirstChild(upgradeKey)
			if value and value:IsA("IntValue") then
				value:GetPropertyChangedSignal("Value"):Connect(function()
					applyCharacterDerivedStats(player, player.Character)
				end)
			end
		end
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			applyCharacterDerivedStats(player, character)
		end)
	end)

	if player.Character then
		task.defer(function()
			applyCharacterDerivedStats(player, player.Character)
		end)
	end

	task.defer(bindMetaSignals)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

skillEvent.OnServerEvent:Connect(function(player, action, skillKey)
	if action == "open" or action == "refresh" then
		sendSkillState(player, "")
		return
	end

	if action == "upgrade" then
		local result = tryUpgradeSkill(player, tostring(skillKey or ""))
		sendSkillState(player, result)
	end
end)
