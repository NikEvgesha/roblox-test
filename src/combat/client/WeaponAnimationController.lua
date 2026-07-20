local WeaponAnimationController = {}
WeaponAnimationController.__index = WeaponAnimationController

local function defaultDelay(seconds, callback)
	task.delay(seconds, callback)
end

local function loadTrack(humanoid, animationId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return humanoid:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		return nil
	end
	return track
end

function WeaponAnimationController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, WeaponAnimationController)
	self.player = assert(options.player, "WeaponAnimationController requires player")
	self.combatConfig = assert(options.combatConfig, "WeaponAnimationController requires combatConfig")
	self.loadTrack = options.loadTrack or loadTrack
	self.delay = options.delay or defaultDelay
	self.tracksByHumanoid = setmetatable({}, { __mode = "k" })
	return self
end

function WeaponAnimationController:PlayById(animationId, speed)
	if type(animationId) ~= "string" or animationId == "" then
		return nil
	end

	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local tracks = self.tracksByHumanoid[humanoid]
	if not tracks then
		tracks = {}
		self.tracksByHumanoid[humanoid] = tracks
	end

	local track = tracks[animationId]
	if not track then
		track = self.loadTrack(humanoid, animationId)
		if not track then
			return nil
		end
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		tracks[animationId] = track
	end

	if track.IsPlaying then
		track:Stop(0.04)
	end

	local playbackSpeed = tonumber(speed) or 1
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05, 1, playbackSpeed)
	track:AdjustSpeed(playbackSpeed)
	return track
end

function WeaponAnimationController:ClearCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.tracksByHumanoid[humanoid] = nil
	end
end

function WeaponAnimationController:PlayFire(weaponKey, meleeCooldown)
	local weapon = self.combatConfig.Weapons[weaponKey]
	if not weapon then
		return nil
	end

	if weapon.Category == "Ranged" then
		return self:PlayById(weapon.FireAnimationId, weapon.FireAnimationSpeed or 1)
	end
	if weapon.Category ~= "Melee" then
		return nil
	end

	local animationId = weapon.SwingAnimationId
	if type(animationId) ~= "string" or animationId == "" then
		animationId = weapon.SwingAltAnimationId
	end
	local baseSpeed = weapon.SwingAnimationSpeed or 1
	local targetCooldown = math.max(0.2, tonumber(meleeCooldown) or tonumber(weapon.Cooldown) or 0.75)
	local track = self:PlayById(animationId, 1)
	if not track then
		return nil
	end

	local trackLength = tonumber(track.Length) or 0
	if trackLength > 0.01 then
		local targetDuration = math.max(0.16, targetCooldown * 0.9)
		local speedScale = math.clamp(trackLength / targetDuration, 0.35, 3.5)
		track:AdjustSpeed(baseSpeed * speedScale)
	else
		track:AdjustSpeed(baseSpeed)
	end

	local stopAfter = math.max(0.12, math.min(targetCooldown, targetCooldown * 0.95))
	self.delay(stopAfter, function()
		if track and track.IsPlaying then
			track:Stop(0.08)
		end
	end)
	return track
end

function WeaponAnimationController:PlayReload(weaponKey)
	local weapon = self.combatConfig.Weapons[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return nil
	end
	return nil
end

return WeaponAnimationController
