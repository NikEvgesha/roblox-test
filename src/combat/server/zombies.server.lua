local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local zombieConfig = combatConfig.Zombies
local progressionConfig = combatConfig.Progression
local variantConfig = zombieConfig.Variants or {}
local difficultySchedule = zombieConfig.DifficultySchedule or { { MinTime = 0, Weights = { Walker = 100 } } }

local SURVIVAL_EVENT_NAME = "SurvivalEvent"
local REVIVE_PURCHASE_EVENT_NAME = "RevivePurchaseEvent"
local ZOMBIES_FOLDER_NAME = "Zombies"
local SPAWN_POINTS_FOLDER_NAME = "ZombieSpawnPoints"
local DOWNED_FOLDER_NAME = "DownedPlayers"
local GAME_POINTS_FOLDER_NAME = "GamePoints"
local START_SPAWN_NAME = "StartSpawn"

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

local zombiesFolder = ensureFolder(ZOMBIES_FOLDER_NAME)
local spawnPointsFolder = ensureFolder(SPAWN_POINTS_FOLDER_NAME)
local downedFolder = ensureFolder(DOWNED_FOLDER_NAME)

local gamePointsFolder = Workspace:FindFirstChild(GAME_POINTS_FOLDER_NAME)
if not gamePointsFolder then
	gamePointsFolder = Instance.new("Folder")
	gamePointsFolder.Name = GAME_POINTS_FOLDER_NAME
	gamePointsFolder.Parent = Workspace
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

local zombieStates = {}
local playerStates = {}
local pendingProductRequests = {}
local processedReceipts = {}
local wipeState = {
	active = false,
	token = 0,
	endsAt = 0,
}
local clearReviveOptions

local matchState = {
	runId = 0,
	startedAt = 0,
	ended = true,
	waveNumber = 0,
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

local function getXpForLevel(level)
	return progressionConfig.BaseXpForLevel + math.max(0, level - 1) * progressionConfig.XpGrowthPerLevel
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
	local remaining = math.max(0, math.floor(amount))

	while remaining > 0 do
		local need = getXpForLevel(level.Value) - xp.Value
		if need <= 0 then
			level.Value += 1
			skillPoints.Value += 1
			xp.Value = 0
		elseif remaining >= need then
			remaining -= need
			level.Value += 1
			skillPoints.Value += 1
			xp.Value = 0
		else
			xp.Value += remaining
			remaining = 0
		end
	end
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

local function getRewardBonusMultiplier(playerCount)
	if playerCount <= 1 then
		return 1
	end

	local perPlayer = tonumber(zombieConfig.PartyRewardBonusPerPlayer) or 0.1
	return 1 + perPlayer * playerCount
end

local function getEnemyCountPartyMultiplier(playerCount)
	if playerCount <= 1 then
		return 1
	end

	local perPlayer = tonumber(zombieConfig.PartyEnemyCountBonusPerPlayer) or 0.1
	return 1 + perPlayer * playerCount
end

local function getFreeRespawnSecondsForDeath(deathCount)
	local base = tonumber(zombieConfig.FreeRespawnBaseSeconds) or 10
	local increment = tonumber(zombieConfig.FreeRespawnIncrementSeconds) or 10
	return base + math.max(0, deathCount - 1) * increment
end

local function awardZombieKillToParty(rewardMoney, rewardXP)
	local players = Players:GetPlayers()
	local count = #players
	if count <= 0 then
		return
	end

	local bonus = getRewardBonusMultiplier(count)
	local moneyPerPlayer = math.max(0, math.floor((rewardMoney or 0) * bonus / count + 0.5))
	local xpPerPlayer = math.max(0, math.floor((rewardXP or 0) * bonus / count + 0.5))

	for _, player in ipairs(players) do
		addMoney(player, moneyPerPlayer)
		addXp(player, xpPerPlayer)
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

local function colorFromRgbArray(rgbArray, fallback)
	if type(rgbArray) ~= "table" then
		return fallback
	end

	return Color3.fromRGB(
		tonumber(rgbArray[1]) or math.floor(fallback.R * 255 + 0.5),
		tonumber(rgbArray[2]) or math.floor(fallback.G * 255 + 0.5),
		tonumber(rgbArray[3]) or math.floor(fallback.B * 255 + 0.5)
	)
end

local function getPlayerState(player)
	local state = playerStates[player]
	if state then
		return state
	end

	state = {
		alive = false,
		downed = false,
		deathToken = 0,
		deathCount = 0,
		downedMarker = nil,
	}
	playerStates[player] = state
	return state
end

local function removeDownedMarker(player)
	local state = getPlayerState(player)
	if state.downedMarker and state.downedMarker.Parent then
		state.downedMarker:Destroy()
	end
	state.downedMarker = nil
end

local function clearAllDownedMarkers()
	for _, player in ipairs(Players:GetPlayers()) do
		removeDownedMarker(player)
	end

	for _, child in ipairs(downedFolder:GetChildren()) do
		child:Destroy()
	end
end

local function clearAllZombies()
	for model in pairs(zombieStates) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	table.clear(zombieStates)

	for _, child in ipairs(zombiesFolder:GetChildren()) do
		child:Destroy()
	end
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
	local state = playerStates[player]
	if not state or not state.alive or state.downed then
		return nil, nil
	end

	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, root
end

local function countAlivePlayers()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = getLiveTargetFromPlayer(player)
		if humanoid then
			count += 1
		end
	end
	return count
end

local function getNearestPlayer(position)
	local nearestPlayer = nil
	local nearestHumanoid = nil
	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid, root = getLiveTargetFromPlayer(player)
		if humanoid and root then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
				nearestHumanoid = humanoid
				nearestRoot = root
			end
		end
	end

	return nearestPlayer, nearestHumanoid, nearestRoot, nearestDistance
end

local function getSurvivalSeconds()
	if matchState.startedAt <= 0 then
		return 0
	end
	return math.max(0, os.clock() - matchState.startedAt)
end

local function getDifficultyStage()
	return math.max(0, (matchState.waveNumber or 1) - 1)
end

local function getDifficultyMultipliers()
	local difficulty = getDifficultyConfig()
	return {
		health = tonumber(difficulty.EnemyHealthMultiplier) or 1,
		damage = tonumber(difficulty.EnemyDamageMultiplier) or 1,
		enemyCount = tonumber(difficulty.EnemyCountMultiplier) or 1,
		reward = tonumber(difficulty.RewardMultiplier) or 1,
		crystal = tonumber(difficulty.CrystalMultiplier) or 1,
	}
end

local function getCurrentVariantWeights()
	local stage = getDifficultyStage()
	local progressionTime = stage * math.max(1, zombieConfig.DifficultyStepSeconds)
	local chosenWeights = nil

	for _, entry in ipairs(difficultySchedule) do
		local minTime = entry.MinTime
		if minTime == nil and entry.MinWave ~= nil then
			minTime = (entry.MinWave - 1) * math.max(1, zombieConfig.DifficultyStepSeconds)
		end
		minTime = minTime or 0
		if progressionTime >= minTime then
			chosenWeights = entry.Weights
		else
			break
		end
	end

	return chosenWeights or { Walker = 100 }
end

local function chooseVariantKey()
	local weights = getCurrentVariantWeights()
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

local function getScaledValue(baseValue, scalePerStage, stage, multiplier)
	return baseValue * (1 + scalePerStage * stage) * (multiplier or 1)
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
local function attachZombieHealthBar(zombieModel, humanoid, head, title)
	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "ZombieHealthGui"
	healthGui.Size = UDim2.fromOffset(140, 24)
	healthGui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	healthGui.AlwaysOnTop = true
	healthGui.MaxDistance = 180
	healthGui.Adornee = head
	healthGui.Parent = zombieModel

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	bg.BorderSizePixel = 0
	bg.Parent = healthGui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 7)
	bgCorner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(88, 214, 115)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextStrokeTransparency = 0.55
	label.Text = title
	label.Parent = bg

	local function updateBar()
		local maxHealth = math.max(1, humanoid.MaxHealth)
		local ratio = math.clamp(humanoid.Health / maxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		label.Text = ("%s %d/%d"):format(title, math.ceil(humanoid.Health), math.floor(maxHealth))
	end

	humanoid.HealthChanged:Connect(updateBar)
	updateBar()
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

local function resolveGroundY(position)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { zombiesFolder, spawnPointsFolder, downedFolder }

	local rayOrigin = position + Vector3.new(0, 40, 0)
	local rayDirection = Vector3.new(0, -180, 0)
	local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
	if result then
		return result.Position.Y
	end

	return position.Y
end

local function createZombie(position, variantKey, stage)
	local variant = variantConfig[variantKey] or variantConfig.Walker
	variantKey = variantConfig[variantKey] and variantKey or "Walker"

	local zombie = Instance.new("Model")
	zombie.Name = "Zombie_" .. variantKey
	zombie:SetAttribute("IsZombie", true)
	zombie:SetAttribute("ZombieVariant", variantKey)

	local multipliers = getDifficultyMultipliers()
	local health = getScaledValue(zombieConfig.BaseHealth, zombieConfig.HealthScalePerStage, stage, (variant.HealthMul or 1) * multipliers.health)
	local moveSpeed = getScaledValue(zombieConfig.BaseMoveSpeed, zombieConfig.SpeedScalePerStage, stage, variant.MoveSpeedMul or 1)
	local attackDamage = getScaledValue(zombieConfig.BaseAttackDamage, zombieConfig.DamageScalePerStage, stage, (variant.DamageMul or 1) * multipliers.damage)
	local rewardMoney = getScaledValue(zombieConfig.BaseRewardMoney, zombieConfig.RewardScalePerStage, stage, (variant.RewardMul or 1) * multipliers.reward)
	local rewardXP = getScaledValue(zombieConfig.BaseRewardXP, zombieConfig.RewardScalePerStage, stage, (variant.RewardMul or 1) * multipliers.reward)
	local attackRange = zombieConfig.BaseAttackRange
	local attackCooldown = math.max(0.35, zombieConfig.BaseAttackCooldown / (1 + stage * 0.02))

	local bodyScaleY = variant.ScaleY or 1
	local torsoColor = colorFromRgbArray(variant.Color, Color3.fromRGB(77, 142, 74))
	local headColor = colorFromRgbArray(variant.HeadColor, Color3.fromRGB(101, 170, 95))

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = moveSpeed
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = zombie

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = zombie

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 2.6 * bodyScaleY, 1.4)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = torsoColor
	torso.Anchored = true
	torso.CanCollide = true
	torso.Parent = zombie

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1.2 * bodyScaleY, 1.2)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = headColor
	head.Anchored = true
	head.CanCollide = true
	head.Parent = zombie

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	if variantKey == "Flyer" then
		local leftWing = Instance.new("Part")
		leftWing.Name = "LeftWing"
		leftWing.Size = Vector3.new(0.2, 1.2, 3.2)
		leftWing.Material = Enum.Material.Neon
		leftWing.Color = Color3.fromRGB(173, 164, 255)
		leftWing.CanCollide = false
		leftWing.Massless = true
		leftWing.Parent = zombie

		local rightWing = leftWing:Clone()
		rightWing.Name = "RightWing"
		rightWing.Parent = zombie

		leftWing.CFrame = root.CFrame * CFrame.new(-1.3, 0.1, 0)
		rightWing.CFrame = root.CFrame * CFrame.new(1.3, 0.1, 0)

		local weldLeft = Instance.new("WeldConstraint")
		weldLeft.Part0 = root
		weldLeft.Part1 = leftWing
		weldLeft.Parent = leftWing

		local weldRight = Instance.new("WeldConstraint")
		weldRight.Part0 = root
		weldRight.Part1 = rightWing
		weldRight.Parent = rightWing
	end

	local rootToTorso = Instance.new("WeldConstraint")
	rootToTorso.Part0 = root
	rootToTorso.Part1 = torso
	rootToTorso.Parent = torso

	local rootToHead = Instance.new("WeldConstraint")
	rootToHead.Part0 = root
	rootToHead.Part1 = head
	rootToHead.Parent = head

	local groundY = resolveGroundY(position)
	local baseYOffset = torso.Size.Y * 0.5 + 0.1
	local yOffset = baseYOffset + (variant.FlyHeight or 0)
	root.CFrame = CFrame.new(position.X, groundY + yOffset, position.Z)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.8 * bodyScaleY, 0)

	zombie.PrimaryPart = root
	zombie.Parent = zombiesFolder

	attachZombieHealthBar(zombie, humanoid, head, variant.DisplayName or variantKey)

	local state = {
		model = zombie,
		humanoid = humanoid,
		root = root,
		variantKey = variantKey,
		variant = variant,
		moveSpeed = moveSpeed,
		attackDamage = attackDamage,
		attackRange = attackRange,
		attackCooldown = attackCooldown,
		rewardMoney = rewardMoney,
		rewardXP = rewardXP,
		bossCrystals = math.max(0, math.floor((variant.BossCrystalDrop or 0) * multipliers.crystal + 0.5)),
		lastAttack = 0,
		lastSpit = 0,
		dead = false,
		exploded = false,
		isFlyer = variantKey == "Flyer",
		isSpitter = variantKey == "Spitter",
		isBomber = variantKey == "Bomber",
		spitRange = variant.SpitRange or 0,
		spitDamage = (variant.SpitDamage or 0) * (1 + stage * zombieConfig.DamageScalePerStage) * multipliers.damage,
		spitCooldown = variant.SpitCooldown or 0,
		spitProjectileSpeed = variant.SpitProjectileSpeed or 0,
		explosionRange = variant.ExplosionRange or 0,
		explosionDamage = (variant.ExplosionDamage or 0) * (1 + stage * zombieConfig.DamageScalePerStage) * multipliers.damage,
		explosionTriggerRange = variant.ExplosionTriggerRange or 0,
		flyHeight = variant.FlyHeight or 0,
	}

	zombieStates[zombie] = state

	local function handleZombieDeath()
		if state.dead then
			return
		end

		state.dead = true
		humanoid.Health = 0

		if not matchState.ended then
			awardZombieKillToParty(state.rewardMoney, state.rewardXP)
			if state.bossCrystals > 0 then
				awardBossCrystalsToParty(state.bossCrystals)
			end
		end

		zombieStates[zombie] = nil
		task.delay(2, function()
			if zombie.Parent then
				zombie:Destroy()
			end
		end)
	end

	humanoid.Died:Connect(handleZombieDeath)
	humanoid.HealthChanged:Connect(function(currentHealth)
		if currentHealth <= 0 then
			handleZombieDeath()
		end
	end)

	zombie.AncestryChanged:Connect(function(_, parent)
		if not parent then
			zombieStates[zombie] = nil
		end
	end)
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
	local points = {}
	for _, child in ipairs(spawnPointsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end

	if #points == 0 then
		return nil
	end

	for _ = 1, 12 do
		local candidate = points[math.random(1, #points)]
		local _, _, _, distance = getNearestPlayer(candidate.Position)
		if distance == math.huge or distance >= zombieConfig.MinSpawnDistanceToPlayer then
			return candidate
		end
	end

	return points[math.random(1, #points)]
end

local function countAliveZombies()
	local count = 0
	for _, state in pairs(zombieStates) do
		if state.humanoid and state.humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

local function isBossWave(waveNumber)
	local interval = math.max(1, tonumber(zombieConfig.BossWaveInterval) or 10)
	return waveNumber % interval == 0
end

local function computeWaveSpawnBudget(waveNumber)
	local multipliers = getDifficultyMultipliers()
	local partySize = #Players:GetPlayers()
	local normalCount = (tonumber(zombieConfig.BaseEnemiesPerWave) or 8)
	normalCount += math.max(0, waveNumber - 1) * (tonumber(zombieConfig.EnemiesPerWaveStep) or 1)
	if isBossWave(waveNumber) then
		normalCount += tonumber(zombieConfig.BossAdditionalEnemies) or 0
	end

	normalCount *= getEnemyCountPartyMultiplier(partySize)
	normalCount *= multipliers.enemyCount
	normalCount = math.max(1, math.floor(normalCount + 0.5))

	local bossCount = isBossWave(waveNumber) and 1 or 0
	return normalCount + bossCount, bossCount
end

local function getWaveSpawnInterval()
	local stage = getDifficultyStage()
	local multipliers = getDifficultyMultipliers()
	local partyMultiplier = getEnemyCountPartyMultiplier(#Players:GetPlayers())
	local spawnPressure = math.max(1, multipliers.enemyCount * partyMultiplier)
	local interval = zombieConfig.BaseSpawnInterval / (1 + stage * zombieConfig.SpawnRateScalePerStage)
	interval /= spawnPressure
	return math.max(zombieConfig.MinSpawnInterval, interval)
end

local function startWave(waveNumber)
	local totalSpawns, bossSpawns = computeWaveSpawnBudget(waveNumber)
	matchState.waveNumber = waveNumber
	matchState.waveActive = true
	matchState.waveSpawnsRemaining = totalSpawns
	matchState.waveBossSpawnsRemaining = bossSpawns
	matchState.intermissionEndsAt = 0
	matchState.intermissionSecondLastSent = -1
	matchState.nextSpawnAt = os.clock()

	Workspace:SetAttribute("WaveNumber", waveNumber)
	Workspace:SetAttribute("IsBossWave", bossSpawns > 0)

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
	matchState.intermissionEndsAt = os.clock() + seconds
	matchState.intermissionSecondLastSent = -1
	Workspace:SetAttribute("IsBossWave", false)

	broadcastSurvivalEvent({
		type = "match",
		text = ("Wave %d cleared. Next wave in %ds."):format(matchState.waveNumber, seconds),
	})
end

local function updateWaveDirector(now)
	if matchState.ended then
		return
	end

	if wipeState.active then
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
	matchState.waveActive = false
	matchState.waveSpawnsRemaining = 0
	matchState.waveBossSpawnsRemaining = 0
	matchState.intermissionEndsAt = 0
	matchState.nextSpawnAt = 0
	matchState.intermissionSecondLastSent = -1
	wipeState.active = false
	wipeState.endsAt = 0
	wipeState.token += 1

	local difficultyKey = getDifficultyKey()

	Workspace:SetAttribute("SurvivalState", "Running")
	Workspace:SetAttribute("SurvivalReason", "")
	Workspace:SetAttribute("SelectedDifficulty", difficultyKey)
	Workspace:SetAttribute("Difficulty", difficultyKey)
	Workspace:SetAttribute("WaveNumber", 0)
	Workspace:SetAttribute("IsBossWave", false)
	broadcastSurvivalEvent({
		type = "match",
		text = ("New run started. Difficulty: %s"):format(difficultyKey),
	})

	clearAllZombies()
	clearAllDownedMarkers()
	clearReviveOptions()

	for _, player in ipairs(Players:GetPlayers()) do
		local state = getPlayerState(player)
		state.alive = false
		state.downed = false
		state.deathCount = 0
		state.deathToken += 1
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

local function endMatch(reason)
	if matchState.ended then
		return
	end

	matchState.ended = true
	wipeState.active = false
	wipeState.endsAt = 0
	wipeState.token += 1
	Workspace:SetAttribute("SurvivalState", "GameOver")
	Workspace:SetAttribute("SurvivalReason", reason or "All players down")
	Workspace:SetAttribute("IsBossWave", false)
	Workspace:SetAttribute("WaveNumber", matchState.waveNumber or 0)
	local gameOverText = ("Game over. Returning in %ds."):format(zombieConfig.RestartDelayAfterWipe)
	if tostring(reason) == "Victory" then
		gameOverText = ("Run cleared. %d waves completed. Returning in %ds."):format(matchState.waveNumber or 0, zombieConfig.RestartDelayAfterWipe)
	end
	broadcastSurvivalEvent({
		type = "match",
		text = gameOverText,
	})

	clearAllZombies()
	clearAllDownedMarkers()

	for _, state in pairs(playerStates) do
		state.alive = false
		state.downed = false
		state.deathToken += 1
	end
	table.clear(pendingProductRequests)

	local currentRunId = matchState.runId
	task.delay(zombieConfig.RestartDelayAfterWipe, function()
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

clearReviveOptions = function()
	broadcastSurvivalEvent({
		type = "revive_options_clear",
	})
end

local function canUseWipeWindow()
	return wipeState.active and os.clock() <= wipeState.endsAt
end

local function beginWipeWindow()
	if wipeState.active or matchState.ended then
		return
	end

	wipeState.active = true
	wipeState.token += 1
	local wipeToken = wipeState.token
	local duration = tonumber(zombieConfig.WipePurchaseWindowSeconds) or 30
	wipeState.endsAt = os.clock() + duration

	broadcastSurvivalEvent({
		type = "match",
		text = ("All players are down. Buy revive in %ds or run ends."):format(duration),
	})
	broadcastSurvivalEvent({
		type = "revive_options",
		canSolo = true,
		canTeam = true,
		soloPrice = soloReviveRobux,
		teamPrice = teamReviveRobux,
		seconds = duration,
		wipeOnly = true,
	})

	task.spawn(function()
		for secondsLeft = duration, 1, -1 do
			if matchState.ended or wipeState.token ~= wipeToken or not wipeState.active then
				return
			end

			broadcastSurvivalEvent({
				type = "wipe_timer",
				seconds = secondsLeft,
				text = ("Team wipe. Buy revive in %ds."):format(secondsLeft),
			})
			task.wait(1)
		end

		if matchState.ended or wipeState.token ~= wipeToken or not wipeState.active then
			return
		end

		if countAlivePlayers() <= 0 then
			endMatch("All players died")
		end
	end)
end

local function revivePlayer(player, reasonText)
	if not player or not player.Parent then
		return
	end

	local state = getPlayerState(player)
	state.deathToken += 1
	state.alive = false
	state.downed = false
	removeDownedMarker(player)

	sendSurvivalEventToPlayer(player, {
		type = "respawn_clear",
		text = reasonText or "Respawning...",
	})
	sendSurvivalEventToPlayer(player, {
		type = "revive_options_clear",
	})

	safeLoadCharacter(player)

	if wipeState.active and countAlivePlayers() > 0 then
		wipeState.active = false
		wipeState.endsAt = 0
		wipeState.token += 1
		clearReviveOptions()
	end
end

local function canRequestSoloRevive(player)
	if matchState.ended then
		return false
	end

	local state = getPlayerState(player)
	if not state.downed then
		return false
	end

	if wipeState.active then
		return canUseWipeWindow()
	end

	return true
end

local function canRequestTeamRevive(player)
	if matchState.ended then
		return false
	end

	local state = getPlayerState(player)
	if not state.downed then
		return false
	end

	return canUseWipeWindow()
end

local function grantTeamRevive(player)
	if not canRequestTeamRevive(player) then
		return false
	end

	local revivedCount = 0
	for _, target in ipairs(Players:GetPlayers()) do
		local targetState = getPlayerState(target)
		if targetState.downed then
			revivePlayer(target, "Team revive purchased")
			revivedCount += 1
		end
	end

	if revivedCount > 0 then
		broadcastSurvivalEvent({
			type = "match",
			text = ("%s used team revive. Revived %d players."):format(player.Name, revivedCount),
		})
	end
	return revivedCount > 0
end

local function grantSoloRevive(player)
	if not canRequestSoloRevive(player) then
		return false
	end

	revivePlayer(player, "Solo revive purchased")
	broadcastSurvivalEvent({
		type = "match",
		text = ("%s used solo revive."):format(player.Name),
	})
	return true
end

local function promptRevivePurchase(player, kind)
	local productId = kind == "team" and teamReviveProductId or soloReviveProductId

	if RunService:IsStudio() and productId <= 0 then
		if kind == "team" then
			grantTeamRevive(player)
		else
			grantSoloRevive(player)
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

	pendingProductRequests[player.UserId] = {
		kind = kind,
		runId = matchState.runId,
	}

	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[Survival] PromptProductPurchase failed:", err)
	end
end

local function createDownedMarker(player, deathToken, position)
	removeDownedMarker(player)

	local marker = Instance.new("Part")
	marker.Name = ("Downed_%s"):format(player.Name)
	marker.Size = Vector3.new(2.5, 0.6, 2.5)
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(210, 88, 88)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = true
	marker.Position = position + Vector3.new(0, 1, 0)
	marker.Parent = downedFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.Name
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 1.25
	prompt.Parent = marker

	local state = getPlayerState(player)
	state.downedMarker = marker

	prompt.Triggered:Connect(function(reviver)
		if reviver == player or matchState.ended or wipeState.active then
			return
		end

		local currentState = getPlayerState(player)
		if currentState.deathToken ~= deathToken or not currentState.downed then
			return
		end

		local reviverHumanoid = getLiveTargetFromPlayer(reviver)
		if not reviverHumanoid then
			return
		end

		if countAlivePlayers() <= 0 then
			return
		end

		broadcastSurvivalEvent({
			type = "match",
			text = ("%s revived %s."):format(reviver.Name, player.Name),
		})
		revivePlayer(player, "Revived by teammate")
	end)
end

local function handlePlayerDeath(player, character)
	if matchState.ended then
		return
	end

	local state = getPlayerState(player)
	if not state.alive then
		return
	end

	state.alive = false
	state.downed = true
	state.deathCount += 1
	state.deathToken += 1
	local deathToken = state.deathToken
	local runId = matchState.runId

	local deathPosition = startSpawn.Position
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			deathPosition = root.Position
		end
	end

	createDownedMarker(player, deathToken, deathPosition)

	if countAlivePlayers() <= 0 then
		beginWipeWindow()
		return
	end

	local freeRespawnSeconds = getFreeRespawnSecondsForDeath(state.deathCount)
	sendSurvivalEventToPlayer(player, {
		type = "respawn",
		seconds = freeRespawnSeconds,
		mode = "free",
		text = ("You are down. Free respawn in %ds."):format(freeRespawnSeconds),
	})
	sendSurvivalEventToPlayer(player, {
		type = "revive_options",
		canSolo = true,
		canTeam = false,
		soloPrice = soloReviveRobux,
		teamPrice = teamReviveRobux,
		seconds = freeRespawnSeconds,
		wipeOnly = false,
	})

	task.spawn(function()
		for secondsLeft = freeRespawnSeconds, 1, -1 do
			if matchState.runId ~= runId or matchState.ended then
				return
			end

			local currentState = getPlayerState(player)
			if currentState.deathToken ~= deathToken or not currentState.downed then
				return
			end

			if wipeState.active then
				return
			end

			sendSurvivalEventToPlayer(player, {
				type = "respawn",
				seconds = secondsLeft,
				mode = "free",
			})
			task.wait(1)
		end
	end)

	task.delay(freeRespawnSeconds, function()
		if matchState.runId ~= runId or matchState.ended then
			return
		end

		local currentState = getPlayerState(player)
		if currentState.deathToken ~= deathToken or not currentState.downed then
			return
		end

		if wipeState.active then
			return
		end

		revivePlayer(player, "Free respawn")
	end)
end
local function onCharacterAdded(player, character)
	local state = getPlayerState(player)
	state.alive = true
	state.downed = false
	state.deathToken += 1
	removeDownedMarker(player)

	if wipeState.active and countAlivePlayers() > 0 then
		wipeState.active = false
		wipeState.endsAt = 0
		wipeState.token += 1
		clearReviveOptions()
	end

	sendSurvivalEventToPlayer(player, {
		type = "respawn_clear",
		text = "",
	})
	sendSurvivalEventToPlayer(player, {
		type = "revive_options_clear",
	})

	task.defer(function()
		placeCharacterAtStart(character)
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			handlePlayerDeath(player, character)
		end)
	end
end

local function setupPlayer(player)
	local state = getPlayerState(player)
	state.alive = false
	state.downed = false
	state.deathToken += 1
	ensureLeaderstats(player)
	ensureProgression(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	if not matchState.ended then
		task.defer(function()
			safeLoadCharacter(player)
		end)
	end
end

local function cleanupPlayer(player)
	removeDownedMarker(player)
	playerStates[player] = nil
	pendingProductRequests[player.UserId] = nil

	if not matchState.ended and #Players:GetPlayers() > 0 and countAlivePlayers() <= 0 then
		beginWipeWindow()
	end
end

local function spawnZombieFromPoint()
	if matchState.ended or wipeState.active then
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

	local stage = getDifficultyStage()
	local multipliers = getDifficultyMultipliers()
	local partySize = #Players:GetPlayers()
	local maxAlive = math.max(2, zombieConfig.BaseMaxAlive + stage * zombieConfig.MaxAlivePerStage)
	maxAlive *= getEnemyCountPartyMultiplier(partySize)
	maxAlive *= multipliers.enemyCount
	maxAlive = math.max(2, math.floor(maxAlive + 0.5))
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

revivePurchaseEvent.OnServerEvent:Connect(function(player, action)
	if action == "request_solo" then
		if canRequestSoloRevive(player) then
			promptRevivePurchase(player, "solo")
		end
		return
	end

	if action == "request_team" then
		if canRequestTeamRevive(player) then
			promptRevivePurchase(player, "team")
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if processedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local kind = nil
	local pending = pendingProductRequests[receiptInfo.PlayerId]
	if pending and pending.runId == matchState.runId then
		kind = pending.kind
	else
		if receiptInfo.ProductId == soloReviveProductId then
			kind = "solo"
		elseif receiptInfo.ProductId == teamReviveProductId then
			kind = "team"
		end
	end

	if kind == "team" then
		grantTeamRevive(player)
	elseif kind == "solo" then
		grantSoloRevive(player)
	end

	pendingProductRequests[receiptInfo.PlayerId] = nil
	processedReceipts[purchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

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

task.spawn(function()
	while true do
		if matchState.ended then
			task.wait(0.25)
		else
			local now = os.clock()
			if matchState.waveActive and not wipeState.active and matchState.waveSpawnsRemaining > 0 then
				if now >= matchState.nextSpawnAt then
					spawnZombieFromPoint()
					matchState.nextSpawnAt = now + getWaveSpawnInterval()
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

	local stage = getDifficultyStage()
	if stage ~= lastStageAttribute then
		lastStageAttribute = stage
		Workspace:SetAttribute("SurvivalStage", stage)
	end

	for zombie, state in pairs(zombieStates) do
		local humanoid = state.humanoid
		local root = state.root

		if not zombie.Parent or not humanoid or humanoid.Health <= 0 or not root or not root.Parent then
			zombieStates[zombie] = nil
		else
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
					continue
				end

				if state.isSpitter and distance <= state.spitRange and now - state.lastSpit >= state.spitCooldown then
					state.lastSpit = now
					spawnSpitProjectile(state, targetRoot.Position + Vector3.new(0, 1.4, 0))
				end

				if movementDistance > state.attackRange then
					local maxStep = state.moveSpeed * deltaTime
					local step = math.min(maxStep, movementDistance - state.attackRange * 0.55)
					if step > 0 then
						local newPos = root.Position + forward * step
						zombie:PivotTo(CFrame.lookAt(newPos, newPos + lookForward))
					else
						zombie:PivotTo(CFrame.lookAt(root.Position, root.Position + lookForward))
					end
				else
					zombie:PivotTo(CFrame.lookAt(root.Position, root.Position + lookForward))
					if now - state.lastAttack >= state.attackCooldown then
						state.lastAttack = now
						targetHumanoid:TakeDamage(state.attackDamage)
					end
				end
			end
		end
	end
end)
