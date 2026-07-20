local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameRules = require(sharedFolder:WaitForChild("GameRules"))

local ReviveRuntime = {}
ReviveRuntime.__index = ReviveRuntime

local function noOp() end

function ReviveRuntime.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, ReviveRuntime)
	self.config = assert(options.config, "ReviveRuntime requires config")
	self.downedFolder = assert(options.downedFolder, "ReviveRuntime requires a downed folder")
	self.startSpawn = assert(options.startSpawn, "ReviveRuntime requires a start spawn")
	self.getPlayers = assert(options.getPlayers, "ReviveRuntime requires getPlayers")
	self.isMatchEnded = assert(options.isMatchEnded, "ReviveRuntime requires isMatchEnded")
	self.getRunId = assert(options.getRunId, "ReviveRuntime requires getRunId")
	self.endMatch = assert(options.endMatch, "ReviveRuntime requires endMatch")
	self.safeLoadCharacter = assert(options.safeLoadCharacter, "ReviveRuntime requires safeLoadCharacter")
	self.sendToPlayer = options.sendToPlayer or noOp
	self.broadcast = options.broadcast or noOp
	self.restoreWaveState = options.restoreWaveState or noOp
	self.onCharacterReady = options.onCharacterReady or noOp
	self.clock = options.clock or os.clock
	self.spawnTask = options.spawnTask or task.spawn
	self.delayTask = options.delayTask or task.delay
	self.waitTask = options.waitTask or task.wait
	self.soloPrice = math.max(0, math.floor(tonumber(options.soloPrice) or 10))
	self.teamPrice = math.max(0, math.floor(tonumber(options.teamPrice) or 50))
	self.states = {}
	self.wipe = { active = false, token = 0, endsAt = 0 }
	return self
end

function ReviveRuntime:GetState(player)
	local state = self.states[player]
	if state then
		return state
	end

	state = {
		alive = false,
		downed = false,
		deathToken = 0,
		deathCount = 0,
		downedMarker = nil,
		runsCountedRunId = 0,
	}
	self.states[player] = state
	return state
end

function ReviveRuntime:GetLiveTarget(player)
	local state = self.states[player]
	if not state or not state.alive or state.downed then
		return nil, nil
	end

	local character = player and player.Character
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

function ReviveRuntime:CountAlivePlayers()
	local count = 0
	for _, player in ipairs(self.getPlayers()) do
		if self:GetLiveTarget(player) then
			count += 1
		end
	end
	return count
end

function ReviveRuntime:GetFreeRespawnSeconds(deathCount)
	local base = tonumber(self.config.FreeRespawnBaseSeconds) or 10
	local increment = tonumber(self.config.FreeRespawnIncrementSeconds) or 10
	return gameRules.GetFreeRespawnSeconds(deathCount, base, increment)
end

function ReviveRuntime:RemoveDownedMarker(player)
	local state = self:GetState(player)
	if state.downedMarker and state.downedMarker.Parent then
		state.downedMarker:Destroy()
	end
	state.downedMarker = nil
end

function ReviveRuntime:ClearAllDownedMarkers()
	for _, player in ipairs(self.getPlayers()) do
		self:RemoveDownedMarker(player)
	end
	for _, child in ipairs(self.downedFolder:GetChildren()) do
		child:Destroy()
	end
end

function ReviveRuntime:ClearOptions()
	self.broadcast({ type = "revive_options_clear" })
end

function ReviveRuntime:CancelWipe()
	local wasActive = self.wipe.active
	self.wipe.active = false
	self.wipe.endsAt = 0
	self.wipe.token += 1
	return wasActive
end

function ReviveRuntime:IsWipeActive()
	return self.wipe.active
end

function ReviveRuntime:CanUseWipeWindow()
	return self.wipe.active and self.clock() <= self.wipe.endsAt
end

function ReviveRuntime:IsWipeTokenCurrent(token)
	return self.wipe.active and self.wipe.token == token
end

function ReviveRuntime:ResetRun()
	self:CancelWipe()
	self:ClearAllDownedMarkers()
	self:ClearOptions()
	for _, player in ipairs(self.getPlayers()) do
		local state = self:GetState(player)
		state.alive = false
		state.downed = false
		state.deathCount = 0
		state.deathToken += 1
		state.runsCountedRunId = 0
	end
end

function ReviveRuntime:EndRun()
	self:CancelWipe()
	self:ClearAllDownedMarkers()
	for _, state in pairs(self.states) do
		state.alive = false
		state.downed = false
		state.deathToken += 1
	end
end

function ReviveRuntime:PreparePlayer(player)
	local state = self:GetState(player)
	state.alive = false
	state.downed = false
	state.deathToken += 1
	return state
end

function ReviveRuntime:IsDeathCurrent(player, deathToken)
	local state = self.states[player]
	return state ~= nil and state.deathToken == deathToken and state.downed
end

function ReviveRuntime:_cancelWipeIfTeamAlive()
	if not self.wipe.active or self:CountAlivePlayers() <= 0 then
		return false
	end

	self:CancelWipe()
	self:ClearOptions()
	self.restoreWaveState()
	return true
end

function ReviveRuntime:BeginWipeWindow()
	if self.wipe.active or self.isMatchEnded() then
		return false
	end

	local duration = math.max(1, math.floor(tonumber(self.config.WipePurchaseWindowSeconds) or 30))
	self.wipe.active = true
	self.wipe.token += 1
	self.wipe.endsAt = self.clock() + duration
	local wipeToken = self.wipe.token

	self.restoreWaveState("WipeWindow")
	self.broadcast({
		type = "match",
		text = ("All players are down. Buy revive in %ds or run ends."):format(duration),
	})
	self.broadcast({
		type = "revive_options",
		canSolo = true,
		canTeam = true,
		soloPrice = self.soloPrice,
		teamPrice = self.teamPrice,
		seconds = duration,
		wipeOnly = true,
	})

	self.spawnTask(function()
		for secondsLeft = duration, 1, -1 do
			if self.isMatchEnded() or not self:IsWipeTokenCurrent(wipeToken) then
				return
			end
			self.broadcast({
				type = "wipe_timer",
				seconds = secondsLeft,
				text = ("Team wipe. Buy revive in %ds."):format(secondsLeft),
			})
			self.waitTask(1)
		end

		if self.isMatchEnded() or not self:IsWipeTokenCurrent(wipeToken) then
			return
		end
		if self:CountAlivePlayers() <= 0 then
			self.endMatch("All players died")
		end
	end)
	return true
end

function ReviveRuntime:RevivePlayer(player, reasonText)
	if not player or not player.Parent then
		return false
	end

	local state = self:GetState(player)
	if not state.downed then
		return false
	end

	state.deathToken += 1
	state.alive = false
	state.downed = false
	self:RemoveDownedMarker(player)
	self.sendToPlayer(player, { type = "respawn_clear", text = reasonText or "Respawning..." })
	self.sendToPlayer(player, { type = "revive_options_clear" })
	self.safeLoadCharacter(player)
	self:_cancelWipeIfTeamAlive()
	return true
end

function ReviveRuntime:CanRequestSoloRevive(player)
	if self.isMatchEnded() then
		return false
	end
	local state = self:GetState(player)
	if not state.downed then
		return false
	end
	return not self.wipe.active or self:CanUseWipeWindow()
end

function ReviveRuntime:CanRequestTeamRevive(player)
	if self.isMatchEnded() then
		return false
	end
	local state = self:GetState(player)
	return state.downed and self:CanUseWipeWindow()
end

function ReviveRuntime:GrantTeamRevive(player)
	if not self:CanRequestTeamRevive(player) then
		return false
	end

	local revivedCount = 0
	for _, target in ipairs(self.getPlayers()) do
		if self:GetState(target).downed and self:RevivePlayer(target, "Team revive purchased") then
			revivedCount += 1
		end
	end
	if revivedCount > 0 then
		self.broadcast({
			type = "match",
			text = ("%s used team revive. Revived %d players."):format(player.Name, revivedCount),
		})
	end
	return revivedCount > 0
end

function ReviveRuntime:GrantSoloRevive(player)
	if not self:CanRequestSoloRevive(player) or not self:RevivePlayer(player, "Solo revive purchased") then
		return false
	end
	self.broadcast({ type = "match", text = ("%s used solo revive."):format(player.Name) })
	return true
end

function ReviveRuntime:TryTeammateRevive(reviver, targetPlayer, deathToken)
	if reviver == targetPlayer or self.isMatchEnded() or self.wipe.active then
		return false
	end
	if deathToken and not self:IsDeathCurrent(targetPlayer, deathToken) then
		return false
	end
	if not self:GetLiveTarget(reviver) or self:CountAlivePlayers() <= 0 then
		return false
	end

	self.broadcast({
		type = "match",
		text = ("%s revived %s."):format(reviver.Name, targetPlayer.Name),
	})
	return self:RevivePlayer(targetPlayer, "Revived by teammate")
end

function ReviveRuntime:CreateDownedMarker(player, deathToken, position)
	self:RemoveDownedMarker(player)

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
	marker.Parent = self.downedFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.Name
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 1.25
	prompt.Parent = marker

	self:GetState(player).downedMarker = marker
	prompt.Triggered:Connect(function(reviver)
		self:TryTeammateRevive(reviver, player, deathToken)
	end)
	return marker
end

function ReviveRuntime:HandlePlayerDeath(player, character)
	if self.isMatchEnded() then
		return false
	end

	local state = self:GetState(player)
	if not state.alive then
		return false
	end
	state.alive = false
	state.downed = true
	state.deathCount += 1
	state.deathToken += 1
	local deathToken = state.deathToken
	local runId = self.getRunId()

	local deathPosition = self.startSpawn.Position
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			deathPosition = root.Position
		end
	end
	self:CreateDownedMarker(player, deathToken, deathPosition)

	if self:CountAlivePlayers() <= 0 then
		self:BeginWipeWindow()
		return true
	end

	local seconds = self:GetFreeRespawnSeconds(state.deathCount)
	self.sendToPlayer(player, {
		type = "respawn",
		seconds = seconds,
		mode = "free",
		text = ("You are down. Free respawn in %ds."):format(seconds),
	})
	self.sendToPlayer(player, {
		type = "revive_options",
		canSolo = true,
		canTeam = false,
		soloPrice = self.soloPrice,
		teamPrice = self.teamPrice,
		seconds = seconds,
		wipeOnly = false,
	})

	self.spawnTask(function()
		for secondsLeft = seconds, 1, -1 do
			if self.getRunId() ~= runId or self.isMatchEnded() or not self:IsDeathCurrent(player, deathToken) then
				return
			end
			if self.wipe.active then
				return
			end
			self.sendToPlayer(player, { type = "respawn", seconds = secondsLeft, mode = "free" })
			self.waitTask(1)
		end
	end)

	self.delayTask(seconds, function()
		if self.getRunId() ~= runId or self.isMatchEnded() or not self:IsDeathCurrent(player, deathToken) then
			return
		end
		if not self.wipe.active then
			self:RevivePlayer(player, "Free respawn")
		end
	end)
	return true
end

function ReviveRuntime:OnCharacterAdded(player, character)
	local state = self:GetState(player)
	state.alive = true
	state.downed = false
	state.deathToken += 1
	self:RemoveDownedMarker(player)
	self.onCharacterReady(player, character)
	self:_cancelWipeIfTeamAlive()
	self.sendToPlayer(player, { type = "respawn_clear", text = "" })
	self.sendToPlayer(player, { type = "revive_options_clear" })

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			self:HandlePlayerDeath(player, character)
		end)
	end
	return state
end

function ReviveRuntime:CleanupPlayer(player)
	self:RemoveDownedMarker(player)
	self.states[player] = nil
	if not self.isMatchEnded() and #self.getPlayers() > 0 and self:CountAlivePlayers() <= 0 then
		self:BeginWipeWindow()
	end
end

return ReviveRuntime
