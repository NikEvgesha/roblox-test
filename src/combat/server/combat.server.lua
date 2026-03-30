local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local COMBAT_ACTION_EVENT_NAME = "CombatAction"
local COMBAT_STATE_EVENT_NAME = "CombatState"
local COMBAT_FEEDBACK_EVENT_NAME = "CombatFeedback"
local SHOP_EVENT_NAME = "ShopEvent"

local KILL_TAG_LIFETIME = 8
local TRACER_SPEED = 740
local TRACER_MIN_TRAVEL_TIME = 0.045
local TRACER_MAX_TRAVEL_TIME = 0.22
local TRACER_SEGMENT_LENGTH = 10
local TRACER_MUZZLE_OFFSET = 0.45

local weaponsByKey = combatConfig.Weapons
local metaProgressionConfig = combatConfig.MetaProgression or {}
local metaUpgradeConfig = metaProgressionConfig.Upgrades or {}
local debugConfig = combatConfig.Debug or {}
local classesConfig = combatConfig.Classes or {}
local classDefinitions = classesConfig.Definitions or {}
local classOrder = classesConfig.Order or { "Assault", "Builder", "Healer", "Melee" }
local grantAllWeaponsOnSpawn = debugConfig.GrantAllWeaponsOnSpawn == true
local toolNameToWeaponKey = {}
for weaponKey, definition in pairs(weaponsByKey) do
	toolNameToWeaponKey[definition.ToolName] = weaponKey
end

local function getWeaponKeyFromTool(tool)
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	local byAttribute = tool:GetAttribute("WeaponKey")
	if type(byAttribute) == "string" and weaponsByKey[byAttribute] then
		return byAttribute
	end

	local byName = toolNameToWeaponKey[tool.Name]
	if byName and weaponsByKey[byName] then
		return byName
	end

	return nil
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

local combatActionEvent = ensureRemoteEvent(COMBAT_ACTION_EVENT_NAME)
local combatStateEvent = ensureRemoteEvent(COMBAT_STATE_EVENT_NAME)
local combatFeedbackEvent = ensureRemoteEvent(COMBAT_FEEDBACK_EVENT_NAME)
local shopEvent = ensureRemoteEvent(SHOP_EVENT_NAME)

local pickupFolder = Workspace:FindFirstChild("AmmoPickups")
if not pickupFolder then
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "AmmoPickups"
	pickupFolder.Parent = Workspace
end

local ammoConfig = combatConfig.Ammo or {}
local infiniteReserveAmmo = ammoConfig.InfiniteReserve ~= false
local spawnAmmoPickups = ammoConfig.SpawnPickups == true

if not spawnAmmoPickups then
	for _, child in ipairs(pickupFolder:GetChildren()) do
		child:Destroy()
	end
end

local stateByPlayer = {}

local function getProgressionLevel(player, statName)
	local progression = player:FindFirstChild("Progression")
	if not progression then
		return 0
	end

	local stat = progression:FindFirstChild(statName)
	if not stat or not stat:IsA("IntValue") then
		return 0
	end

	return math.max(0, stat.Value)
end

local function getMetaUpgradeLevel(player, upgradeKey)
	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression then
		return 0
	end

	local stat = metaProgression:FindFirstChild(upgradeKey)
	if not stat or not stat:IsA("IntValue") then
		return 0
	end

	return math.max(0, stat.Value)
end

local function getRangedDamageMultiplier(player)
	local skill = combatConfig.Progression.Skills and combatConfig.Progression.Skills.RangedDamage or nil
	local perLevel = skill and skill.DamageMultiplierPerLevel or 0
	local runLevel = getProgressionLevel(player, "RangedLevel")
	local metaDamage = metaUpgradeConfig.Damage or {}
	local metaLevel = getMetaUpgradeLevel(player, "Damage")
	local metaBonus = metaLevel * (tonumber(metaDamage.RangedDamagePerLevel) or 0)
	return 1 + runLevel * perLevel + metaBonus
end

local function getMeleeDamageMultiplier(player)
	local skill = combatConfig.Progression.Skills and combatConfig.Progression.Skills.MeleeDamage or nil
	local perLevel = skill and skill.DamageMultiplierPerLevel or 0
	local runLevel = getProgressionLevel(player, "MeleeLevel")
	local metaDamage = metaUpgradeConfig.Damage or {}
	local metaLevel = getMetaUpgradeLevel(player, "Damage")
	local metaBonus = metaLevel * (tonumber(metaDamage.MeleeDamagePerLevel) or 0)
	return 1 + runLevel * perLevel + metaBonus
end

local function getMeleeAttackSpeedMultiplier(player, weapon)
	local base = tonumber(weapon and weapon.AttackSpeedMultiplier) or 1
	local speedSkillConfig = combatConfig.Progression and combatConfig.Progression.Skills
		and combatConfig.Progression.Skills.Speed
		or nil
	local speedMetaConfig = metaUpgradeConfig.Speed or {}
	local speedSkillLevel = getProgressionLevel(player, "SpeedLevel")
	local speedMetaLevel = getMetaUpgradeLevel(player, "Speed")
	local fromRun = speedSkillLevel * (tonumber(speedSkillConfig and speedSkillConfig.MeleeAttackSpeedPerLevel) or 0)
	local fromMeta = speedMetaLevel * (tonumber(speedMetaConfig.MeleeAttackSpeedPerLevel) or 0)
	return math.max(0.25, base + fromRun + fromMeta)
end

local function getEffectiveMeleeCooldown(player, weapon)
	local cooldown = tonumber(weapon and weapon.Cooldown) or 0.75
	local speedMultiplier = getMeleeAttackSpeedMultiplier(player, weapon)
	return math.max(0.2, cooldown / speedMultiplier)
end

local function ensureStat(parent, name, className, defaultValue)
	local item = parent:FindFirstChild(name)
	if item and item.ClassName == className then
		return item
	end

	item = Instance.new(className)
	item.Name = name
	item.Value = defaultValue
	item.Parent = parent
	return item
end

local function ensureMoneyStat(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	return ensureStat(leaderstats, "Money", "IntValue", 0)
end

local function createSound(parent, name, soundId, volume)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		if type(soundId) == "string" and soundId ~= "" then
			existing.SoundId = soundId
		end
		if volume ~= nil then
			existing.Volume = volume
		end
		return existing
	end

	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	sound.Parent = parent
	return sound
end

local function purgeExecutableDescendants(root)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			inst:Destroy()
		end
	end
end

local function ensureToolHandle(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end

	local fallbackAnchor = nil
	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("BasePart") then
			fallbackAnchor = inst
			break
		end
	end

	handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	if fallbackAnchor then
		handle.CFrame = fallbackAnchor.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = fallbackAnchor
		weld.Parent = handle
	end

	return handle
end

local function getToolGripForward(tool)
	if not tool then
		return Vector3.new(0, 0, -1)
	end

	local forward = tool.GripForward
	if typeof(forward) ~= "Vector3" or forward.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return forward.Unit
end

local function getMuzzleLocalOffset(tool, handle, padding)
	local forward = getToolGripForward(tool)
	local size = handle.Size
	local halfLength = (math.abs(forward.X) * size.X + math.abs(forward.Y) * size.Y + math.abs(forward.Z) * size.Z) * 0.5
	return forward * (halfLength + (padding or 0.2))
end

local function sanitizeTemplateTool(tool, weaponKey, weapon)
	purgeExecutableDescendants(tool)

	local detectedShotSoundId = nil
	local detectedReloadSoundId = nil

	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("Sound") then
			local soundId = tostring(inst.SoundId or "")
			if soundId ~= "" then
				local nameLower = string.lower(inst.Name)
				if not detectedShotSoundId
					and (string.find(nameLower, "fire", 1, true)
						or string.find(nameLower, "shot", 1, true)
						or string.find(nameLower, "shoot", 1, true))
				then
					detectedShotSoundId = soundId
				elseif not detectedReloadSoundId
					and (string.find(nameLower, "reload", 1, true)
						or string.find(nameLower, "mag", 1, true)
						or string.find(nameLower, "bolt", 1, true)
						or string.find(nameLower, "cock", 1, true))
				then
					detectedReloadSoundId = soundId
				end
			end
		end
	end

	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("Sound") then
			inst:Destroy()
		end
	end

	tool.Name = weapon.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponKey", weaponKey)

	local handle = ensureToolHandle(tool)
	if not handle then
		return nil
	end

	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = false
			inst.CanCollide = false
			inst.CanTouch = false
			inst.Massless = true
		end
	end

	if weapon.Category == "Ranged" then
		local muzzle = handle:FindFirstChild("Muzzle")
		if not (muzzle and muzzle:IsA("Attachment")) then
			muzzle = Instance.new("Attachment")
			muzzle.Name = "Muzzle"
			muzzle.Parent = handle
		end
		muzzle.Position = getMuzzleLocalOffset(tool, handle, 0.2)

		local shotSoundId = weapon.ShotSoundId
		if type(shotSoundId) ~= "string" or shotSoundId == "" then
			shotSoundId = detectedShotSoundId or ""
		end

		local reloadSoundId = weapon.ReloadSoundId
		if type(reloadSoundId) ~= "string" or reloadSoundId == "" then
			reloadSoundId = detectedReloadSoundId or ""
		end

		local shotSoundVolume = math.clamp(tonumber(weapon.ShotSoundVolume) or 0.6, 0, 2)
		local boltSoundVolume = math.clamp(tonumber(weapon.BoltSoundVolume) or 0.6, 0, 2)
		createSound(handle, "ShotSound", shotSoundId, shotSoundVolume)
		createSound(handle, "ReloadSound", reloadSoundId, 0.8)
		createSound(handle, "BoltSound", weapon.BoltSoundId, boltSoundVolume)
	else
		createSound(handle, "SwingSound", weapon.SwingSoundId, 0.9)
	end

	createSound(handle, "PickupSound", "rbxasset://sounds/unsheath.wav", 0.7)
	return tool
end

local function buildFallbackWeaponTool(weaponKey)
	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = weapon.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponKey", weaponKey)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(72, 72, 76)
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	if weaponKey == "Pistol" then
		handle.Size = Vector3.new(1, 0.85, 2)
	elseif weaponKey == "Rifle" then
		handle.Size = Vector3.new(1.2, 0.85, 3.6)
	elseif weaponKey == "Shotgun" then
		handle.Size = Vector3.new(1.15, 0.95, 3.4)
	elseif weaponKey == "Sniper" then
		handle.Size = Vector3.new(1.15, 0.9, 4.3)
	elseif weaponKey == "Bow" then
		handle.Size = Vector3.new(0.5, 3, 0.45)
		handle.Color = Color3.fromRGB(118, 83, 56)

		local stringPart = Instance.new("Part")
		stringPart.Name = "String"
		stringPart.Size = Vector3.new(0.08, 3.1, 0.08)
		stringPart.CanCollide = false
		stringPart.Massless = true
		stringPart.Material = Enum.Material.Neon
		stringPart.Color = Color3.fromRGB(220, 220, 220)
		stringPart.Parent = tool
		stringPart.CFrame = handle.CFrame * CFrame.new(0, 0, -0.25)

		local stringWeld = Instance.new("WeldConstraint")
		stringWeld.Part0 = handle
		stringWeld.Part1 = stringPart
		stringWeld.Parent = stringPart
	elseif weaponKey == "Bulava" then
		handle.Size = Vector3.new(0.45, 3.2, 0.45)
		handle.Color = Color3.fromRGB(99, 71, 46)

		local head = Instance.new("Part")
		head.Name = "MaceHead"
		head.Size = Vector3.new(1.2, 1.2, 1.2)
		head.Material = Enum.Material.Metal
		head.Color = Color3.fromRGB(155, 155, 160)
		head.CanCollide = false
		head.Massless = true
		head.Parent = tool
		head.CFrame = handle.CFrame * CFrame.new(0, 1.9, 0)

		local headWeld = Instance.new("WeldConstraint")
		headWeld.Part0 = handle
		headWeld.Part1 = head
		headWeld.Parent = head
	else
		handle.Size = Vector3.new(1, 1, 2.2)
	end

	if weapon.Category == "Ranged" then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = getMuzzleLocalOffset(tool, handle, 0.2)
		muzzle.Parent = handle

		local shotSoundVolume = math.clamp(tonumber(weapon.ShotSoundVolume) or 0.6, 0, 2)
		local boltSoundVolume = math.clamp(tonumber(weapon.BoltSoundVolume) or 0.6, 0, 2)
		createSound(handle, "ShotSound", weapon.ShotSoundId, shotSoundVolume)
		createSound(handle, "ReloadSound", weapon.ReloadSoundId, 0.8)
		createSound(handle, "BoltSound", weapon.BoltSoundId, boltSoundVolume)
	else
		createSound(handle, "SwingSound", weapon.SwingSoundId, 0.9)
	end

	createSound(handle, "PickupSound", "rbxasset://sounds/unsheath.wav", 0.7)
	return tool
end

local function buildWeaponTool(weaponKey)
	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return nil
	end

	local templateName = weapon.TemplateToolName or weapon.ToolName
	local templateFolders = {
		ServerStorage:FindFirstChild("WeaponTemplates"),
		Workspace:FindFirstChild("Weapon"),
	}

	for _, templateFolder in ipairs(templateFolders) do
		if templateFolder and templateFolder:IsA("Folder") then
			local templateTool = templateFolder:FindFirstChild(templateName)
			if templateTool and templateTool:IsA("Tool") then
				local clonedTemplate = templateTool:Clone()
				local sanitized = sanitizeTemplateTool(clonedTemplate, weaponKey, weapon)
				if sanitized then
					return sanitized
				end
			end
		end
	end

	return buildFallbackWeaponTool(weaponKey)
end

local function ensureToolInContainer(container, weaponKey)
	if not container then
		return
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return
	end

	if container:FindFirstChild(weapon.ToolName) then
		return
	end

	local tool = buildWeaponTool(weaponKey)
	if tool then
		tool.Parent = container
	end
end

local function purgeUnmanagedTools(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and not getWeaponKeyFromTool(child) then
			child:Destroy()
		end
	end
end

local function getEquippedWeaponKey(player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local key = getWeaponKeyFromTool(child)
			if key and weaponsByKey[key] then
				return key
			end
		end
	end

	return nil
end

local function getAmmoStateForWeapon(playerState, weaponKey)
	if not playerState or not weaponKey then
		return nil
	end

	local ammoState = playerState.ammoByWeapon[weaponKey]
	if ammoState then
		return ammoState
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return nil
	end

	ammoState = {
		mag = weapon.MaxMag,
		reserve = infiniteReserveAmmo and -1 or weapon.StartReserve,
	}
	playerState.ammoByWeapon[weaponKey] = ammoState
	return ammoState
end

local function sendCombatState(player)
	local playerState = stateByPlayer[player]
	if not playerState then
		return
	end

	local equippedWeaponKey = getEquippedWeaponKey(player)
	local payload = {
		reloading = playerState.reloading,
		equippedWeaponKey = equippedWeaponKey or "",
		equippedToolName = equippedWeaponKey and weaponsByKey[equippedWeaponKey].ToolName or "",
		mag = 0,
		reserve = 0,
	}

	if equippedWeaponKey then
		local weapon = weaponsByKey[equippedWeaponKey]
		if weapon and weapon.Category == "Ranged" then
			local ammoState = getAmmoStateForWeapon(playerState, equippedWeaponKey)
			if ammoState then
				payload.mag = ammoState.mag
				payload.reserve = ammoState.reserve
			end
		end
	end

	combatStateEvent:FireClient(player, payload)
end

local function ensureOwnedLoadout(player)
	local playerState = stateByPlayer[player]
	if not playerState then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	local starterGear = player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear", 5)
	local character = player.Character

	purgeUnmanagedTools(backpack)
	purgeUnmanagedTools(starterGear)
	purgeUnmanagedTools(character)

	for weaponKey, owned in pairs(playerState.ownedWeapons) do
		if owned then
			ensureToolInContainer(backpack, weaponKey)
			ensureToolInContainer(starterGear, weaponKey)
		end
	end
end

local function prepareWeaponTemplatesForRuntime()
	local workspaceFolder = Workspace:FindFirstChild("Weapon")
	if not (workspaceFolder and workspaceFolder:IsA("Folder")) then
		return
	end

	local storageFolder = ServerStorage:FindFirstChild("WeaponTemplates")
	if not storageFolder then
		storageFolder = Instance.new("Folder")
		storageFolder.Name = "WeaponTemplates"
		storageFolder.Parent = ServerStorage
	end

	for _, child in ipairs(workspaceFolder:GetChildren()) do
		if child:IsA("Tool") then
			child.Parent = storageFolder
		end
	end
end

local function getSelectedClassFromMeta(player)
	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression then
		return nil
	end

	local selectedClass = metaProgression:FindFirstChild("SelectedClass")
	if selectedClass and selectedClass:IsA("StringValue") then
		return normalizeClassKey(selectedClass.Value)
	end

	return nil
end

local function getSelectedClassFromJoinData(player)
	local joinData = nil
	local ok = pcall(function()
		joinData = player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return nil
	end

	local teleportData = joinData.TeleportData
	if type(teleportData) ~= "table" then
		return nil
	end

	local classByUserId = teleportData.selectedClassByUserId
	if type(classByUserId) == "table" then
		local byString = classByUserId[tostring(player.UserId)]
		if byString ~= nil then
			return normalizeClassKey(byString)
		end
		local byNumber = classByUserId[player.UserId]
		if byNumber ~= nil then
			return normalizeClassKey(byNumber)
		end
	end

	if teleportData.selectedClass ~= nil then
		return normalizeClassKey(teleportData.selectedClass)
	end

	return nil
end

local function resolveSelectedClassForPlayer(player)
	return getSelectedClassFromJoinData(player) or getSelectedClassFromMeta(player) or DEFAULT_CLASS_KEY
end

local function applyClassLoadout(player, playerState, classKey)
	local normalizedClass = normalizeClassKey(classKey)
	local classDefinition = classDefinitions[normalizedClass] or {}
	local starterWeapons = classDefinition.StarterWeapons

	table.clear(playerState.ownedWeapons)
	table.clear(playerState.ammoByWeapon)
	playerState.selectedClass = normalizedClass

	local addedAny = false
	if type(starterWeapons) == "table" then
		for _, weaponKey in ipairs(starterWeapons) do
			if weaponsByKey[weaponKey] then
				playerState.ownedWeapons[weaponKey] = true
				getAmmoStateForWeapon(playerState, weaponKey)
				addedAny = true
			end
		end
	end

	if not addedAny then
		for _, weaponKey in ipairs(combatConfig.DefaultOwnedWeapons) do
			if weaponsByKey[weaponKey] then
				playerState.ownedWeapons[weaponKey] = true
				getAmmoStateForWeapon(playerState, weaponKey)
			end
		end
	end

	if grantAllWeaponsOnSpawn then
		for weaponKey in pairs(weaponsByKey) do
			playerState.ownedWeapons[weaponKey] = true
			getAmmoStateForWeapon(playerState, weaponKey)
		end
	end

	player:SetAttribute("SelectedClass", normalizedClass)
end

local function playHandleSound(player, weaponKey, soundName, playbackSpeed)
	local character = player.Character
	if not character then
		return
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return
	end

	local tool = character:FindFirstChild(weapon.ToolName)
	if not tool then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local sound = handle:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		if tostring(sound.SoundId) == "" then
			return
		end
		if typeof(playbackSpeed) == "number" then
			sound.PlaybackSpeed = math.clamp(playbackSpeed, 0.65, 2.25)
		else
			sound.PlaybackSpeed = 1
		end
		sound:Play()
	end
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
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
	if not handle or not handle:IsA("BasePart") then
		return tool, nil
	end

	return tool, handle
end

local function getRangedFireOrigin(player, weapon)
	local tool, handle = getEquippedToolAndHandle(player, weapon)
	if handle then
		local muzzle = handle:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle.WorldPosition
		end

		local localOffset = getMuzzleLocalOffset(tool, handle, 0.2)
		return handle.CFrame:PointToWorldSpace(localOffset)
	end

	local root = getCharacterRoot(player)
	if root then
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

	return model:FindFirstChildOfClass("Humanoid")
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
	Debris:AddItem(creator, KILL_TAG_LIFETIME)
end

local function makeMuzzleFlash(origin, direction)
	if typeof(origin) ~= "Vector3" then
		return
	end

	local dir = direction
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.001 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Shape = Enum.PartType.Ball
	flash.Color = Color3.fromRGB(255, 210, 125)
	flash.Size = Vector3.new(0.24, 0.24, 0.24)
	flash.Transparency = 0.12
	flash.CFrame = CFrame.lookAt(origin + dir * 0.12, origin + dir)
	flash.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 2.8
	light.Range = 6
	light.Color = flash.Color
	light.Parent = flash

	local tween = TweenService:Create(
		flash,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.04, 0.04, 0.04),
			Transparency = 1,
		}
	)
	tween:Play()
	Debris:AddItem(flash, 0.09)
end

local function makeTracer(origin, hitPosition, shotDirection)
	if typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" then
		return
	end

	local toHit = hitPosition - origin
	local distance = toHit.Magnitude
	if distance <= 0.001 then
		return
	end

	local direction = shotDirection
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.001 then
		direction = toHit
	end
	local unitDirection = direction.Unit

	local tailPart = Instance.new("Part")
	tailPart.Name = "BulletTracerTail"
	tailPart.Anchored = true
	tailPart.CanCollide = false
	tailPart.CanTouch = false
	tailPart.CanQuery = false
	tailPart.Transparency = 1
	tailPart.Size = Vector3.new(0.05, 0.05, 0.05)
	tailPart.CFrame = CFrame.new(origin)
	tailPart.Parent = Workspace

	local headPart = Instance.new("Part")
	headPart.Name = "BulletTracerHead"
	headPart.Anchored = true
	headPart.CanCollide = false
	headPart.CanTouch = false
	headPart.CanQuery = false
	headPart.Transparency = 1
	headPart.Size = Vector3.new(0.05, 0.05, 0.05)
	headPart.CFrame = CFrame.new(origin)
	headPart.Parent = Workspace

	local tailAttachment = Instance.new("Attachment")
	tailAttachment.Parent = tailPart
	local headAttachment = Instance.new("Attachment")
	headAttachment.Parent = headPart

	local beam = Instance.new("Beam")
	beam.Name = "BulletTracerBeam"
	beam.Attachment0 = tailAttachment
	beam.Attachment1 = headAttachment
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Brightness = 4.8
	beam.Width0 = 0.22
	beam.Width1 = 0.14
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 244, 188), Color3.fromRGB(255, 216, 118))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.2, 0.08),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(0.72, 0.08),
		NumberSequenceKeypoint.new(0.9, 0.22),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	beam.Parent = tailPart

	local segmentLength = math.clamp(distance * 0.22, 5.5, TRACER_SEGMENT_LENGTH)
	local travelTime = math.clamp(distance / TRACER_SPEED, TRACER_MIN_TRAVEL_TIME, TRACER_MAX_TRAVEL_TIME)
	local cleanupAfter = travelTime + 0.18
	Debris:AddItem(tailPart, cleanupAfter)
	Debris:AddItem(headPart, cleanupAfter)

	task.spawn(function()
		local startTime = os.clock()
		while true do
			local elapsed = os.clock() - startTime
			local alpha = elapsed / travelTime
			if alpha >= 1 then
				break
			end

			local headDistance = distance * alpha
			local tailDistance = math.max(0, headDistance - segmentLength)
			headPart.CFrame = CFrame.new(origin + unitDirection * headDistance)
			tailPart.CFrame = CFrame.new(origin + unitDirection * tailDistance)
			task.wait()
		end

		headPart.CFrame = CFrame.new(hitPosition)
		tailPart.CFrame = CFrame.new(hitPosition - unitDirection * math.min(segmentLength, distance))
	end)
end

local function applySpread(unitDirection, spreadDegrees)
	if spreadDegrees <= 0 then
		return unitDirection
	end

	local spreadRadians = math.rad(spreadDegrees)
	local yaw = (math.random() * 2 - 1) * spreadRadians
	local pitch = (math.random() * 2 - 1) * spreadRadians
	local cf = CFrame.lookAt(Vector3.zero, unitDirection)
	return (cf * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function isPlayerNearShop(player)
	local shopsFolder = Workspace:FindFirstChild("Shops")
	local shopModel = shopsFolder and shopsFolder:FindFirstChild("WeaponShop")
	local npc = shopModel and shopModel:FindFirstChild("Shopkeeper")
	local prompt = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt or not prompt.Parent or not prompt.Parent:IsA("BasePart") then
		return false
	end

	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	local maxDistance = prompt.MaxActivationDistance + 2
	return (root.Position - prompt.Parent.Position).Magnitude <= maxDistance
end

local function fireSingleRay(player, weapon, damageOrigin, tracerOrigin, direction, damageMultiplier)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(damageOrigin, direction * weapon.Range, rayParams)
	local hitPosition = damageOrigin + direction * weapon.Range
	local dealtDamage = 0

	if result then
		hitPosition = result.Position
		local humanoid = findHumanoidFromPart(result.Instance)
		if humanoid and humanoid.Parent ~= player.Character then
			tagHumanoidDamageByPlayer(humanoid, player)
			local finalDamage = math.max(1, math.floor((weapon.Damage * (damageMultiplier or 1)) + 0.5))
			humanoid:TakeDamage(finalDamage)
			dealtDamage = finalDamage
		end
	end

	local tracerStart = tracerOrigin + direction.Unit * TRACER_MUZZLE_OFFSET
	makeTracer(tracerStart, hitPosition, direction)
	return dealtDamage, hitPosition
end

local handleReload

local function handleFire(player, payload)
	local playerState = stateByPlayer[player]
	if not playerState then
		return
	end

	if playerState.reloading then
		return
	end

	local weaponKey = getEquippedWeaponKey(player)
	if not weaponKey then
		return
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return
	end

	if os.clock() - playerState.lastShotAt < weapon.FireCooldown then
		return
	end

	local ammoState = getAmmoStateForWeapon(playerState, weaponKey)
	if not ammoState then
		return
	end

	if ammoState.mag <= 0 then
		if infiniteReserveAmmo or ammoState.reserve > 0 then
			handleReload(player)
		end
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local payloadDirection = payload.direction
	if typeof(payloadDirection) ~= "Vector3" then
		return
	end

	if payloadDirection.Magnitude < 0.01 then
		return
	end

	local unitDirection = payloadDirection.Unit
	local tracerOrigin = getRangedFireOrigin(player, weapon)
	if not tracerOrigin then
		return
	end

	local damageOrigin = tracerOrigin
	local rayOrigin = payload.rayOrigin
	local rayDirection = payload.rayDirection
	if typeof(rayOrigin) == "Vector3" and typeof(rayDirection) == "Vector3" and rayDirection.Magnitude > 0.01 then
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local anchorPart = (head and head:IsA("BasePart")) and head or ((root and root:IsA("BasePart")) and root or nil)
		if anchorPart and (rayOrigin - anchorPart.Position).Magnitude <= 16 then
			damageOrigin = rayOrigin
			unitDirection = rayDirection.Unit
		end
	end

	local targetPosition = payload.targetPosition
	local targetDistance = nil
	if typeof(targetPosition) == "Vector3" then
		local fromOrigin = targetPosition - damageOrigin
		if fromOrigin.Magnitude > 0.01 then
			unitDirection = fromOrigin.Unit
			targetDistance = fromOrigin.Magnitude
		end
	end

	local pellets = math.max(1, weapon.Pellets or 1)
	if pellets > 1 then
		-- For shotgun-like weapons, apply damage traces from muzzle to reduce near-range parallax misses.
		damageOrigin = tracerOrigin
		if typeof(targetPosition) == "Vector3" then
			local muzzleToTarget = targetPosition - damageOrigin
			if muzzleToTarget.Magnitude > 0.01 then
				unitDirection = muzzleToTarget.Unit
				targetDistance = muzzleToTarget.Magnitude
			end
		end
	end

	playerState.lastShotAt = os.clock()
	ammoState.mag -= 1
	sendCombatState(player)
	makeMuzzleFlash(tracerOrigin, unitDirection)
	playHandleSound(player, weaponKey, "ShotSound", tonumber(weapon.ShotSoundPlaybackSpeed) or 1)
	if type(weapon.BoltSoundId) == "string" and weapon.BoltSoundId ~= "" then
		local boltDelay = math.max(0, tonumber(weapon.BoltSoundDelay) or 0.15)
		local boltPlaybackSpeed = tonumber(weapon.BoltSoundPlaybackSpeed) or 1
		task.delay(boltDelay, function()
			playHandleSound(player, weaponKey, "BoltSound", boltPlaybackSpeed)
		end)
	end

	local spreadDegrees = 0
	if pellets > 1 then
		spreadDegrees = math.max(0, tonumber(weapon.SpreadDegrees) or 0)
		if targetDistance then
			local closeRangeSpreadFactor = math.clamp(targetDistance / 28, 0.18, 1)
			spreadDegrees *= closeRangeSpreadFactor
		end
	end
	local damageMultiplier = getRangedDamageMultiplier(player)
	local totalDamage = 0
	local hitCount = 0
	local feedbackWorldPosition = nil

	for _ = 1, pellets do
		local pelletDirection = applySpread(unitDirection, spreadDegrees)
		local dealtDamage, hitPosition =
			fireSingleRay(player, weapon, damageOrigin, tracerOrigin, pelletDirection, damageMultiplier)
		if dealtDamage > 0 then
			totalDamage += dealtDamage
			hitCount += 1
			feedbackWorldPosition = feedbackWorldPosition or hitPosition
		end
	end

	if hitCount > 0 then
		combatFeedbackEvent:FireClient(player, {
			type = "hit",
			damage = totalDamage,
			hitCount = hitCount,
			category = weapon.Category,
			worldPosition = feedbackWorldPosition,
		})
	end

	if ammoState.mag <= 0 and (infiniteReserveAmmo or ammoState.reserve > 0) then
		handleReload(player)
	end
end

handleReload = function(player)
	local playerState = stateByPlayer[player]
	if not playerState or playerState.reloading then
		return
	end

	local weaponKey = getEquippedWeaponKey(player)
	if not weaponKey then
		return
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return
	end

	local ammoState = getAmmoStateForWeapon(playerState, weaponKey)
	if not ammoState then
		return
	end

	if ammoState.mag >= weapon.MaxMag or (not infiniteReserveAmmo and ammoState.reserve <= 0) then
		return
	end

	playerState.reloading = true
	sendCombatState(player)
	playHandleSound(player, weaponKey, "ReloadSound")

	task.delay(weapon.ReloadTime, function()
		local currentState = stateByPlayer[player]
		if not currentState then
			return
		end

		local currentAmmo = getAmmoStateForWeapon(currentState, weaponKey)
		if not currentAmmo then
			currentState.reloading = false
			sendCombatState(player)
			return
		end

		if infiniteReserveAmmo then
			currentAmmo.mag = weapon.MaxMag
			currentAmmo.reserve = -1
		else
			local need = weapon.MaxMag - currentAmmo.mag
			local amount = math.min(need, currentAmmo.reserve)
			currentAmmo.mag += amount
			currentAmmo.reserve -= amount
		end
		currentState.reloading = false
		sendCombatState(player)
	end)
end

local function handleMeleeSwing(player, payload)
	local playerState = stateByPlayer[player]
	if not playerState then
		return
	end

	local weaponKey = getEquippedWeaponKey(player)
	if not weaponKey then
		return
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Melee" then
		return
	end

	local meleeCooldown = getEffectiveMeleeCooldown(player, weapon)
	if os.clock() - playerState.lastMeleeAt < meleeCooldown then
		return
	end

	playerState.lastMeleeAt = os.clock()
	playHandleSound(player, weaponKey, "SwingSound", (tonumber(weapon.Cooldown) or 0.75) / meleeCooldown)

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local facingDirection = root.CFrame.LookVector
	if typeof(payload) == "table" then
		local payloadDirection = payload.direction
		if typeof(payloadDirection) == "Vector3" then
			local planar = Vector3.new(payloadDirection.X, 0, payloadDirection.Z)
			if planar.Magnitude > 0.01 then
				facingDirection = planar.Unit
			end
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	overlapParams.FilterDescendantsInstances = { character }

	local center = root.Position + Vector3.new(0, 1.4, 0) + facingDirection * (weapon.Range * 0.5)
	local parts = Workspace:GetPartBoundsInRadius(center, weapon.Range, overlapParams)
	local hitModels = {}
	local damageMultiplier = getMeleeDamageMultiplier(player)
	local finalDamage = math.max(1, math.floor((weapon.Damage * damageMultiplier) + 0.5))
	local totalDamage = 0
	local hitCount = 0
	local feedbackWorldPosition = nil

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= character and not hitModels[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot then
				local toTarget = targetRoot.Position - root.Position
				local planarToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
				if planarToTarget.Magnitude > 0 and planarToTarget.Magnitude <= weapon.Range * 1.15 then
					local facingDot = facingDirection:Dot(planarToTarget.Unit)
					if facingDot > -0.25 then
						tagHumanoidDamageByPlayer(humanoid, player)
						humanoid:TakeDamage(finalDamage)
						hitModels[model] = true
						totalDamage += finalDamage
						hitCount += 1
						feedbackWorldPosition = feedbackWorldPosition or targetRoot.Position
					end
				end
			end
		end
	end

	if hitCount > 0 then
		combatFeedbackEvent:FireClient(player, {
			type = "hit",
			damage = totalDamage,
			hitCount = hitCount,
			category = weapon.Category,
			worldPosition = feedbackWorldPosition,
		})
	end
end

local function countNearbyPickupsForPlayer(player)
	local count = 0
	for _, obj in ipairs(pickupFolder:GetChildren()) do
		if obj:GetAttribute("OwnerUserId") == player.UserId then
			count += 1
		end
	end
	return count
end

local function getPreferredRangedWeaponKey(playerState, equippedWeaponKey)
	if equippedWeaponKey then
		local equippedWeapon = weaponsByKey[equippedWeaponKey]
		if equippedWeapon and equippedWeapon.Category == "Ranged" and playerState.ownedWeapons[equippedWeaponKey] then
			return equippedWeaponKey
		end
	end

	local fallbackWeaponKey = nil
	for _, weaponKey in ipairs(combatConfig.ShopOrder) do
		local weapon = weaponsByKey[weaponKey]
		if weapon and weapon.Category == "Ranged" then
			if playerState.ownedWeapons[weaponKey] then
				return weaponKey
			end
			if not fallbackWeaponKey then
				fallbackWeaponKey = weaponKey
			end
		end
	end

	return fallbackWeaponKey
end

local function spawnAmmoPickupForPlayer(player)
	local playerState = stateByPlayer[player]
	if not playerState then
		return
	end

	if countNearbyPickupsForPlayer(player) >= combatConfig.Pickups.MaxNearbyPerPlayer then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local angle = math.random() * math.pi * 2
	local radius = combatConfig.Pickups.MinRadius + math.random() * (combatConfig.Pickups.MaxRadius - combatConfig.Pickups.MinRadius)
	local position = root.Position + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)

	local pickup = Instance.new("Part")
	pickup.Name = "AmmoPickup"
	pickup.Size = Vector3.new(1.2, 1.2, 1.2)
	pickup.Shape = Enum.PartType.Ball
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromRGB(255, 219, 88)
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanQuery = true
	pickup.CanTouch = false
	pickup.Position = position
	pickup:SetAttribute("OwnerUserId", player.UserId)
	pickup.Parent = pickupFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Ammo"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = pickup

	local pickupSound = createSound(pickup, "PickupSound", "rbxasset://sounds/unsheath.wav", 0.9)
	local picked = false

	prompt.Triggered:Connect(function(triggeringPlayer)
		if picked or triggeringPlayer ~= player then
			return
		end

		local currentState = stateByPlayer[player]
		if not currentState then
			return
		end

		local rangedWeaponKey = getPreferredRangedWeaponKey(currentState, getEquippedWeaponKey(player))
		if not rangedWeaponKey then
			return
		end

		local weapon = weaponsByKey[rangedWeaponKey]
		local ammoState = getAmmoStateForWeapon(currentState, rangedWeaponKey)
		if not weapon or not ammoState then
			return
		end

		picked = true
		local amount = weapon.AmmoPackAmount or combatConfig.Pickups.DefaultAmmoAmount
		ammoState.reserve = math.min(weapon.MaxReserve, ammoState.reserve + amount)
		sendCombatState(player)

		prompt.Enabled = false
		pickup.Transparency = 1
		pickupSound:Play()
		task.delay(0.15, function()
			if pickup.Parent then
				pickup:Destroy()
			end
		end)
	end)

	Debris:AddItem(pickup, combatConfig.Pickups.Lifetime)
end

local function buildShopPayload(player, message)
	local playerState = stateByPlayer[player]
	local money = ensureMoneyStat(player).Value
	local items = {}

	for _, weaponKey in ipairs(combatConfig.ShopOrder) do
		local weapon = weaponsByKey[weaponKey]
		if weapon then
			table.insert(items, {
				key = weaponKey,
				displayName = weapon.DisplayName,
				category = weapon.Category,
				price = weapon.Price,
				owned = playerState and playerState.ownedWeapons[weaponKey] or false,
				ammoPackPrice = infiniteReserveAmmo and 0 or (weapon.AmmoPackPrice or 0),
				ammoPackAmount = infiniteReserveAmmo and 0 or (weapon.AmmoPackAmount or 0),
			})
		end
	end

	return {
		type = "open",
		message = message or "",
		money = money,
		items = items,
	}
end

local function openShopForPlayer(player, message)
	shopEvent:FireClient(player, buildShopPayload(player, message))
end

local function processBuyWeapon(player, weaponKey)
	local playerState = stateByPlayer[player]
	if not playerState then
		return "State error."
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon then
		return "Unknown weapon."
	end

	if playerState.ownedWeapons[weaponKey] then
		return weapon.DisplayName .. " already owned."
	end

	local money = ensureMoneyStat(player)
	if money.Value < weapon.Price then
		return "Not enough money."
	end

	money.Value -= weapon.Price
	playerState.ownedWeapons[weaponKey] = true
	getAmmoStateForWeapon(playerState, weaponKey)
	ensureOwnedLoadout(player)
	sendCombatState(player)
	return "Bought " .. weapon.DisplayName .. "."
end

local function processBuyAmmo(player, weaponKey)
	local playerState = stateByPlayer[player]
	if not playerState then
		return "State error."
	end

	if infiniteReserveAmmo then
		return "Ammo reserve is infinite in this mode."
	end

	local weapon = weaponsByKey[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return "Ammo is unavailable for this weapon."
	end

	if not playerState.ownedWeapons[weaponKey] then
		return "Buy weapon first."
	end

	local ammoState = getAmmoStateForWeapon(playerState, weaponKey)
	if not ammoState then
		return "Ammo state error."
	end

	if ammoState.reserve >= weapon.MaxReserve then
		return "Reserve ammo is already full."
	end

	local price = weapon.AmmoPackPrice or 0
	local amount = weapon.AmmoPackAmount or 0
	local money = ensureMoneyStat(player)
	if money.Value < price then
		return "Not enough money."
	end

	money.Value -= price
	ammoState.reserve = math.min(weapon.MaxReserve, ammoState.reserve + amount)
	sendCombatState(player)
	return "Bought ammo for " .. weapon.DisplayName .. "."
end

local function ensureShopNpc()
	local shopsFolder = Workspace:FindFirstChild("Shops")
	if not shopsFolder then
		shopsFolder = Instance.new("Folder")
		shopsFolder.Name = "Shops"
		shopsFolder.Parent = Workspace
	end

	local shopModel = shopsFolder:FindFirstChild("WeaponShop")
	if not shopModel then
		shopModel = Instance.new("Model")
		shopModel.Name = "WeaponShop"
		shopModel.Parent = shopsFolder

		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Size = Vector3.new(16, 1, 10)
		floor.Anchored = true
		floor.Material = Enum.Material.WoodPlanks
		floor.Color = Color3.fromRGB(117, 89, 62)
		floor.Position = Vector3.new(0, 1.5, -36)
		floor.Parent = shopModel

		local counter = Instance.new("Part")
		counter.Name = "Counter"
		counter.Size = Vector3.new(12, 3, 2)
		counter.Anchored = true
		counter.Material = Enum.Material.Wood
		counter.Color = Color3.fromRGB(144, 107, 76)
		counter.Position = floor.Position + Vector3.new(0, 2, 3.5)
		counter.Parent = shopModel

		local roof = Instance.new("Part")
		roof.Name = "Roof"
		roof.Size = Vector3.new(16, 1, 10)
		roof.Anchored = true
		roof.Material = Enum.Material.Metal
		roof.Color = Color3.fromRGB(52, 52, 58)
		roof.Position = floor.Position + Vector3.new(0, 7, 0)
		roof.Parent = shopModel

		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(6, 2, 0.6)
		sign.Anchored = true
		sign.Material = Enum.Material.Neon
		sign.Color = Color3.fromRGB(79, 168, 255)
		sign.Position = floor.Position + Vector3.new(0, 5.3, 4.5)
		sign.Parent = shopModel

		local signGui = Instance.new("SurfaceGui")
		signGui.Face = Enum.NormalId.Front
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		signGui.Parent = sign

		local signText = Instance.new("TextLabel")
		signText.BackgroundTransparency = 1
		signText.Size = UDim2.fromScale(1, 1)
		signText.Font = Enum.Font.GothamBlack
		signText.TextScaled = true
		signText.TextColor3 = Color3.fromRGB(15, 20, 30)
		signText.Text = "WEAPON SHOP"
		signText.Parent = signGui
	end

	local npc = shopModel:FindFirstChild("Shopkeeper")
	if not npc then
		npc = Instance.new("Model")
		npc.Name = "Shopkeeper"
		npc.Parent = shopModel

		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.Parent = npc

		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2.2, 2.5, 1.2)
		torso.Color = Color3.fromRGB(40, 88, 158)
		torso.Anchored = true
		torso.Parent = npc

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1.2, 1.2)
		head.Color = Color3.fromRGB(255, 219, 172)
		head.Anchored = true
		head.Parent = npc

		local humanoid = Instance.new("Humanoid")
		humanoid.DisplayName = "Arms Dealer"
		humanoid.Health = 100
		humanoid.MaxHealth = 100
		humanoid.BreakJointsOnDeath = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.Parent = npc

		local rootTorsoWeld = Instance.new("WeldConstraint")
		rootTorsoWeld.Part0 = root
		rootTorsoWeld.Part1 = torso
		rootTorsoWeld.Parent = torso

		local rootHeadWeld = Instance.new("WeldConstraint")
		rootHeadWeld.Part0 = root
		rootHeadWeld.Part1 = head
		rootHeadWeld.Parent = head

		local basePosition = Vector3.new(0, 3.5, -38.2)
		root.CFrame = CFrame.new(basePosition)
		torso.CFrame = root.CFrame
		head.CFrame = root.CFrame * CFrame.new(0, 1.8, 0)

		npc.PrimaryPart = root

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Open shop"
		prompt.ObjectText = "Arms Dealer"
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Parent = head
	end

	local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and not prompt:GetAttribute("Connected") then
		prompt:SetAttribute("Connected", true)
		prompt.Triggered:Connect(function(player)
			openShopForPlayer(player, "Welcome! Choose your weapon.")
		end)
	end
end

local function setupPlayer(player)
	local playerState = {
		ownedWeapons = {},
		ammoByWeapon = {},
		reloading = false,
		lastShotAt = 0,
		lastMeleeAt = 0,
		selectedClass = DEFAULT_CLASS_KEY,
	}
	stateByPlayer[player] = playerState

	local selectedClass = resolveSelectedClassForPlayer(player)
	applyClassLoadout(player, playerState, selectedClass)

	ensureOwnedLoadout(player)

	player.CharacterAdded:Connect(function(character)
		ensureOwnedLoadout(player)

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				if not getWeaponKeyFromTool(child) then
					child:Destroy()
					return
				end
				sendCombatState(player)
			end
		end)

		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				sendCombatState(player)
			end
		end)

		task.delay(0.2, function()
			sendCombatState(player)
		end)
	end)

	if player.Character then
		ensureOwnedLoadout(player)
		task.delay(0.2, function()
			sendCombatState(player)
		end)
	end
end

local function cleanupPlayer(player)
	stateByPlayer[player] = nil
end

ensureShopNpc()
prepareWeaponTemplatesForRuntime()

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

combatActionEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "shoot" or action == "fire" then
		handleFire(player, payload)
		return
	end

	if action == "reload" then
		handleReload(player)
		return
	end

	if action == "swing" or action == "melee" then
		handleMeleeSwing(player, payload)
	end
end)

shopEvent.OnServerEvent:Connect(function(player, action, weaponKey)
	if action == "open" or action == "refresh" then
		if not isPlayerNearShop(player) then
			return
		end
		openShopForPlayer(player, "")
		return
	end

	if action == "buyWeapon" then
		if not isPlayerNearShop(player) then
			return
		end
		local message = processBuyWeapon(player, tostring(weaponKey))
		openShopForPlayer(player, message)
		return
	end

	if action == "buyAmmo" then
		if not isPlayerNearShop(player) then
			return
		end
		local message = processBuyAmmo(player, tostring(weaponKey))
		openShopForPlayer(player, message)
	end
end)

if spawnAmmoPickups then
	task.spawn(function()
		while true do
			task.wait(combatConfig.Pickups.SpawnInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				spawnAmmoPickupForPlayer(player)
			end
		end
	end)
end
