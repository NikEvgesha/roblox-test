local EnemyFactory = require(script.Parent:WaitForChild("EnemyFactory"))

local EnemyFactoryTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local function expectNear(actual, expected, epsilon, label)
	if math.abs(actual - expected) > epsilon then
		error(("%s: expected %.6f, got %.6f"):format(label, expected, actual), 2)
	end
end

function EnemyFactoryTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, epsilon, label)
		expectNear(actual, expected, epsilon, label)
		assertions += 1
	end

	local previousRoot = workspace:FindFirstChild("EnemyFactoryTests")
	if previousRoot then
		previousRoot:Destroy()
	end
	local searchRoot = Instance.new("Folder")
	searchRoot.Name = "EnemyFactoryTests"
	searchRoot.Parent = workspace
	local enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "RuntimeEnemies"
	enemyFolder.Parent = searchRoot
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Parent = searchRoot
	local downedFolder = Instance.new("Folder")
	downedFolder.Parent = searchRoot
	local assetsFolder = Instance.new("Folder")
	assetsFolder.Name = "Enemy"
	assetsFolder.Parent = searchRoot

	local template = Instance.new("Model")
	template.Name = "EnemyFactoryTestTemplate"
	local templateHumanoid = Instance.new("Humanoid")
	templateHumanoid.Parent = template
	local templateBody = Instance.new("Part")
	templateBody.Name = "Body"
	templateBody.Parent = template
	template.PrimaryPart = templateBody
	local templateHead = Instance.new("Part")
	templateHead.Name = "Head"
	templateHead.Parent = template
	template.Parent = assetsFolder

	local config = {
		BaseHealth = 100,
		HealthScalePerStage = 0.1,
		BaseMoveSpeed = 10,
		SpeedScalePerStage = 0.05,
		BaseAttackDamage = 20,
		DamageScalePerStage = 0.1,
		BaseRewardMoney = 5,
		BaseRewardXP = 7,
		RewardScalePerStage = 0.2,
		BaseAttackRange = 4,
		BaseAttackCooldown = 1.5,
	}
	local variants = {
		Walker = {
			DisplayName = "Test Walker",
			HealthMul = 1,
			MoveSpeedMul = 1,
			DamageMul = 1,
			RewardMul = 1,
			Color = { 10, 20, 30 },
			HeadColor = { 40, 50, 60 },
		},
		Template = {
			DisplayName = "Template Enemy",
			TemplateModelName = "EnemyFactoryTestTemplate",
			HealthMul = 0.5,
			MoveSpeedMul = 1.5,
			DamageMul = 2,
			RewardMul = 3,
			BossCrystalDrop = 2,
			IsBoss = true,
		},
	}
	local registry = {}
	local createdCount = 0
	local killedCount = 0
	local removedCount = 0
	local sanitizedCount = 0

	local factory = EnemyFactory.new({
		config = config,
		variants = variants,
		enemyFolder = enemyFolder,
		spawnPointsFolder = spawnFolder,
		downedFolder = downedFolder,
		templateSearchRoot = searchRoot,
		templateAssetsFolder = assetsFolder,
		getDifficultyMultipliers = function()
			return { health = 2, damage = 3, reward = 4, crystal = 5 }
		end,
		resolveGroundY = function(position)
			return position.Y
		end,
		sanitizeTemplateContent = function()
			sanitizedCount += 1
		end,
		onCreated = function(model, state)
			createdCount += 1
			registry[model] = state
		end,
		onKilled = function()
			killedCount += 1
		end,
		onRemoved = function(model)
			removedCount += 1
			registry[model] = nil
		end,
		schedule = function(_, callback)
			callback()
		end,
	})

	local fallbackModel, fallbackState = factory:Create(Vector3.new(1, 10, 2), "Missing", 2)
	equal(fallbackModel.Name, "Zombie_Walker", "fallback model name")
	equal(fallbackModel.Parent, enemyFolder, "fallback parent")
	equal(fallbackModel:GetAttribute("IsZombie"), true, "fallback zombie attribute")
	equal(fallbackState.variantKey, "Walker", "fallback variant key")
	near(fallbackState.humanoid.MaxHealth, 240, 0.000001, "scaled health")
	near(fallbackState.moveSpeed, 11, 0.000001, "scaled move speed")
	near(fallbackState.attackDamage, 72, 0.000001, "scaled attack damage")
	near(fallbackState.rewardMoney, 28, 0.000001, "scaled money")
	near(fallbackState.rewardXP, 39.2, 0.000001, "scaled xp")
	equal(fallbackState.attackRange, 4, "attack range")
	equal(fallbackModel:FindFirstChild("ZombieHealthGui") ~= nil, true, "health bar created")
	equal(registry[fallbackModel], fallbackState, "fallback registered")
	equal(createdCount, 1, "fallback create callback")
	equal(fallbackModel.Torso.Color, Color3.fromRGB(10, 20, 30), "fallback torso color")
	equal(fallbackModel.Head.Color, Color3.fromRGB(40, 50, 60), "fallback head color")

	equal(factory:Kill(fallbackModel), true, "explicit kill accepted")
	equal(fallbackState.dead, true, "death state")
	equal(killedCount, 1, "kill callback")
	equal(removedCount, 1, "death remove callback")
	equal(registry[fallbackModel], nil, "death unregister")
	equal(fallbackModel.Parent, nil, "scheduled destroy")
	equal(factory:Kill(fallbackModel), false, "duplicate kill rejected")

	local templateModel, templateState = factory:Create(Vector3.new(5, 20, 6), "Template", 0)
	equal(templateModel ~= template, true, "template cloned")
	equal(templateModel.Parent, enemyFolder, "template parent")
	equal(templateModel:GetAttribute("ZombieVariant"), "Template", "template variant attribute")
	equal(templateModel:FindFirstChild("HumanoidRootPart") ~= nil, true, "synthetic root created")
	equal(templateState.isBoss, true, "boss state")
	equal(templateModel:GetAttribute("IsBossZombie"), true, "boss attribute")
	near(templateState.humanoid.MaxHealth, 100, 0.000001, "template health")
	near(templateState.moveSpeed, 15, 0.000001, "template move speed")
	near(templateState.bossCrystals, 10, 0.000001, "template crystal reward")
	equal(sanitizedCount, 1, "template sanitized")
	equal(createdCount, 2, "template create callback")

	equal(factory:Remove(templateModel), true, "explicit remove accepted")
	templateModel:Destroy()
	equal(removedCount, 2, "explicit remove callback")
	equal(killedCount, 1, "remove is not kill")
	equal(registry[templateModel], nil, "explicit unregister")
	equal(factory:Remove(templateModel), false, "duplicate remove rejected")

	local stopped = 0
	local destroyed = 0
	local fakeTrack = {
		Stop = function()
			stopped += 1
		end,
		Destroy = function()
			destroyed += 1
		end,
	}
	local cleanupState = { animationTracks = { idle = fakeTrack } }
	factory:CleanupAnimationTracks(cleanupState)
	equal(stopped, 1, "animation stopped")
	equal(destroyed, 1, "animation destroyed")
	equal(cleanupState.animationTracks, nil, "animation state cleared")

	searchRoot:Destroy()
	return assertions
end

return EnemyFactoryTests
