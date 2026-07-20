local ReviveRuntime = require(script.Parent:WaitForChild("ReviveRuntime"))

local ReviveRuntimeTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local function createCharacter(position)
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = character
	return character
end

function ReviveRuntimeTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local previousRoot = workspace:FindFirstChild("ReviveRuntimeTests")
	if previousRoot then
		previousRoot:Destroy()
	end
	local testRoot = Instance.new("Folder")
	testRoot.Name = "ReviveRuntimeTests"
	testRoot.Parent = workspace
	local downedFolder = Instance.new("Folder")
	downedFolder.Parent = testRoot
	local startSpawn = Instance.new("Part")
	startSpawn.Position = Vector3.new(0, 5, 0)
	startSpawn.Parent = testRoot

	local playerOne = { Name = "One", Parent = true, Character = createCharacter(Vector3.new(10, 5, 0)) }
	local playerTwo = { Name = "Two", Parent = true, Character = createCharacter(Vector3.new(20, 5, 0)) }
	local players = { playerOne, playerTwo }
	local currentTime = 100
	local runId = 7
	local matchEnded = false
	local endedReason = nil
	local sent = {}
	local broadcasts = {}
	local restoreStates = {}
	local spawnedTasks = {}
	local delayedTasks = {}
	local characterReadyCount = 0
	local loadCount = 0
	local runtime

	runtime = ReviveRuntime.new({
		config = {
			FreeRespawnBaseSeconds = 10,
			FreeRespawnIncrementSeconds = 10,
			WipePurchaseWindowSeconds = 30,
		},
		downedFolder = downedFolder,
		startSpawn = startSpawn,
		getPlayers = function()
			return players
		end,
		isMatchEnded = function()
			return matchEnded
		end,
		getRunId = function()
			return runId
		end,
		endMatch = function(reason)
			matchEnded = true
			endedReason = reason
		end,
		safeLoadCharacter = function(player)
			loadCount += 1
			runtime:OnCharacterAdded(player, player.Character)
		end,
		sendToPlayer = function(player, payload)
			table.insert(sent, { player = player, payload = payload })
		end,
		broadcast = function(payload)
			table.insert(broadcasts, payload)
		end,
		restoreWaveState = function(state)
			table.insert(restoreStates, state or "Active")
		end,
		onCharacterReady = function()
			characterReadyCount += 1
		end,
		clock = function()
			return currentTime
		end,
		spawnTask = function(callback)
			table.insert(spawnedTasks, callback)
		end,
		delayTask = function(seconds, callback)
			table.insert(delayedTasks, { seconds = seconds, callback = callback })
		end,
		waitTask = function(seconds)
			currentTime += seconds
		end,
		soloPrice = 10,
		teamPrice = 50,
	})

	runtime:PreparePlayer(playerOne)
	runtime:PreparePlayer(playerTwo)
	runtime:OnCharacterAdded(playerOne, playerOne.Character)
	runtime:OnCharacterAdded(playerTwo, playerTwo.Character)
	equal(runtime:CountAlivePlayers(), 2, "initial alive count")
	equal(characterReadyCount, 2, "character ready callbacks")
	equal(runtime:GetFreeRespawnSeconds(1), 10, "first respawn seconds")
	equal(runtime:GetFreeRespawnSeconds(2), 20, "second respawn seconds")

	equal(runtime:HandlePlayerDeath(playerOne, playerOne.Character), true, "first death accepted")
	local firstState = runtime:GetState(playerOne)
	equal(firstState.alive, false, "first death not alive")
	equal(firstState.downed, true, "first death downed")
	equal(firstState.deathCount, 1, "first death count")
	equal(firstState.downedMarker.Parent, downedFolder, "downed marker parent")
	equal(runtime:CountAlivePlayers(), 1, "one teammate alive")
	equal(runtime:CanRequestSoloRevive(playerOne), true, "solo revive available")
	equal(runtime:CanRequestTeamRevive(playerOne), false, "team revive unavailable before wipe")
	equal(delayedTasks[1].seconds, 10, "first free delay")
	equal(#spawnedTasks, 1, "first timer task")
	local firstDeathToken = firstState.deathToken

	equal(runtime:TryTeammateRevive(playerTwo, playerOne, firstDeathToken), true, "teammate revive")
	equal(runtime:GetState(playerOne).downed, false, "teammate clears downed")
	equal(runtime:CountAlivePlayers(), 2, "teammate revive alive count")
	equal(loadCount, 1, "teammate revive loads character")
	equal(runtime:IsDeathCurrent(playerOne, firstDeathToken), false, "old death token invalid")
	delayedTasks[1].callback()
	equal(loadCount, 1, "stale free timer ignored")

	equal(runtime:HandlePlayerDeath(playerOne, playerOne.Character), true, "second death accepted")
	equal(runtime:GetState(playerOne).deathCount, 2, "second death count")
	equal(delayedTasks[2].seconds, 20, "second free delay")
	equal(runtime:HandlePlayerDeath(playerTwo, playerTwo.Character), true, "team wipe death accepted")
	equal(runtime:IsWipeActive(), true, "wipe active")
	equal(runtime:CanUseWipeWindow(), true, "wipe window valid")
	equal(runtime:CanRequestSoloRevive(playerTwo), true, "wipe solo available")
	equal(runtime:CanRequestTeamRevive(playerTwo), true, "wipe team available")
	equal(restoreStates[#restoreStates], "WipeWindow", "wipe wave state")
	equal(#spawnedTasks, 3, "wipe timer task")

	equal(runtime:GrantTeamRevive(playerTwo), true, "team revive granted")
	equal(runtime:CountAlivePlayers(), 2, "team revive alive count")
	equal(runtime:IsWipeActive(), false, "team revive cancels wipe")
	equal(runtime:GetState(playerOne).downed, false, "team revive player one")
	equal(runtime:GetState(playerTwo).downed, false, "team revive player two")
	equal(restoreStates[#restoreStates], "Active", "wave state restored")
	equal(runtime:GrantTeamRevive(playerTwo), false, "duplicate team revive rejected")

	runtime:ResetRun()
	equal(runtime:GetState(playerOne).deathCount, 0, "run resets death count")
	equal(runtime:CountAlivePlayers(), 0, "run reset alive count")
	equal(#downedFolder:GetChildren(), 0, "run clears markers")
	runtime:OnCharacterAdded(playerOne, playerOne.Character)
	runtime:OnCharacterAdded(playerTwo, playerTwo.Character)
	runtime:HandlePlayerDeath(playerOne, playerOne.Character)
	runtime:HandlePlayerDeath(playerTwo, playerTwo.Character)
	equal(runtime:IsWipeActive(), true, "second wipe active")

	local wipeTimer = spawnedTasks[#spawnedTasks]
	wipeTimer()
	equal(matchEnded, true, "wipe timeout ends match")
	equal(endedReason, "All players died", "wipe timeout reason")
	equal(runtime:CanRequestSoloRevive(playerOne), false, "revive blocked after match end")

	runtime:EndRun()
	equal(runtime:IsWipeActive(), false, "end run cancels wipe")
	equal(runtime:GetState(playerOne).downed, false, "end run clears downed")
	runtime:CleanupPlayer(playerOne)
	equal(runtime.states[playerOne], nil, "cleanup removes player state")

	playerOne.Character:Destroy()
	playerTwo.Character:Destroy()
	testRoot:Destroy()
	return assertions
end

return ReviveRuntimeTests
