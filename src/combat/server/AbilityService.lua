local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local abilityConfig = require(sharedFolder:WaitForChild("AbilityConfig"))

local AbilityService = {}

local STATE_SEND_INTERVAL = 0.2
local implementedAbilities = {
	Shield = true,
	RageHeal = true,
	UndyingRage = true,
}

local abilityEvent = nil
local started = false
local stateByPlayer = {}
local connectionsByPlayer = {}

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

local function disconnectPlayerConnections(player)
	local connections = connectionsByPlayer[player]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connectionsByPlayer[player] = nil
end

local function trackConnection(player, connection)
	if not connectionsByPlayer[player] then
		connectionsByPlayer[player] = {}
	end
	table.insert(connectionsByPlayer[player], connection)
end

local function resolveProfessionKey(player)
	local attributeValue = player:GetAttribute("SelectedClass")
	if type(attributeValue) == "string" and attributeValue ~= "" then
		return abilityConfig.NormalizeProfessionKey(attributeValue)
	end

	local metaProgression = player:FindFirstChild("MetaProgression")
	local selectedClass = metaProgression and metaProgression:FindFirstChild("SelectedClass")
	if selectedClass and selectedClass:IsA("StringValue") then
		return abilityConfig.NormalizeProfessionKey(selectedClass.Value)
	end

	return abilityConfig.DefaultProfession
end

local function buildUnlockedAbilities(profession)
	local unlocked = {}
	for _, abilityKey in ipairs(profession.AbilityOrder or {}) do
		unlocked[abilityKey] = true
	end
	return unlocked
end

local function createState(player, professionKey)
	local profession, normalizedKey = abilityConfig.GetProfession(professionKey)
	local resourceConfig = profession.Resource or {}
	local maxResource = tonumber(resourceConfig.Max) or 0
	local startResource = resourceConfig.StartFull == false and 0 or maxResource

	return {
		player = player,
		professionKey = normalizedKey,
		resourceKey = tostring(resourceConfig.Key or ""),
		resourceDisplayName = tostring(resourceConfig.DisplayName or resourceConfig.Key or ""),
		resource = startResource,
		maxResource = maxResource,
		stanceKey = abilityConfig.GetDefaultStance(normalizedKey),
		unlockedAbilities = buildUnlockedAbilities(profession),
		abilityRanks = {},
		cooldowns = {},
		auraEnabled = {},
		shield = 0,
		shieldExpiresAt = 0,
		immortalUntil = 0,
		lastCombatAt = os.clock(),
		dirty = true,
		nextSendAt = 0,
		message = "",
	}
end

local function getState(player)
	local state = stateByPlayer[player]
	if state then
		return state
	end

	state = createState(player, resolveProfessionKey(player))
	stateByPlayer[player] = state
	return state
end

local function setStateMessage(state, message)
	state.message = message or ""
	state.dirty = true
	state.nextSendAt = 0
end

local function setProfession(player, professionKey)
	local oldState = getState(player)
	local normalizedKey = abilityConfig.NormalizeProfessionKey(professionKey)
	if oldState.professionKey == normalizedKey then
		return oldState
	end

	local newState = createState(player, normalizedKey)
	stateByPlayer[player] = newState
	player:SetAttribute("ProfessionKey", normalizedKey)
	player:SetAttribute("ProfessionResourceName", newState.resourceDisplayName)
	player:SetAttribute("ProfessionStance", newState.stanceKey)
	local profession = select(1, abilityConfig.GetProfession(normalizedKey))
	setStateMessage(newState, ("Profession: %s"):format((profession and profession.DisplayName) or normalizedKey))
	return newState
end

local function clampResource(state)
	state.maxResource = math.max(0, tonumber(state.maxResource) or 0)
	state.resource = math.clamp(tonumber(state.resource) or 0, 0, state.maxResource)
end

local function addResource(state, amount)
	local delta = tonumber(amount) or 0
	if delta == 0 or state.maxResource <= 0 then
		return
	end

	local before = state.resource
	state.resource = math.clamp(state.resource + delta, 0, state.maxResource)
	if math.abs(state.resource - before) > 0.001 then
		state.dirty = true
	end
end

local function spendResource(state, amount)
	local cost = math.max(0, tonumber(amount) or 0)
	if cost <= 0 then
		return true
	end

	if state.resource + 0.001 < cost then
		return false
	end

	state.resource -= cost
	state.lastCombatAt = os.clock()
	state.dirty = true
	return true
end

local function getCooldownRemaining(state, abilityKey, now)
	local endsAt = tonumber(state.cooldowns[abilityKey]) or 0
	return math.max(0, endsAt - (now or os.clock()))
end

local function buildAbilityPayload(state, profession)
	local abilities = {}
	for _, abilityKey in ipairs(profession.AbilityOrder or {}) do
		local ability = profession.Abilities and profession.Abilities[abilityKey]
		if ability then
			table.insert(abilities, {
				key = abilityKey,
				displayName = ability.DisplayName or abilityKey,
				type = ability.Type or "Passive",
				description = ability.Description or "",
				cost = ability.Cost,
				costPerSecond = ability.CostPerSecond,
				cooldown = ability.Cooldown or 0,
				cooldownRemaining = getCooldownRemaining(state, abilityKey),
				unlocked = state.unlockedAbilities[abilityKey] == true,
				rank = state.abilityRanks[abilityKey] or 0,
				active = state.auraEnabled[abilityKey] == true,
			})
		end
	end
	return abilities
end

local function buildStancePayload(state, profession)
	local stances = {}
	for _, stanceKey in ipairs(profession.StanceOrder or {}) do
		local stance = profession.Stances and profession.Stances[stanceKey]
		if stance then
			table.insert(stances, {
				key = stanceKey,
				displayName = stance.DisplayName or stanceKey,
				weaponKey = stance.WeaponKey or "",
				resourceCostPerShot = stance.ResourceCostPerShot or 0,
				active = stanceKey == state.stanceKey,
			})
		end
	end
	return stances
end

local function buildStatePayload(state)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	clampResource(state)

	return {
		type = "state",
		professionKey = state.professionKey,
		professionDisplayName = profession.DisplayName or state.professionKey,
		resourceKey = state.resourceKey,
		resourceDisplayName = state.resourceDisplayName,
		resource = state.resource,
		maxResource = state.maxResource,
		stanceKey = state.stanceKey,
		stances = buildStancePayload(state, profession),
		abilities = buildAbilityPayload(state, profession),
		shield = state.shield,
		immortalRemaining = math.max(0, state.immortalUntil - os.clock()),
		message = state.message or "",
	}
end

local function sendState(player, force)
	if not abilityEvent then
		return
	end

	local state = getState(player)
	local now = os.clock()
	if not force then
		if not state.dirty then
			return
		end
		if now < state.nextSendAt then
			return
		end
	end

	player:SetAttribute("ProfessionResource", state.resource)
	player:SetAttribute("ProfessionMaxResource", state.maxResource)
	abilityEvent:FireClient(player, buildStatePayload(state))
	state.dirty = false
	state.message = ""
	state.nextSendAt = now + STATE_SEND_INTERVAL
end

local function bindCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	local lastHealth = humanoid.Health
	local applyingHealthAdjustment = false
	trackConnection(player, humanoid.HealthChanged:Connect(function(currentHealth)
		if applyingHealthAdjustment then
			lastHealth = currentHealth
			applyingHealthAdjustment = false
			return
		end

		local state = getState(player)
		local profession = select(1, abilityConfig.GetProfession(state.professionKey))
		local resourceConfig = profession.Resource or {}

		if currentHealth < lastHealth then
			local now = os.clock()
			local damageTaken = lastHealth - currentHealth
			local adjustedHealth = currentHealth

			if state.shield > 0 then
				local absorbed = math.min(state.shield, damageTaken)
				if absorbed > 0 then
					state.shield -= absorbed
					adjustedHealth = math.min(humanoid.MaxHealth, adjustedHealth + absorbed)
					state.dirty = true
				end
			end

			if now < state.immortalUntil and adjustedHealth < 1 then
				adjustedHealth = 1
				state.dirty = true
			end

			if adjustedHealth > currentHealth then
				applyingHealthAdjustment = true
				humanoid.Health = adjustedHealth
			end

			local gainPerDamage = tonumber(resourceConfig.GainPerDamageTaken) or 0
			if gainPerDamage > 0 then
				addResource(state, damageTaken * gainPerDamage)
				state.lastCombatAt = now
			end
		end

		lastHealth = humanoid.Health
	end))
end

local function setupPlayer(player)
	local state = getState(player)
	player:SetAttribute("ProfessionKey", state.professionKey)
	player:SetAttribute("ProfessionResourceName", state.resourceDisplayName)
	player:SetAttribute("ProfessionStance", state.stanceKey)

	trackConnection(player, player:GetAttributeChangedSignal("SelectedClass"):Connect(function()
		setProfession(player, resolveProfessionKey(player))
		sendState(player, true)
	end))

	trackConnection(player, player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
		task.defer(function()
			sendState(player, true)
		end)
	end))

	if player.Character then
		task.defer(function()
			bindCharacter(player, player.Character)
			sendState(player, true)
		end)
	end

	sendState(player, true)
end

local function cleanupPlayer(player)
	disconnectPlayerConnections(player)
	stateByPlayer[player] = nil
end

local function setStance(player, stanceKey)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	if not profession.Stances or not profession.Stances[stanceKey] then
		setStateMessage(state, "This profession has no such stance.")
		return
	end

	state.stanceKey = stanceKey
	player:SetAttribute("ProfessionStance", stanceKey)
	setStateMessage(state, ("Stance: %s"):format(profession.Stances[stanceKey].DisplayName or stanceKey))
end

local function useAbility(player, abilityKey)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local ability = profession.Abilities and profession.Abilities[abilityKey]
	if not ability or state.unlockedAbilities[abilityKey] ~= true then
		setStateMessage(state, "Ability is not unlocked.")
		return
	end

	local now = os.clock()
	if getCooldownRemaining(state, abilityKey, now) > 0 then
		setStateMessage(state, "Ability is on cooldown.")
		return
	end

	if ability.Type == "Aura" then
		state.auraEnabled[abilityKey] = not state.auraEnabled[abilityKey]
		setStateMessage(state, state.auraEnabled[abilityKey] and (ability.DisplayName .. " enabled.") or (ability.DisplayName .. " disabled."))
		return
	end

	if not implementedAbilities[abilityKey] then
		setStateMessage(state, (ability.DisplayName or abilityKey) .. " is scaffolded for a later slice.")
		return
	end

	local cost = ability.Cost
	local spentResource = 0
	if cost == "All" then
		if state.resource <= 0 then
			setStateMessage(state, "Not enough " .. state.resourceDisplayName .. ".")
			return
		end
		spentResource = state.resource
		state.resource = 0
	elseif not spendResource(state, cost) then
		setStateMessage(state, "Not enough " .. state.resourceDisplayName .. ".")
		return
	else
		spentResource = tonumber(cost) or 0
	end

	state.cooldowns[abilityKey] = now + math.max(0, tonumber(ability.Cooldown) or 0)

	if abilityKey == "Shield" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local maxHealth = humanoid and humanoid.MaxHealth or 100
		state.shield = math.max(state.shield, maxHealth * (tonumber(ability.ShieldMaxHealthMultiplier) or 0.1))
		state.shieldExpiresAt = now + math.max(0, tonumber(ability.Duration) or 6)
		setStateMessage(state, "Shield active.")
	elseif abilityKey == "RageHeal" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local healAmount = humanoid.MaxHealth * spentResource * (tonumber(ability.HealMaxHealthPerRage) or 0)
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
			setStateMessage(state, ("Rage Heal: +%d HP."):format(math.floor(healAmount + 0.5)))
		else
			setStateMessage(state, "Rage Heal used.")
		end
	elseif abilityKey == "UndyingRage" then
		state.immortalUntil = now + math.max(0, tonumber(ability.Duration) or 5)
		setStateMessage(state, "Undying Rage active.")
	else
		setStateMessage(state, ability.DisplayName .. " is scaffolded.")
	end
end

local function handleClientAction(player, action, payload)
	if action == "refresh" then
		sendState(player, true)
		return
	end

	if typeof(payload) ~= "table" then
		payload = {}
	end

	if action == "setStance" then
		setStance(player, tostring(payload.stanceKey or ""))
		sendState(player, true)
		return
	end

	if action == "useAbility" then
		useAbility(player, tostring(payload.abilityKey or ""))
		sendState(player, true)
		return
	end
end

local function updateState(state, deltaTime)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local resourceConfig = profession.Resource or {}
	local now = os.clock()

	local regen = tonumber(resourceConfig.RegenPerSecond) or 0
	if regen > 0 then
		addResource(state, regen * deltaTime)
	end

	local decay = tonumber(resourceConfig.DecayPerSecond) or 0
	local decayDelay = tonumber(resourceConfig.DecayDelay) or 0
	if decay > 0 and now - state.lastCombatAt >= decayDelay then
		addResource(state, -decay * deltaTime)
	end

	for abilityKey, enabled in pairs(state.auraEnabled) do
		if enabled then
			local ability = profession.Abilities and profession.Abilities[abilityKey]
			local costPerSecond = ability and tonumber(ability.CostPerSecond) or 0
			if costPerSecond > 0 then
				local cost = costPerSecond * deltaTime
				if state.resource <= cost then
					state.resource = 0
					state.auraEnabled[abilityKey] = false
					setStateMessage(state, (ability.DisplayName or abilityKey) .. " stopped.")
				else
					state.resource -= cost
					state.dirty = true
				end
			end
		end
	end

	if state.shield > 0 and state.shieldExpiresAt > 0 and now >= state.shieldExpiresAt then
		state.shield = 0
		state.shieldExpiresAt = 0
		state.dirty = true
	end
end

function AbilityService.Start()
	if started then
		return
	end
	started = true
	abilityEvent = ensureRemoteEvent(abilityConfig.EventName)

	abilityEvent.OnServerEvent:Connect(handleClientAction)

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	RunService.Heartbeat:Connect(function(deltaTime)
		for player, state in pairs(stateByPlayer) do
			if player.Parent ~= Players then
				cleanupPlayer(player)
			else
				updateState(state, deltaTime)
				sendState(player, false)
			end
		end
	end)
end

function AbilityService.ConsumeWeaponUse(player, weaponKey)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local stances = profession.Stances or {}

	for _, stance in pairs(stances) do
		if stance.WeaponKey == weaponKey then
			local cost = tonumber(stance.ResourceCostPerShot) or 0
			if cost <= 0 then
				return true
			end

			if not spendResource(state, cost) then
				setStateMessage(state, "Not enough " .. state.resourceDisplayName .. ".")
				sendState(player, true)
				return false
			end

			sendState(player, true)
			return true
		end
	end

	return true
end

function AbilityService.RegisterDamageDealt(player, amount)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local gainPerDamage = tonumber((profession.Resource or {}).GainPerDamageDealt) or 0
	if gainPerDamage <= 0 then
		return
	end

	addResource(state, (tonumber(amount) or 0) * gainPerDamage)
	state.lastCombatAt = os.clock()
	sendState(player, false)
end

function AbilityService.GetState(player)
	return getState(player)
end

return AbilityService
