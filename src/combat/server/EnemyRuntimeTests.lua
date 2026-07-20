local EnemyRuntime = require(script.Parent:WaitForChild("EnemyRuntime"))

local EnemyRuntimeTests = {}

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

local function createEnemy(folder, name, position)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = model

	return model, {
		humanoid = humanoid,
		root = root,
		dead = false,
	}
end

function EnemyRuntimeTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, epsilon, label)
		expectNear(actual, expected, epsilon, label)
		assertions += 1
	end

	local enemyFolder = Instance.new("Folder")
	local spawnFolder = Instance.new("Folder")
	local cleanupCount = 0
	local playerNear = { Name = "Near" }
	local playerFar = { Name = "Far" }
	local nearHumanoid = Instance.new("Humanoid")
	local farHumanoid = Instance.new("Humanoid")
	local nearRoot = Instance.new("Part")
	nearRoot.Position = Vector3.new(3, 0, 4)
	local farRoot = Instance.new("Part")
	farRoot.Position = Vector3.new(30, 0, 0)
	local targets = {
		[playerNear] = { nearHumanoid, nearRoot },
		[playerFar] = { farHumanoid, farRoot },
	}
	local randomIndexes = { 1, 2 }
	local randomCursor = 0

	local runtime = EnemyRuntime.new({
		folder = enemyFolder,
		spawnPointsFolder = spawnFolder,
		minSpawnDistance = 10,
		getPlayers = function()
			return { playerFar, playerNear }
		end,
		getLiveTarget = function(player)
			local target = targets[player]
			return target and target[1], target and target[2]
		end,
		cleanupState = function()
			cleanupCount += 1
		end,
		randomIndex = function()
			randomCursor += 1
			return randomIndexes[randomCursor] or 2
		end,
	})

	local firstModel, firstState = createEnemy(enemyFolder, "First", Vector3.new())
	local secondModel, secondState = createEnemy(enemyFolder, "Second", Vector3.new(10, 0, 0))
	runtime:Register(firstModel, firstState)
	runtime:Register(secondModel, secondState)

	equal(runtime:GetRegisteredCount(), 2, "registered count")
	equal(runtime:CountAlive(), 2, "alive count")
	equal(runtime:GetState(firstModel), firstState, "registered state")

	local nearestPlayer, nearestHumanoid, nearestRootResult, nearestDistance = runtime:GetNearestTarget(Vector3.new())
	equal(nearestPlayer, playerNear, "nearest player")
	equal(nearestHumanoid, nearHumanoid, "nearest humanoid")
	equal(nearestRootResult, nearRoot, "nearest root")
	near(nearestDistance, 5, 0.000001, "nearest distance")

	firstState.humanoid.Health = 0
	equal(runtime:CountAlive(), 1, "dead state pruned")
	equal(runtime:GetState(firstModel), nil, "dead state removed")
	equal(cleanupCount, 1, "dead state cleanup")

	local nearPoint = Instance.new("Part")
	nearPoint.Name = "NearPoint"
	nearPoint.Position = Vector3.new(4, 0, 0)
	nearPoint.Parent = spawnFolder
	local farPoint = Instance.new("Part")
	farPoint.Name = "FarPoint"
	farPoint.Position = Vector3.new(40, 0, 0)
	farPoint.Parent = spawnFolder
	equal(runtime:GetRandomSpawnPoint(), farPoint, "safe spawn point selected")

	local visited = 0
	runtime:ForEachAlive(function(model, state)
		visited += 1
		equal(model, secondModel, "alive iteration model")
		equal(state, secondState, "alive iteration state")
	end)
	equal(visited, 1, "alive iteration count")

	local orphan = Instance.new("Part")
	orphan.Parent = enemyFolder
	equal(runtime:ClearAll(), 1, "clear registered count")
	equal(runtime:GetRegisteredCount(), 0, "registry cleared")
	equal(#enemyFolder:GetChildren(), 0, "enemy folder cleared")
	equal(cleanupCount, 2, "clear cleanup")

	enemyFolder:Destroy()
	spawnFolder:Destroy()
	nearHumanoid:Destroy()
	farHumanoid:Destroy()
	nearRoot:Destroy()
	farRoot:Destroy()

	return assertions
end

return EnemyRuntimeTests
