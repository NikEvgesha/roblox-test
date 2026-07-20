local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local gameRules = require(sharedFolder:WaitForChild("GameRules"))
local profileStore = require(sharedFolder:WaitForChild("ProfileStore"))
local receiptRouter = require(script.Parent:WaitForChild("ReceiptRouter"))
local EnemyFactory = require(script.Parent:WaitForChild("EnemyFactory"))
local EnemyRuntime = require(script.Parent:WaitForChild("EnemyRuntime"))
local ReviveRuntime = require(script.Parent:WaitForChild("ReviveRuntime"))
local WaveDirector = require(script.Parent:WaitForChild("WaveDirector"))

local zombieConfig = combatConfig.Zombies
local progressionConfig = combatConfig.Progression
local achievementStatsConfig = combatConfig.AchievementStats or {}
local achievementStatOrder = achievementStatsConfig.Order or { "RunsPlayed", "BestWave", "TotalKills", "BossKills" }
local variantConfig = zombieConfig.Variants or {}
local waveDirector = WaveDirector.new(zombieConfig)

local SURVIVAL_EVENT_NAME = "SurvivalEvent"
local REVIVE_PURCHASE_EVENT_NAME = "RevivePurchaseEvent"
local DEBUG_ENEMY_SPAWN_EVENT_NAME = "DebugEnemySpawnEvent"
local ZOMBIES_FOLDER_NAME = "Zombies"
local SPAWN_POINTS_FOLDER_NAME = "ZombieSpawnPoints"
local DOWNED_FOLDER_NAME = "DownedPlayers"
local GAME_POINTS_FOLDER_NAME = "GamePoints"
local START_SPAWN_NAME = "StartSpawn"
local ACHIEVEMENT_STATS_FOLDER_NAME = "AchievementStats"

local achievementStatSet = {}
for _, statKey in ipairs(achievementStatOrder) do
	achievementStatSet[statKey] = true
end

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
local revivePurchaseEvent = ensureRemoteEvent(REVIVE_PURCHASE_EVENT_NAME)
local debugEnemySpawnEvent = ensureRemoteEvent(DEBUG_ENEMY_SPAWN_EVENT_NAME)

local function sendSurvivalEventToPlayer(player, payload)
	if player and player.Parent then
		survivalEvent:FireClient(player, payload)
	end
end

local function broadcastSurvivalEvent(payload)
	for _, player in ipairs(Players:GetPlayers()) do
		sendSurvivalEventToPlayer(player, payload)
	end
end

local function ensureFolder(name)
	local folder = Workspace:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function ensureExtractedAnimationsFolder(targetRoot)
	local folder = targetRoot:FindFirstChild("ExtractedAnimations")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "ExtractedAnimations"
	folder.Parent = targetRoot
	return folder
end

local function preserveAnimationsFromScript(scriptInstance, targetRoot)
	if not scriptInstance or not targetRoot then
		return 0
	end

	local preserved = 0
	local animationsFolder = ensureExtractedAnimationsFolder(targetRoot)

	for _, desc in ipairs(scriptInstance:GetDescendants()) do
		if desc:IsA("Animation") then
			local animationId = tostring(desc.AnimationId or "")
			if animationId ~= "" then
				local clone = Instance.new("Animation")
				clone.Name = desc.Name
				clone.AnimationId = animationId
				clone.Parent = animationsFolder
				preserved += 1
			end
		elseif desc:IsA("KeyframeSequence") then
			local okClone, clone = pcall(function()
				return desc:Clone()
			end)
			if okClone and clone then
				clone.Parent = animationsFolder
				preserved += 1
			end
		end
	end

	return preserved
end

local zombiesFolder = ensureFolder(ZOMBIES_FOLDER_NAME)
local spawnPointsFolder = ensureFolder(SPAWN_POINTS_FOLDER_NAME)
local downedFolder = ensureFolder(DOWNED_FOLDER_NAME)

local gamePointsFolder = Workspace:FindFirstChild(GAME_POINTS_FOLDER_NAME)
if not gamePointsFolder then
	gamePointsFolder = Instance.new("Folder")
	gamePointsFolder.Name = GAME_POINTS_FOLDER_NAME
	gamePointsFolder.Parent = Workspace
end

local function purgeScriptsFromFolder(folderName)
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		return 0
	end

	local removed = 0
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			local targetRoot = inst:FindFirstAncestorOfClass("Model") or folder
			preserveAnimationsFromScript(inst, targetRoot)
			removed += 1
			inst:Destroy()
		end
	end
	return removed
end

local function purgeBlockedSoundsFromFolder(folderName)
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		return 0
	end

	local removed = 0
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("Sound") then
			local soundId = string.lower(tostring(inst.SoundId))
			if soundId == "rbxasset://sounds/swoosh.wav" then
				removed += 1
				inst:Destroy()
			end
		end
	end
	return removed
end

local removedWeaponScripts = purgeScriptsFromFolder("Weapon")
local removedEnemyScripts = purgeScriptsFromFolder("Enemy")
local removedWeaponSounds = purgeBlockedSoundsFromFolder("Weapon")
local removedEnemySounds = purgeBlockedSoundsFromFolder("Enemy")
if removedWeaponScripts > 0 or removedEnemyScripts > 0 then
	warn(
		("[Survival] Removed toolbox scripts: Weapon=%d Enemy=%d")
			:format(removedWeaponScripts, removedEnemyScripts)
	)
end
if removedWeaponSounds > 0 or removedEnemySounds > 0 then
	warn(
		("[Survival] Removed blocked sounds: Weapon=%d Enemy=%d")
			:format(removedWeaponSounds, removedEnemySounds)
	)
end

local function ensureStartSpawn()
	local startSpawn = gamePointsFolder:FindFirstChild(START_SPAWN_NAME)
	if startSpawn and startSpawn:IsA("BasePart") then
		return startSpawn
	end

	startSpawn = Instance.new("Part")
	startSpawn.Name = START_SPAWN_NAME
	startSpawn.Size = Vector3.new(18, 1, 18)
	startSpawn.Material = Enum.Material.SmoothPlastic
	startSpawn.Color = Color3.fromRGB(208, 212, 220)
	startSpawn.Anchored = true
	startSpawn.CanCollide = true
	startSpawn.Position = Vector3.new(0, 3, 0)
	startSpawn.Parent = gamePointsFolder
	return startSpawn
end

local startSpawn = ensureStartSpawn()

local enemyFactory
local enemyRuntime
local reviveRuntime
local endMatch

local function cleanupEnemyState(state)
	if state and state.proceduralAnimation then
		state.proceduralAnimation = nil
	end
	if enemyFactory then
		enemyFactory:CleanupAnimationTracks(state)
	elseif state and state.animationTracks then
		for _, track in pairs(state.animationTracks) do
			if track then
				pcall(function()
					track:Stop(0.05)
					track:Destroy()
				end)
			end
		end
		state.animationTracks = nil
	end
end

local matchState = {
	runId = 0,
	startedAt = 0,
	ended = true,
	waveNumber = 0,
	waveBudget = 0,
	waveActive = false,
	waveSpawnsRemaining = 0,
	waveBossSpawnsRemaining = 0,
	intermissionEndsAt = 0,
	nextSpawnAt = 0,
	intermissionSecondLastSent = -1,
}

local reviveProducts = zombieConfig.ReviveProducts or {}
local reviveDisplayPrices = zombieConfig.ReviveDisplayPrices or {}
local soloReviveProductId = tonumber(reviveProducts.SoloReviveProductId) or 0
local teamReviveProductId = tonumber(reviveProducts.TeamReviveProductId) or 0
local soloReviveRobux = tonumber(reviveDisplayPrices.SoloReviveRobux) or 10
local teamReviveRobux = tonumber(reviveDisplayPrices.TeamReviveRobux) or 50

local function ensureIntStat(parent, name, defaultValue)
	local stat = parent:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		return stat
	end

	stat = Instance.new("IntValue")
	stat.Name = name
	stat.Value = defaultValue
	stat.Parent = parent
	return stat
end

local function ensureAchievementStatsFolder(player)
	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression then
		metaProgression = Instance.new("Folder")
		metaProgression.Name = "MetaProgression"
		metaProgression.Parent = player
	end

	local statsFolder = metaProgression:FindFirstChild(ACHIEVEMENT_STATS_FOLDER_NAME)
	if statsFolder and statsFolder:IsA("Folder") then
		return statsFolder
	end

	statsFolder = Instance.new("Folder")
	statsFolder.Name = ACHIEVEMENT_STATS_FOLDER_NAME
	statsFolder.Parent = metaProgression
	return statsFolder
end

local function ensureAchievementStatValue(player, statKey)
	if not achievementStatSet[statKey] then
		return nil
	end

	local statsFolder = ensureAchievementStatsFolder(player)
	return ensureIntStat(statsFolder, statKey, 0)
end

local function addAchievementStat(player, statKey, delta)
	if not player or player.Parent ~= Players then
		return
	end

	if player:GetAttribute("PersistentProfileLoaded") ~= true then
		return
	end

	local value = ensureAchievementStatValue(player, statKey)
	if not value then
		return
	end

	local step = math.floor(tonumber(delta) or 0)
	if step == 0 then
		return
	end

	value.Value = math.max(0, value.Value + step)
	player:SetAttribute(("Achievement_%s"):format(statKey), value.Value)
	profileStore.MarkDirty(player)
end

local function setAchievementStatMax(player, statKey, candidateValue)
	if not player or player.Parent ~= Players then
		return
	end

	if player:GetAttribute("PersistentProfileLoaded") ~= true then
		return
	end

	local value = ensureAchievementStatValue(player, statKey)
	if not value then
		return
	end

	local candidate = math.max(0, math.floor(tonumber(candidateValue) or 0))
	if candidate <= value.Value then
		return
	end

	value.Value = candidate
	player:SetAttribute(("Achievement_%s"):format(statKey), value.Value)
	profileStore.MarkDirty(player)
end

local function syncAchievementAttributes(player)
	if not player or player.Parent ~= Players then
		return
	end

	for _, statKey in ipairs(achievementStatOrder) do
		local value = ensureAchievementStatValue(player, statKey)
		if value then
			player:SetAttribute(("Achievement_%s"):format(statKey), value.Value)
		end
	end
end

local function ensureProgression(player)
	local progression = player:FindFirstChild("Progression")
	if not progression then
		progression = Instance.new("Folder")
		progression.Name = "Progression"
		progression.Parent = player
	end

	ensureIntStat(progression, "SkillPoints", 0)
	ensureIntStat(progression, "SpeedLevel", 0)
	ensureIntStat(progression, "MeleeLevel", 0)
	ensureIntStat(progression, "RangedLevel", 0)
	ensureIntStat(progression, "HealthLevel", 0)
	return progression
end

local function addXp(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local xp = ensureIntStat(leaderstats, "XP", 0)
	local level = ensureIntStat(leaderstats, "Level", 1)
	local progression = ensureProgression(player)
	local skillPoints = ensureIntStat(progression, "SkillPoints", 0)
	local result = gameRules.ApplyXp(
		level.Value,
		xp.Value,
		amount,
		progressionConfig.BaseXpForLevel,
		progressionConfig.XpGrowthPerLevel
	)
	level.Value = result.level
	xp.Value = result.xp
	skillPoints.Value += result.levelsGained
end

local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	ensureIntStat(leaderstats, "Money", 0)
	ensureIntStat(leaderstats, "XP", 0)
	ensureIntStat(leaderstats, "Level", 1)
	ensureIntStat(leaderstats, "Crystals", 0)
	return leaderstats
end

local function addMoney(player, amount)
	local leaderstats = ensureLeaderstats(player)
	local money = ensureIntStat(leaderstats, "Money", 0)
	money.Value += math.max(0, math.floor((amount or 0) + 0.5))
end

local function addCrystals(player, amount)
	local leaderstats = ensureLeaderstats(player)
	local crystals = ensureIntStat(leaderstats, "Crystals", 0)
	crystals.Value += math.max(0, math.floor((amount or 0) + 0.5))
end

local function getDifficultyKey()
	local configured = Workspace:GetAttribute("SelectedDifficulty")
	if type(configured) == "string" and zombieConfig.Difficulties and zombieConfig.Difficulties[configured] then
		return configured
	end
	return zombieConfig.DefaultDifficulty or "Medium"
end

local function getDifficultyConfig()
	local key = getDifficultyKey()
	local config = zombieConfig.Difficulties and zombieConfig.Difficulties[key]
	return config or {
		EnemyHealthMultiplier = 1,
		EnemyDamageMultiplier = 1,
		EnemyCountMultiplier = 1,
		RewardMultiplier = 1,
		CrystalMultiplier = 1,
	}
end

local function applyTeleportRunConfigFromPlayer(player)
	if not player then
		return false
	end

	local joinData = nil
	local ok = pcall(function()
		joinData = player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return false
	end

	local teleportData = joinData.TeleportData
	if type(teleportData) ~= "table" then
		return false
	end

	local changed = false
	local requestedDifficulty = teleportData.difficulty
	if type(requestedDifficulty) == "string"
		and zombieConfig.Difficulties
		and zombieConfig.Difficulties[requestedDifficulty]
	then
		Workspace:SetAttribute("SelectedDifficulty", requestedDifficulty)
		Workspace:SetAttribute("Difficulty", requestedDifficulty)
		changed = true
	end

	local targetPartySize = tonumber(teleportData.targetPartySize)
	if targetPartySize then
		Workspace:SetAttribute("LobbyTargetPartySize", math.max(1, math.floor(targetPartySize)))
		changed = true
	end

	local hostUserId = tonumber(teleportData.hostUserId)
	if hostUserId then
		Workspace:SetAttribute("LobbyHostUserId", math.floor(hostUserId))
		changed = true
	end

	return changed
end

local function awardZombieKillToParty(rewardMoney, rewardXP)
	local players = Players:GetPlayers()
	local count = #players
	if count <= 0 then
		return
	end

	local bonusPerPlayer = tonumber(zombieConfig.PartyRewardBonusPerPlayer) or 0.1
	local moneyPerPlayer = gameRules.GetPerPlayerReward(rewardMoney, count, bonusPerPlayer)
	local xpPerPlayer = gameRules.GetPerPlayerReward(rewardXP, count, bonusPerPlayer)

	for _, player in ipairs(players) do
		addMoney(player, moneyPerPlayer)
		addXp(player, xpPerPlayer)
		addAchievementStat(player, "TotalKills", 1)
	end
end

local function awardBossCrystalsToParty(baseCrystals)
	local difficulty = getDifficultyConfig()
	local multiplier = tonumber(difficulty.CrystalMultiplier) or 1
	local perPlayer = math.max(1, math.floor((baseCrystals or 0) * multiplier + 0.5))

	for _, player in ipairs(Players:GetPlayers()) do
		addCrystals(player, perPlayer)
	end
end

local function getPlayerState(player)
	return reviveRuntime:GetState(player)
end

local function ensureRunParticipationStat(player)
	if not player or player.Parent ~= Players then
		return
	end

	if matchState.ended then
		return
	end

	local state = getPlayerState(player)
	if state.runsCountedRunId == matchState.runId then
		return
	end

	if player:GetAttribute("PersistentProfileLoaded") ~= true then
		return
	end

	addAchievementStat(player, "RunsPlayed", 1)
	state.runsCountedRunId = matchState.runId
end

local function clearAllZombies()
	enemyRuntime:ClearAll()
end

local function safeLoadCharacter(player)
	if not player or not player.Parent then
		return
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return
		end
	end

	pcall(function()
		player:LoadCharacter()
	end)
end

local function canUseDebugEnemySpawner(player)
	local debugConfig = combatConfig.Debug or {}
	if RunService:IsStudio() then
		return debugConfig.EnableStudioEnemySpawner == true
	end

	if debugConfig.EnablePublishedEnemySpawner ~= true or not player then
		return false
	end

	for _, userId in ipairs(debugConfig.EnemySpawnerAuthorizedUserIds or {}) do
		if tonumber(userId) == player.UserId then
			return true
		end
	end

	return false
end

local function ensureDebugLoadTestProtection(player, character)
	if not canUseDebugEnemySpawner(player) or not character then
		return
	end

	if character:FindFirstChild("DebugLoadTestForceField") then
		return
	end

	local forceField = Instance.new("ForceField")
	forceField.Name = "DebugLoadTestForceField"
	forceField.Visible = false
	forceField.Parent = character
end

local function placeCharacterAtStart(character)
	if not character or not character.Parent then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then
		return
	end

	character:PivotTo(startSpawn.CFrame + Vector3.new(0, 3, 0))
end

local function getLiveTargetFromPlayer(player)
	return reviveRuntime:GetLiveTarget(player)
end

enemyRuntime = EnemyRuntime.new({
	folder = zombiesFolder,
	spawnPointsFolder = spawnPointsFolder,
	minSpawnDistance = zombieConfig.MinSpawnDistanceToPlayer,
	getPlayers = function()
		return Players:GetPlayers()
	end,
	getLiveTarget = getLiveTargetFromPlayer,
	cleanupState = cleanupEnemyState,
})

local function countAlivePlayers()
	return reviveRuntime:CountAlivePlayers()
end

local function getNearestPlayer(position)
	return enemyRuntime:GetNearestTarget(position)
end

local function getSurvivalSeconds()
	if matchState.startedAt <= 0 then
		return 0
	end
	return math.max(0, os.clock() - matchState.startedAt)
end

local function getDifficultyMultipliers()
	return waveDirector:GetDifficultyMultipliers(getDifficultyConfig())
end

local function chooseVariantKey()
	local weights = waveDirector:GetVariantWeights(matchState.waveNumber or 1)
	local total = 0
	for variantKey, weight in pairs(weights) do
		local variant = variantConfig[variantKey]
		if variant and not variant.IsBoss then
			total += math.max(0, weight)
		end
	end

	if total <= 0 then
		return "Walker"
	end

	local roll = math.random() * total
	local acc = 0
	for variantKey, weight in pairs(weights) do
		local variant = variantConfig[variantKey]
		if variant and not variant.IsBoss then
			acc += math.max(0, weight)
			if roll <= acc then
				return variantKey
			end
		end
	end

	return "Walker"
end

local function resolveKillerPlayer(humanoid)
	local creator = humanoid:FindFirstChild("creator")
	if creator and creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
		return creator.Value
	end

	local userId = humanoid:GetAttribute("LastHitByUserId")
	local lastHitAt = humanoid:GetAttribute("LastHitAt")
	if typeof(userId) ~= "number" or typeof(lastHitAt) ~= "number" then
		return nil
	end

	if os.clock() - lastHitAt > zombieConfig.KillCreditTimeout then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function findHumanoidFromPart(part)
	if not part then
		return nil, nil
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end

	return model:FindFirstChildOfClass("Humanoid"), model
end
local function spawnSpitProjectile(state, targetPosition)
	local origin = state.root.Position + Vector3.new(0, 1.4, 0)
	local direction = targetPosition - origin
	if direction.Magnitude <= 0.01 then
		return
	end

	local projectile = Instance.new("Part")
	projectile.Name = "ZombieSpit"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(0.6, 0.6, 0.6)
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(98, 240, 112)
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.Position = origin
	projectile.Parent = zombiesFolder

	local speed = state.spitProjectileSpeed or 50
	local maxLifetime = 3
	local elapsed = 0
	local unitDirection = direction.Unit

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { zombiesFolder, downedFolder }

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not projectile.Parent then
			connection:Disconnect()
			return
		end

		if matchState.ended then
			projectile:Destroy()
			connection:Disconnect()
			return
		end

		elapsed += dt
		if elapsed >= maxLifetime then
			projectile:Destroy()
			connection:Disconnect()
			return
		end

		local from = projectile.Position
		local step = unitDirection * speed * dt
		local result = Workspace:Raycast(from, step, rayParams)
		if result then
			local humanoid, model = findHumanoidFromPart(result.Instance)
			local player = model and Players:GetPlayerFromCharacter(model)
			if player and humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(state.spitDamage)
			end
			projectile:Destroy()
			connection:Disconnect()
			return
		end

		projectile.Position = from + step

		for _, player in ipairs(Players:GetPlayers()) do
			local humanoid, root = getLiveTargetFromPlayer(player)
			if humanoid and root and (root.Position - projectile.Position).Magnitude <= 2.2 then
				humanoid:TakeDamage(state.spitDamage)
				projectile:Destroy()
				connection:Disconnect()
				return
			end
		end
	end)

	Debris:AddItem(projectile, maxLifetime + 0.2)
end

local function explodeZombie(state)
	if state.exploded or state.dead then
		return
	end

	state.exploded = true

	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.Position = state.root.Position
	explosion.Parent = Workspace

	local range = state.explosionRange or 8
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid, root = getLiveTargetFromPlayer(player)
		if humanoid and root then
			local distance = (root.Position - state.root.Position).Magnitude
			if distance <= range then
				humanoid:TakeDamage(state.explosionDamage)
			end
		end
	end

	state.humanoid:TakeDamage(state.humanoid.MaxHealth * 5)
end

local function sanitizeTemplateZombieContent(model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			preserveAnimationsFromScript(inst, model)
			inst:Destroy()
		elseif inst:IsA("Sound") then
			local soundId = string.lower(tostring(inst.SoundId))
			if soundId == "rbxasset://sounds/swoosh.wav" then
				inst:Destroy()
			end
		end
	end
end

enemyFactory = EnemyFactory.new({
	config = zombieConfig,
	variants = variantConfig,
	enemyFolder = zombiesFolder,
	spawnPointsFolder = spawnPointsFolder,
	downedFolder = downedFolder,
	getDifficultyMultipliers = getDifficultyMultipliers,
	sanitizeTemplateContent = sanitizeTemplateZombieContent,
	onCreated = function(model, state)
		enemyRuntime:Register(model, state)
	end,
	onKilled = function(state)
		if matchState.ended then
			return
		end

		awardZombieKillToParty(state.rewardMoney, state.rewardXP)
		if state.isBoss then
			for _, player in ipairs(Players:GetPlayers()) do
				addAchievementStat(player, "BossKills", 1)
			end
		end
		if state.bossCrystals > 0 then
			awardBossCrystalsToParty(state.bossCrystals)
		end
	end,
	onRemoved = function(model)
		enemyRuntime:Remove(model)
	end,
})

local function createZombie(position, variantKey, stage)
	return enemyFactory:Create(position, variantKey, stage)
end
local function ensureSpawnPoint(name, position)
	local point = spawnPointsFolder:FindFirstChild(name)
	if point and point:IsA("BasePart") then
		return point
	end

	point = Instance.new("Part")
	point.Name = name
	point.Size = Vector3.new(3, 1, 3)
	point.Shape = Enum.PartType.Cylinder
	point.Material = Enum.Material.Neon
	point.Color = Color3.fromRGB(255, 80, 80)
	point.Transparency = 0.35
	point.Anchored = true
	point.CanCollide = false
	point.CanTouch = false
	point.CanQuery = false
	point.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	point.Parent = spawnPointsFolder
	return point
end

local function ensureDefaultSpawnPoints()
	local hasPoint = false
	for _, child in ipairs(spawnPointsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			hasPoint = true
			break
		end
	end

	if hasPoint then
		return
	end

	ensureSpawnPoint("SpawnPoint_1", Vector3.new(60, 2.5, 0))
	ensureSpawnPoint("SpawnPoint_2", Vector3.new(-60, 2.5, 0))
	ensureSpawnPoint("SpawnPoint_3", Vector3.new(0, 2.5, 60))
	ensureSpawnPoint("SpawnPoint_4", Vector3.new(0, 2.5, -60))
	ensureSpawnPoint("SpawnPoint_5", Vector3.new(45, 2.5, 45))
	ensureSpawnPoint("SpawnPoint_6", Vector3.new(-45, 2.5, -45))
end

local function getRandomSpawnPoint()
	return enemyRuntime:GetRandomSpawnPoint()
end

local function countAliveZombies()
	return enemyRuntime:CountAlive()
end

local waveDebugState = {}

local function setWaveDebugAttribute(name, value)
	if waveDebugState[name] == value then
		return
	end
	waveDebugState[name] = value
	Workspace:SetAttribute(name, value)
end

local function updateWaveDebugAttributes()
	local budget = 0
	local aliveCap = 0
	local spawnInterval = 0
	local aliveZombies = 0
	local spawnsRemaining = 0
	local bossSpawnsRemaining = 0

	if not matchState.ended and matchState.waveActive and matchState.waveNumber > 0 then
		budget = math.max(0, math.floor(tonumber(matchState.waveBudget) or 0))
		aliveCap = waveDirector:GetAliveCap(matchState.waveNumber, #Players:GetPlayers(), getDifficultyConfig())
		spawnInterval = math.floor(
			waveDirector:GetSpawnInterval(matchState.waveNumber, #Players:GetPlayers(), getDifficultyConfig()) * 100 + 0.5
		) / 100
		aliveZombies = countAliveZombies()
		spawnsRemaining = math.max(0, math.floor(tonumber(matchState.waveSpawnsRemaining) or 0))
		bossSpawnsRemaining = math.max(0, math.floor(tonumber(matchState.waveBossSpawnsRemaining) or 0))
	end

	setWaveDebugAttribute("WaveBudget", budget)
	setWaveDebugAttribute("WaveSpawnsRemaining", spawnsRemaining)
	setWaveDebugAttribute("WaveBossSpawnsRemaining", bossSpawnsRemaining)
	setWaveDebugAttribute("AliveZombies", aliveZombies)
	setWaveDebugAttribute("AliveCap", aliveCap)
	setWaveDebugAttribute("SpawnInterval", spawnInterval)
end

reviveRuntime = ReviveRuntime.new({
	config = zombieConfig,
	downedFolder = downedFolder,
	startSpawn = startSpawn,
	getPlayers = function()
		return Players:GetPlayers()
	end,
	isMatchEnded = function()
		return matchState.ended
	end,
	getRunId = function()
		return matchState.runId
	end,
	endMatch = function(reason)
		endMatch(reason)
	end,
	safeLoadCharacter = safeLoadCharacter,
	sendToPlayer = sendSurvivalEventToPlayer,
	broadcast = broadcastSurvivalEvent,
	restoreWaveState = function(forcedState)
		if forcedState then
			Workspace:SetAttribute("WaveState", forcedState)
		elseif matchState.waveActive then
			Workspace:SetAttribute(
				"WaveState",
				waveDirector:IsBossWave(matchState.waveNumber) and "BossWaveActive" or "WaveActive"
			)
		elseif matchState.intermissionEndsAt > 0 then
			Workspace:SetAttribute("WaveState", "Intermission")
		else
			Workspace:SetAttribute("WaveState", "PreRun")
		end
		updateWaveDebugAttributes()
	end,
	onCharacterReady = function(player, character)
		ensureDebugLoadTestProtection(player, character)
		task.defer(function()
			placeCharacterAtStart(character)
		end)
	end,
	soloPrice = soloReviveRobux,
	teamPrice = teamReviveRobux,
})

local function startWave(waveNumber)
	local totalSpawns, bossSpawns =
		waveDirector:ComputeSpawnBudget(waveNumber, #Players:GetPlayers(), getDifficultyConfig())
	matchState.waveNumber = waveNumber
	matchState.waveBudget = totalSpawns
	matchState.waveActive = true
	matchState.waveSpawnsRemaining = totalSpawns
	matchState.waveBossSpawnsRemaining = bossSpawns
	matchState.intermissionEndsAt = 0
	matchState.intermissionSecondLastSent = -1
	matchState.nextSpawnAt = os.clock()

	Workspace:SetAttribute("WaveNumber", waveNumber)
	Workspace:SetAttribute("IsBossWave", bossSpawns > 0)
	Workspace:SetAttribute("WaveState", bossSpawns > 0 and "BossWaveActive" or "WaveActive")
	updateWaveDebugAttributes()

	for _, player in ipairs(Players:GetPlayers()) do
		setAchievementStatMax(player, "BestWave", waveNumber)
	end

	if bossSpawns > 0 then
		broadcastSurvivalEvent({
			type = "match",
			text = ("Wave %d started. Boss incoming."):format(waveNumber),
		})
	else
		broadcastSurvivalEvent({
			type = "match",
			text = ("Wave %d started."):format(waveNumber),
		})
	end
end

local function beginIntermission()
	local seconds = tonumber(zombieConfig.IntermissionSeconds) or 12
	matchState.waveActive = false
	matchState.waveBudget = 0
	matchState.intermissionEndsAt = os.clock() + seconds
	matchState.intermissionSecondLastSent = -1
	Workspace:SetAttribute("IsBossWave", false)
	Workspace:SetAttribute("WaveState", "Intermission")
	updateWaveDebugAttributes()

	broadcastSurvivalEvent({
		type = "match",
		text = ("Wave %d cleared. Next wave in %ds."):format(matchState.waveNumber, seconds),
	})
end

local function updateWaveDirector(now)
	if matchState.ended then
		return
	end

	if reviveRuntime:IsWipeActive() then
		return
	end

	if countAlivePlayers() <= 0 then
		return
	end

	if matchState.waveActive then
		if matchState.waveSpawnsRemaining <= 0 and countAliveZombies() <= 0 then
			if matchState.waveNumber >= (tonumber(zombieConfig.TargetWaveCount) or 100) then
				endMatch("Victory")
				return
			end
			beginIntermission()
		end
		return
	end

	if matchState.intermissionEndsAt > 0 then
		local secondsLeft = math.max(0, math.ceil(matchState.intermissionEndsAt - now))
		if secondsLeft ~= matchState.intermissionSecondLastSent and secondsLeft > 0 and secondsLeft <= 5 then
			matchState.intermissionSecondLastSent = secondsLeft
			broadcastSurvivalEvent({
				type = "match",
				text = ("Wave %d starts in %ds."):format(matchState.waveNumber + 1, secondsLeft),
			})
		end

		if now >= matchState.intermissionEndsAt then
			startWave(matchState.waveNumber + 1)
		end
	end
end

local function startNewMatch()
	matchState.runId += 1
	matchState.startedAt = os.clock()
	matchState.ended = false
	matchState.waveNumber = 0
	matchState.waveBudget = 0
	matchState.waveActive = false
	matchState.waveSpawnsRemaining = 0
	matchState.waveBossSpawnsRemaining = 0
	matchState.intermissionEndsAt = 0
	matchState.nextSpawnAt = 0
	matchState.intermissionSecondLastSent = -1
	local difficultyKey = getDifficultyKey()

	Workspace:SetAttribute("SurvivalState", "Running")
	Workspace:SetAttribute("SurvivalReason", "")
	Workspace:SetAttribute("SelectedDifficulty", difficultyKey)
	Workspace:SetAttribute("Difficulty", difficultyKey)
	Workspace:SetAttribute("WaveNumber", 0)
	Workspace:SetAttribute("IsBossWave", false)
	Workspace:SetAttribute("WaveState", "PreRun")
	updateWaveDebugAttributes()
	broadcastSurvivalEvent({
		type = "match",
		text = ("New run started. Difficulty: %s"):format(difficultyKey),
	})

	clearAllZombies()
	reviveRuntime:ResetRun()

	for _, player in ipairs(Players:GetPlayers()) do
		ensureRunParticipationStat(player)
		safeLoadCharacter(player)
	end

	local runId = matchState.runId
	task.delay(3, function()
		if matchState.ended or matchState.runId ~= runId then
			return
		end
		startWave(1)
	end)
end

local function getReturnDelayForReason(reason)
	local fallback = math.max(0, tonumber(zombieConfig.RestartDelayAfterWipe) or 12)
	if tostring(reason) == "Victory" then
		return math.max(0, tonumber(zombieConfig.ReturnToLobbyDelayAfterVictory) or fallback)
	end
	return math.max(0, tonumber(zombieConfig.ReturnToLobbyDelayAfterWipe) or fallback)
end

endMatch = function(reason)
	if matchState.ended then
		return
	end

	local returnDelay = getReturnDelayForReason(reason)
	matchState.ended = true
	reviveRuntime:EndRun()
	Workspace:SetAttribute("SurvivalState", "GameOver")
	Workspace:SetAttribute("SurvivalReason", reason or "All players down")
	Workspace:SetAttribute("IsBossWave", false)
	Workspace:SetAttribute("WaveNumber", matchState.waveNumber or 0)
	Workspace:SetAttribute("WaveState", "RunResult")
	matchState.waveBudget = 0
	updateWaveDebugAttributes()
	local gameOverText
	if tostring(reason) == "Victory" then
		gameOverText = ("Run cleared. %d waves completed. Returning in %ds."):format(matchState.waveNumber or 0, returnDelay)
	elseif returnDelay > 0 then
		gameOverText = ("Game over. Returning in %ds."):format(returnDelay)
	else
		gameOverText = "Game over. Returning to lobby..."
	end
	broadcastSurvivalEvent({
		type = "match",
		text = gameOverText,
	})

	clearAllZombies()
	local currentRunId = matchState.runId
	task.delay(returnDelay, function()
		if matchState.runId ~= currentRunId then
			return
		end

		local lobbyPlaceId = tonumber(zombieConfig.LobbyPlaceId) or 0
		if lobbyPlaceId > 0 and not RunService:IsStudio() then
			local players = Players:GetPlayers()
			if #players > 0 then
				local ok, err = pcall(function()
					TeleportService:TeleportAsync(lobbyPlaceId, players)
				end)
				if ok then
					return
				end
				warn("[Survival] Teleport to lobby failed:", err)
			end
		end

		startNewMatch()
	end)
end

local function promptRevivePurchase(player, kind)
	local productId = kind == "team" and teamReviveProductId or soloReviveProductId

	if RunService:IsStudio() and productId <= 0 then
		if kind == "team" then
			reviveRuntime:GrantTeamRevive(player)
		else
			reviveRuntime:GrantSoloRevive(player)
		end
		return
	end

	if productId <= 0 then
		sendSurvivalEventToPlayer(player, {
			type = "match",
			text = "Revive product is not configured.",
		})
		return
	end

	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[Survival] PromptProductPurchase failed:", err)
	end
end

local function setupPlayer(player)
	reviveRuntime:PreparePlayer(player)
	applyTeleportRunConfigFromPlayer(player)
	ensureLeaderstats(player)
	ensureProgression(player)

	player:GetAttributeChangedSignal("PersistentProfileLoaded"):Connect(function()
		if player:GetAttribute("PersistentProfileLoaded") == true then
			syncAchievementAttributes(player)
			ensureRunParticipationStat(player)
		end
	end)
	if player:GetAttribute("PersistentProfileLoaded") == true then
		syncAchievementAttributes(player)
		ensureRunParticipationStat(player)
	end

	player.CharacterAdded:Connect(function(character)
		reviveRuntime:OnCharacterAdded(player, character)
	end)

	if player.Character then
		reviveRuntime:OnCharacterAdded(player, player.Character)
	end

	if not matchState.ended then
		task.defer(function()
			safeLoadCharacter(player)
		end)
	end
end

local function cleanupPlayer(player)
	reviveRuntime:CleanupPlayer(player)
end

local function spawnZombieFromPoint()
	if matchState.ended or reviveRuntime:IsWipeActive() then
		return
	end

	if not matchState.waveActive then
		return
	end

	if matchState.waveSpawnsRemaining <= 0 then
		return
	end

	if countAlivePlayers() <= 0 then
		return
	end

	local stage = waveDirector:GetDifficultyStage(matchState.waveNumber)
	local maxAlive = waveDirector:GetAliveCap(matchState.waveNumber, #Players:GetPlayers(), getDifficultyConfig())
	if countAliveZombies() >= maxAlive then
		return
	end

	local point = getRandomSpawnPoint()
	if not point then
		return
	end

	local variantKey
	if matchState.waveBossSpawnsRemaining > 0 then
		local configuredBoss = zombieConfig.BossVariantKey or "BossBrute"
		if variantConfig[configuredBoss] then
			variantKey = configuredBoss
		else
			variantKey = "Bomber"
		end
		matchState.waveBossSpawnsRemaining -= 1
	else
		variantKey = chooseVariantKey()
	end

	matchState.waveSpawnsRemaining = math.max(0, matchState.waveSpawnsRemaining - 1)
	createZombie(point.Position, variantKey, stage)
end

local debugSpawnCounts = { [1] = true, [10] = true, [100] = true }
local debugPreviewVariants = { Shardling = true, MossBrute = true, EmberWisp = true, AnimatedTroll = true }
local debugSpawnCooldownByUserId = {}

debugEnemySpawnEvent.OnServerEvent:Connect(function(player, requestedCount)
	if not canUseDebugEnemySpawner(player) then
		return
	end

	local variantKey = "Walker"
	local countValue = requestedCount
	if typeof(requestedCount) == "table" then
		countValue = requestedCount.count
		local requestedVariant = tostring(requestedCount.variant or "")
		if debugPreviewVariants[requestedVariant] then
			variantKey = requestedVariant
		end
	end
	local count = math.floor(tonumber(countValue) or 0)
	if not debugSpawnCounts[count] then
		return
	end
	if variantKey ~= "Walker" then
		count = 1
	end

	local now = os.clock()
	if now - (debugSpawnCooldownByUserId[player.UserId] or 0) < 0.25 then
		return
	end
	debugSpawnCooldownByUserId[player.UserId] = now

	ensureDebugLoadTestProtection(player, player.Character)

	task.spawn(function()
		local spawned = 0
		local stage = waveDirector:GetDifficultyStage(math.max(1, matchState.waveNumber))
		for index = 1, count do
			local point = getRandomSpawnPoint()
			if point then
				createZombie(point.Position, variantKey, stage)
				spawned += 1
			end

			if index % 10 == 0 then
				task.wait()
			end
		end

		debugEnemySpawnEvent:FireClient(player, {
			requested = count,
			spawned = spawned,
			variant = variantKey,
		})
	end)
end)

revivePurchaseEvent.OnServerEvent:Connect(function(player, action)
	if action == "request_solo" then
		if reviveRuntime:CanRequestSoloRevive(player) then
			promptRevivePurchase(player, "solo")
		end
		return
	end

	if action == "request_team" then
		if reviveRuntime:CanRequestTeamRevive(player) then
			promptRevivePurchase(player, "team")
		end
	end
end)

receiptRouter.RegisterProduct(soloReviveProductId, function(_, player)
	reviveRuntime:GrantSoloRevive(player)
	return true
end)

receiptRouter.RegisterProduct(teamReviveProductId, function(_, player)
	reviveRuntime:GrantTeamRevive(player)
	return true
end)

ensureDefaultSpawnPoints()
Players.CharacterAutoLoads = false

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

startNewMatch()

local lastStageAttribute = -1

local function orientationFromForward(forward)
	if forward.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	local planar = Vector3.new(forward.X, 0, forward.Z)
	if planar.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return planar.Unit
end

local function stopZombieTrack(track, fadeTime)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.12)
	end
end

local function playZombieTrack(track, fadeTime, speed)
	if not track then
		return
	end

	if track.IsPlaying then
		if speed then
			track:AdjustSpeed(speed)
		end
		return
	end

	track:Play(fadeTime or 0.12, 1, speed or 1)
end

local function updateZombieLocomotionAnimation(state, isMoving)
	local tracks = state.animationTracks
	if not tracks then
		return
	end

	local walkSpeedScale = math.clamp((state.moveSpeed or zombieConfig.BaseMoveSpeed) / zombieConfig.BaseMoveSpeed, 0.75, 1.45)

	if isMoving then
		playZombieTrack(tracks.walk, 0.15, walkSpeedScale)
		stopZombieTrack(tracks.idle, 0.15)
	else
		playZombieTrack(tracks.idle, 0.2, 1)
		stopZombieTrack(tracks.walk, 0.15)
	end
end

local function triggerZombieAttackAnimation(state, now)
	local currentTime = now or os.clock()
	state.attackAnimStartedAt = currentTime
	state.attackAnimEndsAt = currentTime + state.attackAnimDuration
	if state.proceduralAnimation and state.model and state.model.Parent then
		state.model:SetAttribute("ProceduralAnimationAttackStartedAt", Workspace:GetServerTimeNow())
		state.model:SetAttribute("ProceduralAnimationAttackDuration", state.attackAnimDuration)
		state.model:SetAttribute(
			"ProceduralAnimationAttackSerial",
			(tonumber(state.model:GetAttribute("ProceduralAnimationAttackSerial")) or 0) + 1
		)
	end

	local tracks = state.animationTracks
	if tracks and tracks.attack then
		stopZombieTrack(tracks.attack, 0.05)
		playZombieTrack(tracks.attack, 0.05, 1)
	end
end

local function buildZombiePoseCFrame(state, basePosition, lookForward, isMoving, now, deltaTime)
	if state.animationTracks or state.proceduralAnimation then
		return CFrame.lookAt(basePosition, basePosition + lookForward)
	end

	local phaseSpeed = isMoving and (2.1 + (state.moveSpeed or 5) * 0.16) or 1.1
	state.visualPhase = (state.visualPhase + phaseSpeed * deltaTime) % (math.pi * 2)

	local bobAmp
	if state.isFlyer then
		bobAmp = isMoving and 0.22 or 0.1
	else
		bobAmp = isMoving and 0.16 or 0.04
	end

	local bobOffset = math.sin(state.visualPhase) * bobAmp
	local swayOffset = math.sin(state.visualPhase * 2) * (isMoving and 0.025 or 0.01)

	local attackCurve = 0
	if state.attackAnimEndsAt > now and state.attackAnimDuration > 0 then
		local elapsed = now - state.attackAnimStartedAt
		local progress = math.clamp(elapsed / state.attackAnimDuration, 0, 1)
		attackCurve = math.sin(progress * math.pi)
	end

	local lungeDistance = attackCurve * (state.isFlyer and 0.15 or 0.28)
	local pitch = attackCurve * 0.18 + swayOffset
	local roll = math.sin(state.visualPhase * 1.3) * (isMoving and 0.02 or 0.008)
	local adjustedPosition = basePosition + Vector3.new(0, bobOffset, 0) + lookForward * lungeDistance
	return CFrame.lookAt(adjustedPosition, adjustedPosition + lookForward) * CFrame.Angles(pitch, 0, roll)
end

task.spawn(function()
	while true do
		if matchState.ended then
			task.wait(0.25)
		else
			local now = os.clock()
			if matchState.waveActive and not reviveRuntime:IsWipeActive() and matchState.waveSpawnsRemaining > 0 then
				if now >= matchState.nextSpawnAt then
					local ok, err = pcall(spawnZombieFromPoint)
					if not ok then
						warn("[Survival] Zombie spawn failed:\n" .. tostring(err))
					end
					matchState.nextSpawnAt = now
						+ waveDirector:GetSpawnInterval(
							matchState.waveNumber,
							#Players:GetPlayers(),
							getDifficultyConfig()
						)
				end
			end
			task.wait(0.1)
		end
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	if matchState.ended then
		return
	end

	local now = os.clock()
	updateWaveDirector(now)
	updateWaveDebugAttributes()

	local stage = waveDirector:GetDifficultyStage(matchState.waveNumber or 1)
	if stage ~= lastStageAttribute then
		lastStageAttribute = stage
		Workspace:SetAttribute("SurvivalStage", stage)
	end

	enemyRuntime:ForEachAlive(function(zombie, state)
		local humanoid = state.humanoid
		local root = state.root

		local _, targetHumanoid, targetRoot, distance = getNearestPlayer(root.Position)
		if targetHumanoid and targetRoot and distance < math.huge then
			local targetPosition = targetRoot.Position
			if state.isFlyer then
				targetPosition = targetPosition + Vector3.new(0, state.flyHeight, 0)
			end

			local toTarget = targetPosition - root.Position
			local movementVector = state.isFlyer and toTarget or Vector3.new(toTarget.X, 0, toTarget.Z)
			local movementDistance = movementVector.Magnitude
			local forward = movementDistance > 0.01 and movementVector.Unit or root.CFrame.LookVector
			local lookForward = orientationFromForward(forward)

			if state.isBomber and distance <= state.explosionTriggerRange then
				explodeZombie(state)
				return
			end

			if state.isSpitter and distance <= state.spitRange and now - state.lastSpit >= state.spitCooldown then
				state.lastSpit = now
				triggerZombieAttackAnimation(state, now)
				spawnSpitProjectile(state, targetRoot.Position + Vector3.new(0, 1.4, 0))
			end

			local isMoving = movementDistance > state.attackRange
			local basePosition = root.Position

			if isMoving then
				local maxStep = state.moveSpeed * deltaTime
				local approachDistance = math.max(0, movementDistance - state.attackRange * 0.55)
				local step = math.min(maxStep, approachDistance)
				if step > 0 then
					basePosition = basePosition + forward * step
				else
					isMoving = false
				end
			end

			if not isMoving then
				if now - state.lastAttack >= state.attackCooldown then
					state.lastAttack = now
					triggerZombieAttackAnimation(state, now)
					targetHumanoid:TakeDamage(state.attackDamage)
				end
			end

			state.lastMoveAnimated = isMoving
			updateZombieLocomotionAnimation(state, isMoving)
			local posedCFrame = buildZombiePoseCFrame(state, basePosition, lookForward, isMoving, now, deltaTime)
			zombie:PivotTo(posedCFrame)
		else
			state.lastMoveAnimated = false
			updateZombieLocomotionAnimation(state, false)
			local idleForward = orientationFromForward(root.CFrame.LookVector)
			local idleCFrame = buildZombiePoseCFrame(state, root.Position, idleForward, false, now, deltaTime)
			zombie:PivotTo(idleCFrame)
		end
	end)
end)
