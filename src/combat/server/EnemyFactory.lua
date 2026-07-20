local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameRules = require(sharedFolder:WaitForChild("GameRules"))
local ProceduralEnemyAnimator = require(script.Parent:WaitForChild("ProceduralEnemyAnimator"))

local EnemyFactory = {}
EnemyFactory.__index = EnemyFactory

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

local function noOp() end

function EnemyFactory.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, EnemyFactory)
	self.config = assert(options.config, "EnemyFactory requires config")
	self.variants = assert(options.variants, "EnemyFactory requires variants")
	self.enemyFolder = assert(options.enemyFolder, "EnemyFactory requires an enemy folder")
	self.spawnPointsFolder = assert(options.spawnPointsFolder, "EnemyFactory requires a spawn-points folder")
	self.downedFolder = assert(options.downedFolder, "EnemyFactory requires a downed folder")
	self.templateSearchRoot = options.templateSearchRoot or Workspace
	self.templateAssetsFolder = options.templateAssetsFolder
	self.getDifficultyMultipliers = assert(
		options.getDifficultyMultipliers,
		"EnemyFactory requires getDifficultyMultipliers"
	)
	self.sanitizeTemplateContent = options.sanitizeTemplateContent or noOp
	self.onCreated = options.onCreated or noOp
	self.onKilled = options.onKilled or noOp
	self.onRemoved = options.onRemoved or noOp
	self.resolveGroundYOverride = options.resolveGroundY
	self.schedule = options.schedule or function(delaySeconds, callback)
		task.delay(delaySeconds, callback)
	end
	self.deathLingerSeconds = math.max(0, tonumber(options.deathLingerSeconds) or 2)
	self.keyframeSequenceProvider = options.keyframeSequenceProvider or KeyframeSequenceProvider
	self.templateCache = {}
	self.deathHandlers = {}
	self.removeHandlers = {}
	return self
end

function EnemyFactory:_resolveGroundY(position)
	if self.resolveGroundYOverride then
		return self.resolveGroundYOverride(position)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { self.enemyFolder, self.spawnPointsFolder, self.downedFolder }

	local result = Workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -180, 0), rayParams)
	return result and result.Position.Y or position.Y
end

function EnemyFactory:_isUsableTemplateModel(instance)
	if not instance or not instance:IsA("Model") then
		return false
	end

	local hasBasePart = instance:FindFirstChildWhichIsA("BasePart", true)
	local hasHumanoid = instance:FindFirstChildOfClass("Humanoid")
	return hasBasePart ~= nil and hasHumanoid ~= nil
end

function EnemyFactory:_findTemplate(templateName)
	if type(templateName) ~= "string" or templateName == "" then
		return nil
	end

	local cached = self.templateCache[templateName]
	if cached and cached.Parent then
		return cached
	end

	local assetsFolder = self.templateAssetsFolder
	if not assetsFolder and self.templateSearchRoot then
		assetsFolder = self.templateSearchRoot:FindFirstChild("Enemy")
	end
	if assetsFolder then
		for _, instance in ipairs(assetsFolder:GetDescendants()) do
			if instance.Name == templateName and self:_isUsableTemplateModel(instance) then
				self.templateCache[templateName] = instance
				return instance
			end
		end
	end

	if self.templateSearchRoot then
		for _, instance in ipairs(self.templateSearchRoot:GetDescendants()) do
			if instance.Name == templateName
				and self:_isUsableTemplateModel(instance)
				and not instance:IsDescendantOf(self.enemyFolder)
				and not instance:IsDescendantOf(self.downedFolder)
			then
				self.templateCache[templateName] = instance
				return instance
			end
		end
	end

	return nil
end

function EnemyFactory:_findTemplateRootPart(model)
	local root = model:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		return root
	end

	local primaryPart = model.PrimaryPart
	if primaryPart and primaryPart:IsA("BasePart") then
		return primaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

function EnemyFactory:_findFirstNamedKeyframeSequence(root, names)
	if not root or type(names) ~= "table" then
		return nil
	end

	local sequences = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("KeyframeSequence") then
			table.insert(sequences, descendant)
		end
	end

	for _, wantedName in ipairs(names) do
		local wanted = string.lower(tostring(wantedName))
		for _, sequence in ipairs(sequences) do
			if string.lower(sequence.Name) == wanted then
				return sequence
			end
		end
	end

	for _, wantedName in ipairs(names) do
		local wanted = string.lower(tostring(wantedName))
		for _, sequence in ipairs(sequences) do
			if string.find(string.lower(sequence.Name), wanted, 1, true) then
				return sequence
			end
		end
	end

	return nil
end

function EnemyFactory:_findFirstNamedAnimation(root, names)
	if not root or type(names) ~= "table" then
		return nil
	end

	local animations = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Animation") and tostring(descendant.AnimationId or "") ~= "" then
			table.insert(animations, descendant)
		end
	end

	for _, wantedName in ipairs(names) do
		local wanted = string.lower(tostring(wantedName))
		for _, animation in ipairs(animations) do
			if string.lower(animation.Name) == wanted then
				return animation
			end
		end
	end

	for _, wantedName in ipairs(names) do
		local wanted = string.lower(tostring(wantedName))
		for _, animation in ipairs(animations) do
			if string.find(string.lower(animation.Name), wanted, 1, true) then
				return animation
			end
		end
	end

	return nil
end

function EnemyFactory:_loadTrackFromKeyframeSequence(animator, sequence, looped, priority)
	if not animator or not sequence then
		return nil
	end

	local okRegister, registeredId = pcall(function()
		return self.keyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not okRegister or type(registeredId) ~= "string" or registeredId == "" then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = registeredId
	local okLoad, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not okLoad or not track then
		return nil
	end

	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Movement
	return track
end

function EnemyFactory:_loadTrackFromAnimation(animator, sourceAnimation, looped, priority)
	if not animator or not sourceAnimation or not sourceAnimation:IsA("Animation") then
		return nil
	end

	local animationId = tostring(sourceAnimation.AnimationId or "")
	if animationId == "" then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local okLoad, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not okLoad or not track then
		return nil
	end

	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Movement
	return track
end

function EnemyFactory:_buildAnimationTracks(model, humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local keyframeRoot = model:FindFirstChild("AnimSaves", true) or model
	local tracks = {
		idle = self:_loadTrackFromAnimation(
			animator,
			self:_findFirstNamedAnimation(model, { "Idle", "IdleAnim", "ToolNoneAnim", "Stand", "Breath" }),
			true,
			Enum.AnimationPriority.Movement
		) or self:_loadTrackFromKeyframeSequence(
			animator,
			self:_findFirstNamedKeyframeSequence(keyframeRoot, { "Idle" }),
			true,
			Enum.AnimationPriority.Movement
		),
		walk = self:_loadTrackFromAnimation(
			animator,
			self:_findFirstNamedAnimation(model, { "WalkAnim", "RunAnim", "Walk", "Run" }),
			true,
			Enum.AnimationPriority.Movement
		) or self:_loadTrackFromKeyframeSequence(
			animator,
			self:_findFirstNamedKeyframeSequence(keyframeRoot, { "Walk", "Run", "CursedGolemWalk" }),
			true,
			Enum.AnimationPriority.Movement
		),
		attack = self:_loadTrackFromAnimation(
			animator,
			self:_findFirstNamedAnimation(model, { "Attack", "AttackAnim", "Hit", "Slash", "Stab" }),
			false,
			Enum.AnimationPriority.Action
		) or self:_loadTrackFromKeyframeSequence(
			animator,
			self:_findFirstNamedKeyframeSequence(keyframeRoot, { "Attack", "Hit", "Slash" }),
			false,
			Enum.AnimationPriority.Action
		),
	}

	if not tracks.idle and not tracks.walk and not tracks.attack then
		return nil
	end
	return tracks
end

function EnemyFactory:CleanupAnimationTracks(state)
	if not state or not state.animationTracks then
		return
	end

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

function EnemyFactory:_prepareTemplateModel(position, variant, variantKey, health, moveSpeed)
	local template = self:_findTemplate(variant.TemplateModelName)
	if not template then
		return nil
	end

	local model = template:Clone()
	self.sanitizeTemplateContent(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = model
	end
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = moveSpeed
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local root = self:_findTemplateRootPart(model)
	if not root then
		model:Destroy()
		return nil
	end

	if root.Name ~= "HumanoidRootPart" then
		local syntheticRoot = Instance.new("Part")
		syntheticRoot.Name = "HumanoidRootPart"
		syntheticRoot.Size = Vector3.new(2, 2, 1)
		syntheticRoot.Transparency = 1
		syntheticRoot.Anchored = true
		syntheticRoot.CanCollide = false
		syntheticRoot.CanTouch = false
		syntheticRoot.CanQuery = true
		syntheticRoot.CFrame = root.CFrame
		syntheticRoot.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = syntheticRoot
		weld.Part1 = root
		weld.Parent = syntheticRoot
		root = syntheticRoot
	end

	local templateScale = tonumber(variant.TemplateScale)
	if templateScale and templateScale > 0 then
		pcall(function()
			model:ScaleTo(templateScale)
		end)
	end

	for _, instance in ipairs(model:GetDescendants()) do
		if instance:IsA("BasePart") then
			instance.Anchored = instance == root
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = true
			instance.Massless = true
			if instance == root then
				instance.Transparency = 1
			end
		end
	end

	local head = model:FindFirstChild("Head", true)
	if not (head and head:IsA("BasePart")) then
		head = root
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local groundY = self:_resolveGroundY(position)
	local boundsBottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
	local rootHeightAboveBottom = math.max(0, root.Position.Y - boundsBottomY)
	local spawnPosition = Vector3.new(
		position.X,
		groundY + rootHeightAboveBottom + 0.1 + (variant.FlyHeight or 0),
		position.Z
	)

	model.Name = "Zombie_" .. variantKey
	model:SetAttribute("IsZombie", true)
	model:SetAttribute("ZombieVariant", variantKey)
	model.PrimaryPart = root
	model:PivotTo(CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, -1)))
	return model, humanoid, root, head
end

function EnemyFactory:_createFallbackModel(position, variant, variantKey, health, moveSpeed)
	local bodyScaleY = variant.ScaleY or 1
	local model = Instance.new("Model")
	model.Name = "Zombie_" .. variantKey
	model:SetAttribute("IsZombie", true)
	model:SetAttribute("ZombieVariant", variantKey)

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = moveSpeed
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 2.6 * bodyScaleY, 1.4)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = colorFromRgbArray(variant.Color, Color3.fromRGB(77, 142, 74))
	torso.Anchored = true
	torso.CanCollide = true
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1.2 * bodyScaleY, 1.2)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = colorFromRgbArray(variant.HeadColor, Color3.fromRGB(101, 170, 95))
	head.Anchored = true
	head.CanCollide = true
	head.Parent = model

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local rootToTorso = Instance.new("WeldConstraint")
	rootToTorso.Part0 = root
	rootToTorso.Part1 = torso
	rootToTorso.Parent = torso
	local rootToHead = Instance.new("WeldConstraint")
	rootToHead.Part0 = root
	rootToHead.Part1 = head
	rootToHead.Parent = head

	local groundY = self:_resolveGroundY(position)
	local baseYOffset = torso.Size.Y * 0.5 + 0.1
	root.CFrame = CFrame.new(position.X, groundY + baseYOffset + (variant.FlyHeight or 0), position.Z)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.8 * bodyScaleY, 0)
	model.PrimaryPart = root
	return model, humanoid, root, head
end

function EnemyFactory:_attachHealthBar(model, humanoid, head, title)
	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "ZombieHealthGui"
	healthGui.Size = UDim2.fromOffset(140, 24)
	healthGui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	healthGui.AlwaysOnTop = true
	healthGui.MaxDistance = 180
	healthGui.Adornee = head
	healthGui.Parent = model

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	background.BorderSizePixel = 0
	background.Parent = healthGui

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 7)
	backgroundCorner.Parent = background

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(88, 214, 115)
	fill.BorderSizePixel = 0
	fill.Parent = background

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
	label.Parent = background

	local function updateBar()
		local maxHealth = math.max(1, humanoid.MaxHealth)
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / maxHealth, 0, 1), 1)
		label.Text = ("%s %d/%d"):format(title, math.ceil(humanoid.Health), math.floor(maxHealth))
	end
	humanoid.HealthChanged:Connect(updateBar)
	updateBar()
end

function EnemyFactory:_attachDeathLifecycle(model, state)
	local removed = false
	local function removeOnce()
		if removed then
			return
		end
		removed = true
		self.deathHandlers[model] = nil
		self.removeHandlers[model] = nil
		self.onRemoved(model, state)
	end

	local function handleDeath()
		if state.dead then
			return
		end
		state.dead = true
		state.humanoid.Health = 0
		self.onKilled(state)
		removeOnce()
		self.schedule(self.deathLingerSeconds, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end

	state.humanoid.Died:Connect(handleDeath)
	state.humanoid.HealthChanged:Connect(function(currentHealth)
		if currentHealth <= 0 then
			handleDeath()
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeOnce()
		end
	end)
	self.deathHandlers[model] = handleDeath
	self.removeHandlers[model] = removeOnce
end

function EnemyFactory:Kill(model)
	local handler = self.deathHandlers[model]
	if not handler then
		return false
	end
	handler()
	return true
end

function EnemyFactory:Remove(model)
	local handler = self.removeHandlers[model]
	if not handler then
		return false
	end
	handler()
	return true
end

function EnemyFactory:Create(position, requestedVariantKey, stage)
	local variant = self.variants[requestedVariantKey] or self.variants.Walker
	assert(variant, "EnemyFactory requires a Walker fallback variant")
	local variantKey = self.variants[requestedVariantKey] and requestedVariantKey or "Walker"
	local normalizedStage = math.max(0, tonumber(stage) or 0)
	local multipliers = self.getDifficultyMultipliers()
	local config = self.config

	local health = gameRules.GetScaledValue(
		config.BaseHealth,
		config.HealthScalePerStage,
		normalizedStage,
		(variant.HealthMul or 1) * multipliers.health
	)
	local moveSpeed = gameRules.GetScaledValue(
		config.BaseMoveSpeed,
		config.SpeedScalePerStage,
		normalizedStage,
		variant.MoveSpeedMul or 1
	)
	local attackDamage = gameRules.GetScaledValue(
		config.BaseAttackDamage,
		config.DamageScalePerStage,
		normalizedStage,
		(variant.DamageMul or 1) * multipliers.damage
	)
	local rewardMoney = gameRules.GetScaledValue(
		config.BaseRewardMoney,
		config.RewardScalePerStage,
		normalizedStage,
		(variant.RewardMul or 1) * multipliers.reward
	)
	local rewardXP = gameRules.GetScaledValue(
		config.BaseRewardXP,
		config.RewardScalePerStage,
		normalizedStage,
		(variant.RewardMul or 1) * multipliers.reward
	)

	local model, humanoid, root, head = self:_prepareTemplateModel(position, variant, variantKey, health, moveSpeed)
	if not model then
		model, humanoid, root, head = self:_createFallbackModel(position, variant, variantKey, health, moveSpeed)
	end

	local isFlyer = variant.IsFlyer == true or variantKey == "Flyer"
	if isFlyer then
		local leftWing = Instance.new("Part")
		leftWing.Name = "LeftWing"
		leftWing.Size = Vector3.new(0.2, 1.2, 3.2)
		leftWing.Material = Enum.Material.Neon
		leftWing.Color = Color3.fromRGB(173, 164, 255)
		leftWing.CanCollide = false
		leftWing.Massless = true
		leftWing.Parent = model
		local rightWing = leftWing:Clone()
		rightWing.Name = "RightWing"
		rightWing.Parent = model
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

	model.Parent = self.enemyFolder
	model:SetAttribute("IsBossZombie", variant.IsBoss == true)
	local proceduralAnimation = ProceduralEnemyAnimator.Capture(model, variant.ProceduralAnimationStyle)
	local animationTracks = proceduralAnimation and nil or self:_buildAnimationTracks(model, humanoid)
	self:_attachHealthBar(model, humanoid, head, variant.DisplayName or variantKey)

	local state = {
		model = model,
		humanoid = humanoid,
		root = root,
		animationTracks = animationTracks,
		proceduralAnimation = proceduralAnimation,
		variantKey = variantKey,
		variant = variant,
		moveSpeed = moveSpeed,
		attackDamage = attackDamage,
		attackRange = config.BaseAttackRange,
		attackCooldown = math.max(0.35, config.BaseAttackCooldown / (1 + normalizedStage * 0.02)),
		rewardMoney = rewardMoney,
		rewardXP = rewardXP,
		bossCrystals = math.max(0, math.floor((variant.BossCrystalDrop or 0) * multipliers.crystal + 0.5)),
		lastAttack = 0,
		lastSpit = 0,
		dead = false,
		exploded = false,
		isFlyer = isFlyer,
		isSpitter = variant.IsSpitter == true or variantKey == "Spitter",
		isBomber = variant.IsBomber == true or variantKey == "Bomber",
		spitRange = variant.SpitRange or 0,
		spitDamage = (variant.SpitDamage or 0)
			* (1 + normalizedStage * config.DamageScalePerStage)
			* multipliers.damage,
		spitCooldown = variant.SpitCooldown or 0,
		spitProjectileSpeed = variant.SpitProjectileSpeed or 0,
		explosionRange = variant.ExplosionRange or 0,
		explosionDamage = (variant.ExplosionDamage or 0)
			* (1 + normalizedStage * config.DamageScalePerStage)
			* multipliers.damage,
		explosionTriggerRange = variant.ExplosionTriggerRange or 0,
		flyHeight = variant.FlyHeight or 0,
		isBoss = variant.IsBoss == true,
		visualPhase = math.random() * math.pi * 2,
		attackAnimDuration = math.max(0.05, tonumber(variant.AttackAnimationDuration) or 0.24),
		attackAnimStartedAt = 0,
		attackAnimEndsAt = 0,
		lastMoveAnimated = false,
	}

	self.onCreated(model, state)
	self:_attachDeathLifecycle(model, state)
	return model, state
end

return EnemyFactory
