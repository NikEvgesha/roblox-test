local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local abilityConfig = require(sharedFolder:WaitForChild("AbilityConfig"))
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local gameRules = require(sharedFolder:WaitForChild("GameRules"))

local AbilityService = {}

local STATE_SEND_INTERVAL = 0.2
local implementedAbilities = {
	PiercingShot = true,
	Grenade = true,
	Shield = true,
	RageHeal = true,
	UndyingRage = true,
}

local combatFeedbackEvent = nil
local weaponsByKey = combatConfig.Weapons or {}
local toolNameToWeaponKey = {}
for weaponKey, weapon in pairs(weaponsByKey) do
	if type(weapon.ToolName) == "string" then
		toolNameToWeaponKey[weapon.ToolName] = weaponKey
	end
end

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

local function getWeaponKeyFromTool(tool)
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	local byAttribute = tool:GetAttribute("WeaponKey")
	if type(byAttribute) == "string" and weaponsByKey[byAttribute] then
		return byAttribute
	end

	return toolNameToWeaponKey[tool.Name]
end

local function getEquippedWeaponKey(player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local weaponKey = getWeaponKeyFromTool(child)
			if weaponKey then
				return weaponKey
			end
		end
	end

	return nil
end

local function getEquippedToolAndHandle(player, weapon)
	local character = player.Character
	if not character or not weapon then
		return nil, nil
	end

	local tool = character:FindFirstChild(weapon.ToolName)
	if not tool or not tool:IsA("Tool") then
		return nil, nil
	end

	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return tool, handle
	end

	return tool, nil
end

local function getRangedFireOrigin(player, weapon)
	local _, handle = getEquippedToolAndHandle(player, weapon)
	if handle then
		local muzzle = handle:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle.WorldPosition
		end

		return handle.Position
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 1.5, 0)
	end

	return nil
end

local function findHumanoidFromPart(part)
	if not part then
		return nil
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	return model:FindFirstChildOfClass("Humanoid"), model
end

local function tagHumanoidDamageByPlayer(humanoid, player)
	if not humanoid or not player then
		return
	end

	humanoid:SetAttribute("LastHitByUserId", player.UserId)
	humanoid:SetAttribute("LastHitAt", os.clock())

	local oldTag = humanoid:FindFirstChild("creator")
	if oldTag and oldTag:IsA("ObjectValue") then
		oldTag:Destroy()
	end

	local creator = Instance.new("ObjectValue")
	creator.Name = "creator"
	creator.Value = player
	creator.Parent = humanoid
	Debris:AddItem(creator, 8)
end

local function createPiercingTracer(origin, hitPosition)
	if typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" then
		return
	end

	local distance = (hitPosition - origin).Magnitude
	if distance < 0.1 then
		return
	end

	local startPart = Instance.new("Part")
	startPart.Name = "PiercingShotTracerStart"
	startPart.Anchored = true
	startPart.CanCollide = false
	startPart.CanTouch = false
	startPart.CanQuery = false
	startPart.Transparency = 1
	startPart.Size = Vector3.new(0.05, 0.05, 0.05)
	startPart.CFrame = CFrame.new(origin)
	startPart.Parent = Workspace

	local endPart = Instance.new("Part")
	endPart.Name = "PiercingShotTracerEnd"
	endPart.Anchored = true
	endPart.CanCollide = false
	endPart.CanTouch = false
	endPart.CanQuery = false
	endPart.Transparency = 1
	endPart.Size = Vector3.new(0.05, 0.05, 0.05)
	endPart.CFrame = CFrame.new(hitPosition)
	endPart.Parent = Workspace

	local startAttachment = Instance.new("Attachment")
	startAttachment.Parent = startPart
	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = endPart

	local beam = Instance.new("Beam")
	beam.Name = "PiercingShotBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Brightness = 6
	beam.Width0 = 0.42
	beam.Width1 = 0.2
	beam.Color = ColorSequence.new(Color3.fromRGB(130, 238, 255), Color3.fromRGB(255, 248, 190))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	beam.Parent = startPart

	Debris:AddItem(startPart, 0.16)
	Debris:AddItem(endPart, 0.16)
end

local function createGrenadeVisual(position, radius, fuseTime)
	if typeof(position) ~= "Vector3" then
		return
	end

	local marker = Instance.new("Part")
	marker.Name = "GrenadeMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Shape = Enum.PartType.Ball
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 172, 74)
	marker.Transparency = 0.15
	marker.Size = Vector3.new(1.2, 1.2, 1.2)
	marker.Position = position + Vector3.new(0, 0.8, 0)
	marker.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = marker.Color
	light.Brightness = 2.4
	light.Range = 10
	light.Parent = marker

	Debris:AddItem(marker, fuseTime + 0.2)

	task.delay(fuseTime, function()
		local explosion = Instance.new("Part")
		explosion.Name = "GrenadeExplosion"
		explosion.Anchored = true
		explosion.CanCollide = false
		explosion.CanTouch = false
		explosion.CanQuery = false
		explosion.Shape = Enum.PartType.Ball
		explosion.Material = Enum.Material.Neon
		explosion.Color = Color3.fromRGB(255, 126, 58)
		explosion.Transparency = 0.45
		explosion.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		explosion.Position = position
		explosion.Parent = Workspace

		local explosionLight = Instance.new("PointLight")
		explosionLight.Color = explosion.Color
		explosionLight.Brightness = 4
		explosionLight.Range = radius * 2
		explosionLight.Parent = explosion

		Debris:AddItem(explosion, 0.18)
	end)
end

local function getRangedDamageMultiplier(player)
	local progression = player:FindFirstChild("Progression")
	local metaProgression = player:FindFirstChild("MetaProgression")
	local runLevelValue = progression and progression:FindFirstChild("RangedLevel")
	local metaLevelValue = metaProgression and metaProgression:FindFirstChild("Damage")
	local runLevel = runLevelValue and runLevelValue:IsA("IntValue") and math.max(0, runLevelValue.Value) or 0
	local metaLevel = metaLevelValue and metaLevelValue:IsA("IntValue") and math.max(0, metaLevelValue.Value) or 0
	local runSkill = combatConfig.Progression and combatConfig.Progression.Skills and combatConfig.Progression.Skills.RangedDamage
	local metaDamage = combatConfig.MetaProgression and combatConfig.MetaProgression.Upgrades and combatConfig.MetaProgression.Upgrades.Damage

	return 1
		+ runLevel * (tonumber(runSkill and runSkill.DamageMultiplierPerLevel) or 0)
		+ metaLevel * (tonumber(metaDamage and metaDamage.RangedDamagePerLevel) or 0)
end

local function equipWeaponKey(player, weaponKey)
	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = character:FindFirstChild(weapon.ToolName)
		or (backpack and backpack:FindFirstChild(weapon.ToolName))
	if not (tool and tool:IsA("Tool")) then
		return false
	end

	humanoid:EquipTool(tool)
	return true
end

local function equipStanceWeapon(player, state)
	local stance = abilityConfig.GetStance(state.professionKey, state.stanceKey)
	local weaponKey = stance and stance.WeaponKey
	if type(weaponKey) ~= "string" or weaponKey == "" then
		return
	end

	task.spawn(function()
		for _ = 1, 8 do
			if player.Parent ~= Players then
				return
			end
			if equipWeaponKey(player, weaponKey) then
				return
			end
			task.wait(0.15)
		end
	end)
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

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
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

local function getSkillPointsValue(player, createIfMissing)
	local progression = player:FindFirstChild("Progression")
	if not progression and createIfMissing then
		progression = ensureFolder(player, "Progression")
	end
	if not progression then
		return nil
	end

	if createIfMissing then
		return ensureIntValue(progression, "SkillPoints", 0)
	end

	local value = progression:FindFirstChild("SkillPoints")
	if value and value:IsA("IntValue") then
		return value
	end

	return nil
end

local function getSkillPoints(player)
	local value = getSkillPointsValue(player, false)
	return value and math.max(0, value.Value) or 0
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

local function buildInitialAbilityRanks(profession)
	local ranks = {}
	for _, abilityKey in ipairs(profession.AbilityOrder or {}) do
		local ability = profession.Abilities and profession.Abilities[abilityKey]
		ranks[abilityKey] = math.max(0, math.floor(tonumber(ability and ability.StartRank) or 0))
	end
	return ranks
end

local function getAbilityRank(state, abilityKey)
	return math.max(0, math.floor(tonumber(state.abilityRanks[abilityKey]) or 0))
end

local function isAbilityUnlocked(state, abilityKey)
	return getAbilityRank(state, abilityKey) > 0
end

local function getAbilityDefinition(state, abilityKey)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	return profession.Abilities and profession.Abilities[abilityKey]
end

local function getScaledAbilityNumber(state, abilityKey, baseField, perRankField, defaultValue)
	local ability = getAbilityDefinition(state, abilityKey)
	local rank = getAbilityRank(state, abilityKey)
	local baseValue = tonumber(ability and ability[baseField]) or defaultValue or 0
	local perRankValue = tonumber(ability and ability[perRankField]) or 0
	return baseValue + math.max(0, rank - 1) * perRankValue
end

local function getGuardianIncomingDamageReduction(state)
	if state.professionKey ~= "Guardian" then
		return 0
	end

	local ironSkin = getAbilityDefinition(state, "IronSkin")
	local reduction = getAbilityRank(state, "IronSkin") * (tonumber(ironSkin and ironSkin.DamageReductionPerRank) or 0)

	if state.auraEnabled.TestAura == true then
		local testAura = getAbilityDefinition(state, "TestAura")
		reduction += tonumber(testAura and testAura.DefenseBonus) or 0
	end

	return math.clamp(reduction, 0, 0.75)
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
		abilityRanks = buildInitialAbilityRanks(profession),
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
			local rank = getAbilityRank(state, abilityKey)
			local maxRank = math.max(1, math.floor(tonumber(ability.MaxRank) or 1))
			table.insert(abilities, {
				key = abilityKey,
				displayName = ability.DisplayName or abilityKey,
				type = ability.Type or "Passive",
				description = ability.Description or "",
				cost = ability.Cost,
				costPerSecond = ability.CostPerSecond,
				cooldown = ability.Cooldown or 0,
				cooldownRemaining = getCooldownRemaining(state, abilityKey),
				unlocked = rank > 0,
				rank = rank,
				maxRank = maxRank,
				upgradeCost = math.max(1, math.floor(tonumber(ability.UpgradeCost) or 1)),
				canUpgrade = rank < maxRank,
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
		skillPoints = getSkillPoints(state.player),
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
			local remainingDamage = damageTaken
			local adjustedHealth = currentHealth

			local damageReduction = getGuardianIncomingDamageReduction(state)
			if damageReduction > 0 then
				local prevented = damageTaken * damageReduction
				if prevented > 0 then
					remainingDamage = math.max(0, remainingDamage - prevented)
					adjustedHealth = math.min(humanoid.MaxHealth, adjustedHealth + prevented)
					state.dirty = true
				end
			end

			if state.shield > 0 then
				local absorbed = math.min(state.shield, remainingDamage)
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
	local skillPointsValue = getSkillPointsValue(player, true)
	player:SetAttribute("ProfessionKey", state.professionKey)
	player:SetAttribute("ProfessionResourceName", state.resourceDisplayName)
	player:SetAttribute("ProfessionStance", state.stanceKey)
	equipStanceWeapon(player, state)

	if skillPointsValue then
		trackConnection(player, skillPointsValue:GetPropertyChangedSignal("Value"):Connect(function()
			local currentState = getState(player)
			currentState.dirty = true
			currentState.nextSendAt = 0
			sendState(player, true)
		end))
	end

	trackConnection(player, player:GetAttributeChangedSignal("SelectedClass"):Connect(function()
		setProfession(player, resolveProfessionKey(player))
		sendState(player, true)
	end))

	trackConnection(player, player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
		task.defer(function()
			equipStanceWeapon(player, getState(player))
			sendState(player, true)
		end)
	end))

	if player.Character then
		task.defer(function()
			bindCharacter(player, player.Character)
			equipStanceWeapon(player, getState(player))
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
	equipStanceWeapon(player, state)
	setStateMessage(state, ("Stance: %s"):format(profession.Stances[stanceKey].DisplayName or stanceKey))
end

local function upgradeAbility(player, abilityKey)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local ability = profession.Abilities and profession.Abilities[abilityKey]
	if not ability then
		setStateMessage(state, "Unknown ability.")
		return
	end

	local currentRank = getAbilityRank(state, abilityKey)
	local maxRank = math.max(1, math.floor(tonumber(ability.MaxRank) or 1))
	local points = getSkillPointsValue(player, true)
	local decision = gameRules.GetAbilityUpgradeDecision(
		currentRank,
		maxRank,
		points and points.Value or 0,
		ability.UpgradeCost
	)
	if decision.reason == "maxed" then
		setStateMessage(state, "Ability is already maxed.")
		return
	end

	if not decision.allowed or not points then
		setStateMessage(state, "Not enough skill points.")
		return
	end

	points.Value -= decision.cost
	state.abilityRanks[abilityKey] = decision.nextRank
	setStateMessage(state, ("Upgraded %s to rank %d."):format(ability.DisplayName or abilityKey, decision.nextRank))
end

local function executePiercingShot(player, ability, payload)
	if typeof(payload) ~= "table" then
		return false, "Missing target data."
	end

	local state = getState(player)
	local weaponKey = getEquippedWeaponKey(player)
	local weapon = weaponKey and weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return false, "Equip a ranged weapon first."
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local anchorPart = (head and head:IsA("BasePart")) and head or ((root and root:IsA("BasePart")) and root or nil)
	if not anchorPart then
		return false, "Character is not ready."
	end

	local damageOrigin = anchorPart.Position
	local rayOrigin = payload.rayOrigin
	local rayDirection = payload.rayDirection
	if typeof(rayOrigin) == "Vector3" and typeof(rayDirection) == "Vector3" and rayDirection.Magnitude > 0.01 then
		if (rayOrigin - anchorPart.Position).Magnitude <= 18 then
			damageOrigin = rayOrigin
		end
	end

	local direction = payload.direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		direction = rayDirection
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return false, "Invalid aim direction."
	end
	direction = direction.Unit

	local targetPosition = payload.targetPosition
	if typeof(targetPosition) == "Vector3" then
		local toTarget = targetPosition - damageOrigin
		if toTarget.Magnitude > 0.01 then
			direction = toTarget.Unit
		end
	end

	local tracerOrigin = getRangedFireOrigin(player, weapon) or damageOrigin
	local range = math.max(1, tonumber(ability.Range) or tonumber(weapon.Range) or 500)
	local maxTargets = math.max(1, math.floor(getScaledAbilityNumber(state, "PiercingShot", "MaxTargets", "MaxTargetsPerRank", 5)))
	local abilityDamageMultiplier = getScaledAbilityNumber(
		state,
		"PiercingShot",
		"DamageMultiplier",
		"DamageMultiplierPerRank",
		2.5
	)
	local damageMultiplier = getRangedDamageMultiplier(player)
		* AbilityService.GetRangedDamageMultiplier(player, weaponKey)
		* abilityDamageMultiplier
	local damage = math.max(1, math.floor((tonumber(weapon.Damage) or 1) * damageMultiplier + 0.5))
	local ignoreList = { character }
	local hitModels = {}
	local totalDamage = 0
	local hitCount = 0
	local feedbackWorldPosition = nil
	local finalHitPosition = damageOrigin + direction * range
	local currentOrigin = damageOrigin
	local remainingDistance = range

	for _ = 1, maxTargets do
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = ignoreList

		local result = Workspace:Raycast(currentOrigin, direction * remainingDistance, rayParams)
		if not result then
			finalHitPosition = currentOrigin + direction * remainingDistance
			break
		end

		finalHitPosition = result.Position
		local humanoid, model = findHumanoidFromPart(result.Instance)
		if humanoid and model and model ~= character then
			local isPlayerCharacter = Players:GetPlayerFromCharacter(model) ~= nil
			if not isPlayerCharacter and humanoid.Health > 0 and not hitModels[model] then
				tagHumanoidDamageByPlayer(humanoid, player)
				humanoid:TakeDamage(damage)
				totalDamage += damage
				hitCount += 1
				hitModels[model] = true
				feedbackWorldPosition = feedbackWorldPosition or result.Position
				table.insert(ignoreList, model)
			else
				table.insert(ignoreList, model)
			end

			local traveled = (result.Position - currentOrigin).Magnitude
			remainingDistance -= traveled
			if remainingDistance <= 0.5 then
				break
			end
			currentOrigin = result.Position + direction * 0.25
		else
			break
		end
	end

	createPiercingTracer(tracerOrigin + direction * 0.6, finalHitPosition)

	if hitCount > 0 then
		AbilityService.RegisterDamageDealt(player, totalDamage)
		if combatFeedbackEvent then
			combatFeedbackEvent:FireClient(player, {
				type = "hit",
				damage = totalDamage,
				hitCount = hitCount,
				category = "Ranged",
				worldPosition = feedbackWorldPosition,
			})
		end
	end

	return true, ("Piercing Shot: %d hits."):format(hitCount)
end

local function resolveAbilityTargetPosition(player, payload, maxRange)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local targetPosition = typeof(payload) == "table" and payload.targetPosition or nil
	local direction = typeof(payload) == "table" and payload.direction or nil

	if typeof(targetPosition) ~= "Vector3" then
		if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
			direction = root.CFrame.LookVector
		end
		targetPosition = origin + direction.Unit * math.max(1, maxRange)
	end

	local offset = targetPosition - origin
	local distance = offset.Magnitude
	if distance > maxRange then
		targetPosition = origin + offset.Unit * maxRange
	end

	return targetPosition
end

local function applyAreaDamage(player, position, radius, damage)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	overlapParams.FilterDescendantsInstances = { player.Character }

	local parts = Workspace:GetPartBoundsInRadius(position, radius, overlapParams)
	local hitModels = {}
	local totalDamage = 0
	local hitCount = 0
	local feedbackWorldPosition = nil

	for _, part in ipairs(parts) do
		local humanoid, model = findHumanoidFromPart(part)
		if humanoid and model and not hitModels[model] and model ~= player.Character then
			if not Players:GetPlayerFromCharacter(model) and humanoid.Health > 0 then
				tagHumanoidDamageByPlayer(humanoid, player)
				humanoid:TakeDamage(damage)
				hitModels[model] = true
				totalDamage += damage
				hitCount += 1

				local targetRoot = model:FindFirstChild("HumanoidRootPart")
				if targetRoot and targetRoot:IsA("BasePart") then
					feedbackWorldPosition = feedbackWorldPosition or targetRoot.Position
				else
					feedbackWorldPosition = feedbackWorldPosition or part.Position
				end
			end
		end
	end

	if hitCount > 0 then
		AbilityService.RegisterDamageDealt(player, totalDamage)
		if combatFeedbackEvent then
			combatFeedbackEvent:FireClient(player, {
				type = "hit",
				damage = totalDamage,
				hitCount = hitCount,
				category = "Ranged",
				worldPosition = feedbackWorldPosition,
			})
		end
	end

	return totalDamage, hitCount
end

local function executeGrenade(player, ability, payload)
	local state = getState(player)
	local radius = math.max(1, getScaledAbilityNumber(state, "Grenade", "Radius", "RadiusPerRank", 12))
	local damage = math.max(1, math.floor(getScaledAbilityNumber(state, "Grenade", "Damage", "DamagePerRank", 120)))
	local fuseTime = math.max(0, tonumber(ability.FuseTime) or 0.8)
	local maxRange = math.max(1, tonumber(ability.Range) or 120)
	local targetPosition = resolveAbilityTargetPosition(player, payload, maxRange)
	if not targetPosition then
		return false, "Character is not ready."
	end

	createGrenadeVisual(targetPosition, radius, fuseTime)

	task.delay(fuseTime, function()
		if player.Parent ~= Players then
			return
		end
		applyAreaDamage(player, targetPosition, radius, damage)
	end)

	return true, "Grenade thrown."
end

local function useAbility(player, abilityKey, payload)
	local state = getState(player)
	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local ability = profession.Abilities and profession.Abilities[abilityKey]
	if not ability or not isAbilityUnlocked(state, abilityKey) then
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
		state.dirty = true
	elseif not spendResource(state, cost) then
		setStateMessage(state, "Not enough " .. state.resourceDisplayName .. ".")
		return
	else
		spentResource = tonumber(cost) or 0
	end

	local successMessage = nil
	if abilityKey == "PiercingShot" then
		local ok, message = executePiercingShot(player, ability, payload)
		if not ok then
			if cost == "All" then
				state.resource = spentResource
			else
				state.resource = math.min(state.maxResource, state.resource + spentResource)
			end
			state.dirty = true
			setStateMessage(state, message)
			return
		end
		successMessage = message
	elseif abilityKey == "Grenade" then
		local ok, message = executeGrenade(player, ability, payload)
		if not ok then
			if cost == "All" then
				state.resource = spentResource
			else
				state.resource = math.min(state.maxResource, state.resource + spentResource)
			end
			state.dirty = true
			setStateMessage(state, message)
			return
		end
		successMessage = message
	elseif abilityKey == "Shield" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local maxHealth = humanoid and humanoid.MaxHealth or 100
		local shieldMultiplier = getScaledAbilityNumber(
			state,
			"Shield",
			"ShieldMaxHealthMultiplier",
			"ShieldMaxHealthMultiplierPerRank",
			0.1
		)
		local duration = getScaledAbilityNumber(state, "Shield", "Duration", "DurationPerRank", 6)
		state.shield = math.max(state.shield, maxHealth * shieldMultiplier)
		state.shieldExpiresAt = now + math.max(0, duration)
		successMessage = "Shield active."
	elseif abilityKey == "RageHeal" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local healPerRage = getScaledAbilityNumber(
				state,
				"RageHeal",
				"HealMaxHealthPerRage",
				"HealMaxHealthPerRagePerRank",
				0.006
			)
			local healAmount = humanoid.MaxHealth * spentResource * healPerRage
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
			successMessage = ("Rage Heal: +%d HP."):format(math.floor(healAmount + 0.5))
		else
			successMessage = "Rage Heal used."
		end
	elseif abilityKey == "UndyingRage" then
		local duration = getScaledAbilityNumber(state, "UndyingRage", "Duration", "DurationPerRank", 5)
		state.immortalUntil = now + math.max(0, duration)
		successMessage = "Undying Rage active."
	else
		successMessage = ability.DisplayName .. " is scaffolded."
	end

	state.cooldowns[abilityKey] = now + math.max(0, tonumber(ability.Cooldown) or 0)
	setStateMessage(state, successMessage)
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
		useAbility(player, tostring(payload.abilityKey or ""), payload)
		sendState(player, true)
		return
	end

	if action == "upgradeAbility" then
		upgradeAbility(player, tostring(payload.abilityKey or ""))
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

	for _, endsAt in pairs(state.cooldowns) do
		if typeof(endsAt) == "number" and endsAt > now then
			state.dirty = true
			break
		end
	end

	if state.immortalUntil > now then
		state.dirty = true
	end
end

function AbilityService.Start()
	if started then
		return
	end
	started = true
	abilityEvent = ensureRemoteEvent(abilityConfig.EventName)
	combatFeedbackEvent = ensureRemoteEvent("CombatFeedback")

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

function AbilityService.GetDamageOutputMultiplier(player)
	local state = getState(player)
	if state.professionKey ~= "Guardian" then
		return 1
	end

	local ability = getAbilityDefinition(state, "RageScaling")
	local rank = getAbilityRank(state, "RageScaling")
	local perRagePerRank = tonumber(ability and ability.DamageMultiplierPerRagePerRank) or 0
	return math.max(0.1, 1 + state.resource * rank * perRagePerRank)
end

function AbilityService.GetRangedDamageMultiplier(player, weaponKey)
	local state = getState(player)
	local multiplier = AbilityService.GetDamageOutputMultiplier(player)

	if state.professionKey ~= "Gunner" then
		return multiplier
	end

	local profession = select(1, abilityConfig.GetProfession(state.professionKey))

	if weaponKey == "Pistol" then
		local ability = profession.Abilities and profession.Abilities.PistolTraining
		multiplier += getAbilityRank(state, "PistolTraining") * (tonumber(ability and ability.DamageMultiplierPerRank) or 0)
	elseif weaponKey == "Rifle" then
		local ability = profession.Abilities and profession.Abilities.RifleTraining
		multiplier += getAbilityRank(state, "RifleTraining") * (tonumber(ability and ability.DamageMultiplierPerRank) or 0)
	end

	return math.max(0.1, multiplier)
end

function AbilityService.GetMeleeDamageMultiplier(player)
	local state = getState(player)
	local multiplier = AbilityService.GetDamageOutputMultiplier(player)

	if state.professionKey == "Guardian" then
		local ability = getAbilityDefinition(state, "HeavyStrikes")
		multiplier += getAbilityRank(state, "HeavyStrikes") * (tonumber(ability and ability.MeleeDamageMultiplierPerRank) or 0)
	end

	return math.max(0.1, multiplier)
end

function AbilityService.GetFireRateMultiplier(player, weaponKey)
	local state = getState(player)
	if state.professionKey ~= "Gunner" then
		return 1
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return 1
	end

	local profession = select(1, abilityConfig.GetProfession(state.professionKey))
	local ability = profession.Abilities and profession.Abilities.RapidHandling
	local rank = getAbilityRank(state, "RapidHandling")
	return math.max(0.1, 1 + rank * (tonumber(ability and ability.FireRateMultiplierPerRank) or 0))
end

function AbilityService.GetState(player)
	return getState(player)
end

return AbilityService
