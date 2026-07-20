local WeaponController = {}
WeaponController.__index = WeaponController

local function noOp() end

function WeaponController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, WeaponController)
	self.player = assert(options.player, "WeaponController requires player")
	self.workspace = assert(options.workspace, "WeaponController requires workspace")
	self.combatConfig = assert(options.combatConfig, "WeaponController requires combatConfig")
	self.combatActionEvent = assert(options.combatActionEvent, "WeaponController requires combatActionEvent")
	self.getCurrentWeapon = assert(options.getCurrentWeapon, "WeaponController requires getCurrentWeapon")
	self.resolveRangedAimData = assert(options.resolveRangedAimData, "WeaponController requires resolveRangedAimData")
	self.findNearestEnemyRoot = assert(options.findNearestEnemyRoot, "WeaponController requires findNearestEnemyRoot")
	self.playFireAnimation = options.playFireAnimation or noOp
	self.playReloadAnimation = options.playReloadAnimation or noOp
	self.applyShotRecoil = options.applyShotRecoil or noOp
	self.canAct = options.canAct or function()
		return true
	end
	self.clock = options.clock or os.clock
	self.fireRangedOverride = options.fireRanged
	self.fireMeleeOverride = options.fireMelee
	self.meleeLockDistance = tonumber(options.meleeLockDistance) or 8
	self.primaryHeld = false
	self.nextAutoFireAt = 0
	self.reloading = false
	self.fireRateMultiplier = 1
	return self
end

function WeaponController:IsReloading()
	return self.reloading
end

function WeaponController:GetFireRateMultiplier()
	return self.fireRateMultiplier
end

function WeaponController:IsPrimaryHeld()
	return self.primaryHeld
end

function WeaponController:ApplyCombatState(data)
	if type(data) ~= "table" then
		return false
	end

	local wasReloading = self.reloading
	if typeof(data.reloading) == "boolean" then
		self.reloading = data.reloading
	end
	if typeof(data.fireRateMultiplier) == "number" then
		self.fireRateMultiplier = math.max(0.1, data.fireRateMultiplier)
	end

	local reloadStarted = not wasReloading and self.reloading
	if reloadStarted then
		local weaponKey, weapon = self.getCurrentWeapon()
		if weaponKey and weapon and weapon.Category == "Ranged" then
			self.playReloadAnimation(weaponKey)
		end
	end
	return reloadStarted
end

function WeaponController:FireRangedOnce(weaponKey, weapon)
	if self.fireRangedOverride then
		return self.fireRangedOverride(weaponKey, weapon) == true
	end

	local camera = self.workspace.CurrentCamera
	if not camera then
		return false
	end
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local targetPosition, rayDirection, rayOrigin = self.resolveRangedAimData(camera, character, root, weapon)
	local direction = rayDirection
	if direction.Magnitude < 0.01 then
		direction = camera.CFrame.LookVector
		rayDirection = direction
	end

	self.playFireAnimation(weaponKey)
	self.applyShotRecoil(weapon)
	self.combatActionEvent:FireServer("fire", {
		direction = direction,
		targetPosition = targetPosition,
		rayOrigin = rayOrigin,
		rayDirection = rayDirection,
	})
	return true
end

function WeaponController:FireMeleeOnce(weaponKey, weapon)
	if self.fireMeleeOverride then
		return self.fireMeleeOverride(weaponKey, weapon) == true
	end

	local now = self.clock()
	local progressionFolder = self.player:FindFirstChild("Progression")
	local metaProgressionFolder = self.player:FindFirstChild("MetaProgression")
	local speedSkillStat = progressionFolder and progressionFolder:FindFirstChild("SpeedLevel") or nil
	local speedMetaStat = metaProgressionFolder and metaProgressionFolder:FindFirstChild("Speed") or nil
	local speedSkillLevel = speedSkillStat and speedSkillStat:IsA("IntValue") and math.max(0, speedSkillStat.Value) or 0
	local speedMetaLevel = speedMetaStat and speedMetaStat:IsA("IntValue") and math.max(0, speedMetaStat.Value) or 0
	local speedSkillConfig = self.combatConfig.Progression and self.combatConfig.Progression.Skills
		and self.combatConfig.Progression.Skills.Speed
		or nil
	local speedMetaConfig = self.combatConfig.MetaProgression
		and self.combatConfig.MetaProgression.Upgrades
		and self.combatConfig.MetaProgression.Upgrades.Speed
		or nil
	local attackSpeedMultiplier = math.max(
		0.25,
		(tonumber(weapon.AttackSpeedMultiplier) or 1)
			+ speedSkillLevel * (tonumber(speedSkillConfig and speedSkillConfig.MeleeAttackSpeedPerLevel) or 0)
			+ speedMetaLevel * (tonumber(speedMetaConfig and speedMetaConfig.MeleeAttackSpeedPerLevel) or 0)
	)
	local meleeCooldown = math.max(0.2, (tonumber(weapon.Cooldown) or 0.75) / attackSpeedMultiplier)
	local nextMeleeAt = tonumber(self.player:GetAttribute("ClientNextMeleeAt")) or 0
	if now < nextMeleeAt then
		return false
	end
	self.player:SetAttribute("ClientNextMeleeAt", now + meleeCooldown)

	self.playFireAnimation(weaponKey, meleeCooldown)
	local payload = nil
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local lockRoot = self.findNearestEnemyRoot(root.Position, self.meleeLockDistance)
		if lockRoot then
			local direction = Vector3.new(
				lockRoot.Position.X - root.Position.X,
				0,
				lockRoot.Position.Z - root.Position.Z
			)
			if direction.Magnitude > 0.01 then
				payload = { direction = direction.Unit }
			end
		end
	end
	self.combatActionEvent:FireServer("melee", payload)
	return true
end

function WeaponController:HandlePrimaryDown()
	self.primaryHeld = true
	if self.reloading or not self.canAct() then
		return false
	end

	local weaponKey, weapon = self.getCurrentWeapon()
	if not weaponKey or not weapon then
		return false
	end
	if weapon.Category == "Ranged" then
		local fired = self:FireRangedOnce(weaponKey, weapon)
		if fired then
			self.nextAutoFireAt = self.clock() + math.max(0.03, (weapon.FireCooldown or 0.1) * 0.85)
		end
		return fired
	end
	return self:FireMeleeOnce(weaponKey, weapon)
end

function WeaponController:HandlePrimaryUp()
	self.primaryHeld = false
end

function WeaponController:RequestReload()
	if self.reloading or not self.canAct() or not (self.combatConfig.Ammo or {}).MagazinesEnabled then
		return false
	end

	local weaponKey, weapon = self.getCurrentWeapon()
	if not weaponKey or not weapon or weapon.Category ~= "Ranged" then
		return false
	end
	self.playReloadAnimation(weaponKey)
	self.combatActionEvent:FireServer("reload")
	return true
end

function WeaponController:Update()
	if not self.primaryHeld or self.reloading or not self.canAct() then
		return false
	end

	local weaponKey, weapon = self.getCurrentWeapon()
	if not weaponKey or not weapon or weapon.Category ~= "Ranged" then
		return false
	end
	local now = self.clock()
	if now < self.nextAutoFireAt then
		return false
	end

	local fired = self:FireRangedOnce(weaponKey, weapon)
	if fired then
		self.nextAutoFireAt = now
			+ math.max(0.03, ((weapon.FireCooldown or 0.1) / self.fireRateMultiplier) * 0.85)
	else
		self.nextAutoFireAt = now + 0.05
	end
	return fired
end

return WeaponController
