local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossAbilityRuntime = {}
BossAbilityRuntime.__index = BossAbilityRuntime

local TELEGRAPH_COLORS = {
	Rockfall = Color3.fromRGB(255, 198, 74),
	Shockwave = Color3.fromRGB(76, 190, 255),
	FlameLanes = Color3.fromRGB(255, 126, 45),
	SummonBrood = Color3.fromRGB(181, 80, 255),
}

local function horizontalOffset(point, center)
	return Vector3.new(point.X - center.X, 0, point.Z - center.Z)
end

function BossAbilityRuntime.IsPointInCircle(point, center, radius)
	return horizontalOffset(point, center).Magnitude <= math.max(0, tonumber(radius) or 0)
end

function BossAbilityRuntime.IsPointInBox(point, boxCFrame, width, length)
	local localPoint = boxCFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= math.max(0, tonumber(width) or 0) * 0.5
		and math.abs(localPoint.Z) <= math.max(0, tonumber(length) or 0) * 0.5
end

local function isStateAlive(state)
	return state
		and not state.dead
		and state.model
		and state.model.Parent
		and state.humanoid
		and state.humanoid.Health > 0
		and state.root
		and state.root.Parent
end

function BossAbilityRuntime.new(options)
	options = type(options) == "table" and options or {}
	local self = setmetatable({}, BossAbilityRuntime)
	self.abilities = type(options.abilities) == "table" and options.abilities or {}
	self.zombiesFolder = options.zombiesFolder
	self.downedFolder = options.downedFolder
	self.spawnEnemy = options.spawnEnemy or function() end
	self.onCast = options.onCast or function() end
	self.isEncounterActive = options.isEncounterActive or function()
		return true
	end
	self.schedule = options.schedule or task.delay

	local effectsParent = options.effectsParent
	if not effectsParent then
		effectsParent = Workspace:FindFirstChild("BossTelegraphs")
		if not effectsParent then
			effectsParent = Instance.new("Folder")
			effectsParent.Name = "BossTelegraphs"
			effectsParent.Parent = Workspace
		end
	end
	self.effectsParent = effectsParent
	return self
end

function BossAbilityRuntime:_isActive(state)
	return self.isEncounterActive() and isStateAlive(state)
end

function BossAbilityRuntime:_trackEffect(state, instance)
	state.bossAbilityEffects = state.bossAbilityEffects or {}
	table.insert(state.bossAbilityEffects, instance)
	return instance
end

function BossAbilityRuntime:_newPart(state, name, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = self.effectsParent
	self:_trackEffect(state, part)
	return part
end

function BossAbilityRuntime:_createDisk(state, name, position, radius, color, lifetime)
	local disk = self:_newPart(state, name, color)
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(0.14, radius * 2, radius * 2)
	disk.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disk.Transparency = 0.42
	Debris:AddItem(disk, lifetime)
	return disk
end

function BossAbilityRuntime:_tween(instance, duration, properties, easingStyle)
	if not instance or not instance.Parent then
		return
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		properties
	)
	tween:Play()
end

function BossAbilityRuntime:_groundPosition(position)
	local filter = { self.effectsParent }
	if self.zombiesFolder then
		table.insert(filter, self.zombiesFolder)
	end
	if self.downedFolder then
		table.insert(filter, self.downedFolder)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = filter
	local result = Workspace:Raycast(position + Vector3.new(0, 55, 0), Vector3.new(0, -180, 0), params)
	return result and result.Position or Vector3.new(position.X, position.Y, position.Z)
end

function BossAbilityRuntime:_getTargets()
	local targets = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(targets, {
				player = player,
				character = character,
				humanoid = humanoid,
				root = root,
			})
		end
	end
	return targets
end

function BossAbilityRuntime:_showStun(character, duration)
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local old = head:FindFirstChild("BossStunIndicator")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossStunIndicator"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(70, 48, 20)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = "STUNNED"
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.TextScaled = true
	label.Parent = gui
	Debris:AddItem(gui, duration)
end

function BossAbilityRuntime:_applyStun(target, duration)
	local humanoid = target.humanoid
	local character = target.character
	if duration <= 0 or not humanoid or humanoid.Health <= 0 or not character then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local previousUntil = tonumber(character:GetAttribute("BossStunnedUntil")) or 0
	local stunUntil = math.max(previousUntil, now + duration)
	if previousUntil <= now then
		character:SetAttribute("BossPreStunWalkSpeed", humanoid.WalkSpeed)
		character:SetAttribute("BossPreStunJumpPower", humanoid.JumpPower)
		character:SetAttribute("BossPreStunJumpHeight", humanoid.JumpHeight)
	end
	character:SetAttribute("BossStunnedUntil", stunUntil)
	character:SetAttribute("BossStunned", true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	self:_showStun(character, duration)

	self.schedule(duration + 0.05, function()
		if not character.Parent or not humanoid.Parent then
			return
		end
		if Workspace:GetServerTimeNow() + 0.02 < (tonumber(character:GetAttribute("BossStunnedUntil")) or 0) then
			return
		end
		humanoid.WalkSpeed = tonumber(character:GetAttribute("BossPreStunWalkSpeed")) or 16
		humanoid.JumpPower = tonumber(character:GetAttribute("BossPreStunJumpPower")) or 50
		humanoid.JumpHeight = tonumber(character:GetAttribute("BossPreStunJumpHeight")) or 7.2
		character:SetAttribute("BossStunned", nil)
		character:SetAttribute("BossStunnedUntil", nil)
		character:SetAttribute("BossPreStunWalkSpeed", nil)
		character:SetAttribute("BossPreStunJumpPower", nil)
		character:SetAttribute("BossPreStunJumpHeight", nil)
	end)
end

function BossAbilityRuntime:_damageCircle(center, radius, damage, stunSeconds, knockbackSpeed)
	for _, target in ipairs(self:_getTargets()) do
		if BossAbilityRuntime.IsPointInCircle(target.root.Position, center, radius) then
			target.humanoid:TakeDamage(damage)
			if stunSeconds and stunSeconds > 0 then
				self:_applyStun(target, stunSeconds)
			end
			if knockbackSpeed and knockbackSpeed > 0 then
				local direction = horizontalOffset(target.root.Position, center)
				if direction.Magnitude > 0.01 then
					target.root.AssemblyLinearVelocity += direction.Unit * knockbackSpeed + Vector3.new(0, 18, 0)
				end
			end
		end
	end
end

function BossAbilityRuntime:_damageBox(boxCFrame, width, length, damage)
	for _, target in ipairs(self:_getTargets()) do
		if BossAbilityRuntime.IsPointInBox(target.root.Position, boxCFrame, width, length) then
			target.humanoid:TakeDamage(damage)
		end
	end
end

function BossAbilityRuntime:_impactDisk(state, position, radius, color)
	local impact = self:_createDisk(state, "BossImpact", position, radius, color, 0.35)
	impact.Transparency = 0.12
	self:_tween(impact, 0.3, { Transparency = 1 })
end

function BossAbilityRuntime:_castRockfall(state, ability, targets)
	local telegraphSeconds = tonumber(ability.TelegraphSeconds) or 1.5
	local radius = tonumber(ability.Radius) or 6
	local count = math.min(math.max(1, math.floor(tonumber(ability.RockCount) or 1)), #targets)
	for index = 1, count do
		local target = targets[index]
		local position = self:_groundPosition(target.root.Position)
		local disk = self:_createDisk(
			state,
			"RockfallTelegraph",
			position,
			radius,
			TELEGRAPH_COLORS.Rockfall,
			telegraphSeconds + 0.5
		)

		local rock = self:_newPart(state, "StunRock", Color3.fromRGB(92, 83, 72))
		rock.Shape = Enum.PartType.Ball
		rock.Material = Enum.Material.Slate
		rock.Size = Vector3.new(3.8, 3.8, 3.8)
		rock.Position = position + Vector3.new(0, tonumber(ability.RockHeight) or 34, 0)
		Debris:AddItem(rock, telegraphSeconds + 0.7)
		self:_tween(rock, telegraphSeconds, { Position = position + Vector3.new(0, 1.9, 0) })

		self.schedule(telegraphSeconds, function()
			if not self:_isActive(state) then
				return
			end
			if disk.Parent then
				disk:Destroy()
			end
			if rock.Parent then
				rock:Destroy()
			end
			self:_impactDisk(state, position, radius, Color3.fromRGB(255, 232, 160))
			self:_damageCircle(
				position,
				radius,
				state.attackDamage * (tonumber(ability.DamageMultiplier) or 1),
				tonumber(ability.StunSeconds) or 0,
				nil
			)
		end)
	end
	return telegraphSeconds
end

function BossAbilityRuntime:_castShockwave(state, ability)
	local telegraphSeconds = tonumber(ability.TelegraphSeconds) or 1.3
	local radius = tonumber(ability.Radius) or 20
	local position = self:_groundPosition(state.root.Position)
	local disk = self:_createDisk(
		state,
		"ShockwaveTelegraph",
		position,
		1,
		TELEGRAPH_COLORS.Shockwave,
		telegraphSeconds + 0.5
	)
	self:_tween(disk, telegraphSeconds, { Size = Vector3.new(0.14, radius * 2, radius * 2), Transparency = 0.55 })

	self.schedule(telegraphSeconds, function()
		if not self:_isActive(state) then
			return
		end
		if disk.Parent then
			disk:Destroy()
		end
		self:_impactDisk(state, position, radius, Color3.fromRGB(180, 235, 255))
		self:_damageCircle(
			position,
			radius,
			state.attackDamage * (tonumber(ability.DamageMultiplier) or 1),
			nil,
			tonumber(ability.KnockbackSpeed) or 0
		)
	end)
	return telegraphSeconds
end

function BossAbilityRuntime:_castFlameLanes(state, ability, targets)
	local telegraphSeconds = tonumber(ability.TelegraphSeconds) or 1.4
	local length = tonumber(ability.Length) or 36
	local width = tonumber(ability.Width) or 5
	local origin = self:_groundPosition(state.root.Position)
	local targetOffset = horizontalOffset(targets[1].root.Position, origin)
	local baseDirection = targetOffset.Magnitude > 0.01 and targetOffset.Unit or Vector3.new(0, 0, -1)
	local lanes = {}

	for _, degrees in ipairs(ability.LaneAngles or { -20, 0, 20 }) do
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(baseDirection)
		local center = origin + direction * (length * 0.5)
		local laneCFrame = CFrame.lookAt(center + Vector3.new(0, 0.08, 0), center + direction)
		local lane = self:_newPart(state, "FlameLaneTelegraph", TELEGRAPH_COLORS.FlameLanes)
		lane.Size = Vector3.new(width, 0.14, length)
		lane.CFrame = laneCFrame
		lane.Transparency = 0.42
		Debris:AddItem(lane, telegraphSeconds + 0.8)
		table.insert(lanes, { part = lane, cframe = laneCFrame })
	end

	self.schedule(telegraphSeconds, function()
		if not self:_isActive(state) then
			return
		end
		local damage = state.attackDamage * (tonumber(ability.DamageMultiplier) or 1)
		for _, laneState in ipairs(lanes) do
			local lane = laneState.part
			if lane.Parent then
				lane.Color = Color3.fromRGB(255, 65, 25)
				lane.Transparency = 0.12
				lane.Size = Vector3.new(width, 3.5, length)
				lane.CFrame = laneState.cframe + Vector3.new(0, 1.7, 0)
				self:_tween(lane, 0.55, { Transparency = 1 })
			end
			self:_damageBox(laneState.cframe, width, length, damage)
		end
	end)
	return telegraphSeconds
end

function BossAbilityRuntime:_castSummonBrood(state, ability)
	local telegraphSeconds = tonumber(ability.TelegraphSeconds) or 1.5
	local count = math.max(1, math.floor(tonumber(ability.SummonCount) or 3))
	local portalRadius = tonumber(ability.PortalRadius) or 3.5
	local variants = ability.SummonVariants or { "Needleling" }
	local positions = {}

	for index = 1, count do
		local angle = (index - 1) * math.pi * 2 / count
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 9
		local position = self:_groundPosition(state.root.Position + offset)
		positions[index] = position
		local portal = self:_createDisk(
			state,
			"BroodPortalTelegraph",
			position,
			portalRadius,
			TELEGRAPH_COLORS.SummonBrood,
			telegraphSeconds + 0.6
		)
		self:_tween(portal, telegraphSeconds, { Transparency = 0.15 })
	end

	self.schedule(telegraphSeconds, function()
		if not self:_isActive(state) then
			return
		end
		for index, position in ipairs(positions) do
			self:_impactDisk(state, position, portalRadius, Color3.fromRGB(226, 175, 255))
			self.spawnEnemy(position, variants[((index - 1) % #variants) + 1])
		end
	end)
	return telegraphSeconds
end

function BossAbilityRuntime:TryCast(state, now)
	if not self:_isActive(state) or not state.bossAbilityKey then
		return false
	end
	local ability = self.abilities[state.bossAbilityKey]
	if type(ability) ~= "table" or state.bossAbilityBusy then
		return false
	end

	local currentTime = tonumber(now) or os.clock()
	if state.nextBossAbilityAt == nil then
		state.nextBossAbilityAt = currentTime + math.max(0, tonumber(ability.InitialDelay) or 3)
		return false
	end
	if currentTime < state.nextBossAbilityAt then
		return false
	end

	local targets = self:_getTargets()
	if #targets == 0 then
		return false
	end

	state.nextBossAbilityAt = currentTime + math.max(0.5, tonumber(ability.Cooldown) or 8)
	state.bossAbilityBusy = true
	state.model:SetAttribute("BossAbilityCasting", state.bossAbilityKey)
	self.onCast(state)

	local castDuration
	if state.bossAbilityKey == "Rockfall" then
		castDuration = self:_castRockfall(state, ability, targets)
	elseif state.bossAbilityKey == "Shockwave" then
		castDuration = self:_castShockwave(state, ability)
	elseif state.bossAbilityKey == "FlameLanes" then
		castDuration = self:_castFlameLanes(state, ability, targets)
	elseif state.bossAbilityKey == "SummonBrood" then
		castDuration = self:_castSummonBrood(state, ability)
	else
		state.bossAbilityBusy = false
		state.model:SetAttribute("BossAbilityCasting", nil)
		return false
	end

	self.schedule((castDuration or 0) + 0.2, function()
		if state.model and state.model.Parent then
			state.model:SetAttribute("BossAbilityCasting", nil)
		end
		state.bossAbilityBusy = false
	end)
	return true
end

function BossAbilityRuntime:Cleanup(state)
	if not state then
		return
	end
	state.bossAbilityBusy = false
	if state.model and state.model.Parent then
		state.model:SetAttribute("BossAbilityCasting", nil)
	end
	for _, effect in ipairs(state.bossAbilityEffects or {}) do
		if effect and effect.Parent then
			effect:Destroy()
		end
	end
	state.bossAbilityEffects = nil
end

return BossAbilityRuntime
