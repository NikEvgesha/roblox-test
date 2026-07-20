local CombatFeedbackController = {}
CombatFeedbackController.__index = CombatFeedbackController

local DEFAULT_DAMAGE_NUMBER_LIFETIME = 0.75
local HIT_MARKER_DURATION = 0.11

function CombatFeedbackController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, CombatFeedbackController)
	self.workspace = assert(options.workspace, "CombatFeedbackController requires workspace")
	self.gui = assert(options.gui, "CombatFeedbackController requires gui")
	self.soundService = assert(options.soundService, "CombatFeedbackController requires soundService")
	self.damageNumberLifetime = tonumber(options.damageNumberLifetime) or DEFAULT_DAMAGE_NUMBER_LIFETIME
	self.hitMarkerTimer = 0
	self.activeDamageNumbers = {}

	local combatFxLayer = Instance.new("Frame")
	combatFxLayer.Name = "CombatFxLayer"
	combatFxLayer.Size = UDim2.fromScale(1, 1)
	combatFxLayer.BackgroundTransparency = 1
	combatFxLayer.BorderSizePixel = 0
	combatFxLayer.ZIndex = 50
	combatFxLayer.Parent = self.gui
	self.combatFxLayer = combatFxLayer

	local hitMarkerFrame = Instance.new("Frame")
	hitMarkerFrame.Name = "HitMarker"
	hitMarkerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarkerFrame.Position = UDim2.fromScale(0.5, 0.5)
	hitMarkerFrame.Size = UDim2.fromOffset(30, 30)
	hitMarkerFrame.BackgroundTransparency = 1
	hitMarkerFrame.Visible = false
	hitMarkerFrame.ZIndex = 55
	hitMarkerFrame.Parent = combatFxLayer
	self.hitMarkerFrame = hitMarkerFrame

	local hitMarkerLineA = Instance.new("Frame")
	hitMarkerLineA.Name = "LineA"
	hitMarkerLineA.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarkerLineA.Position = UDim2.fromScale(0.5, 0.5)
	hitMarkerLineA.Size = UDim2.fromOffset(3, 24)
	hitMarkerLineA.BackgroundColor3 = Color3.fromRGB(255, 240, 196)
	hitMarkerLineA.BorderSizePixel = 0
	hitMarkerLineA.Rotation = 45
	hitMarkerLineA.ZIndex = 55
	hitMarkerLineA.Parent = hitMarkerFrame
	self.hitMarkerLineA = hitMarkerLineA

	local hitMarkerLineB = Instance.new("Frame")
	hitMarkerLineB.Name = "LineB"
	hitMarkerLineB.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarkerLineB.Position = UDim2.fromScale(0.5, 0.5)
	hitMarkerLineB.Size = UDim2.fromOffset(3, 24)
	hitMarkerLineB.BackgroundColor3 = Color3.fromRGB(255, 240, 196)
	hitMarkerLineB.BorderSizePixel = 0
	hitMarkerLineB.Rotation = -45
	hitMarkerLineB.ZIndex = 55
	hitMarkerLineB.Parent = hitMarkerFrame
	self.hitMarkerLineB = hitMarkerLineB

	local hitConfirmSound = Instance.new("Sound")
	hitConfirmSound.Name = "HitConfirm"
	hitConfirmSound.SoundId = options.hitConfirmSoundId or ""
	hitConfirmSound.Volume = tonumber(options.hitConfirmVolume) or 0
	hitConfirmSound.Parent = self.soundService
	self.hitConfirmSound = hitConfirmSound

	return self
end

function CombatFeedbackController:GetHitMarkerFrame()
	return self.hitMarkerFrame
end

function CombatFeedbackController:ShowHitMarker(hitCount)
	self.hitMarkerTimer = HIT_MARKER_DURATION
	self.hitMarkerFrame.Visible = true
	local isMultiHit = (tonumber(hitCount) or 1) > 1
	local color = isMultiHit and Color3.fromRGB(255, 208, 140) or Color3.fromRGB(255, 240, 196)
	self.hitMarkerLineA.BackgroundColor3 = color
	self.hitMarkerLineB.BackgroundColor3 = color
end

function CombatFeedbackController:PlayHitConfirm(hitCount, isMelee)
	if tostring(self.hitConfirmSound.SoundId) == "" then
		return
	end
	self.hitConfirmSound.PlaybackSpeed = isMelee and 0.9 or math.clamp(1 + (tonumber(hitCount) or 1) * 0.02, 1, 1.2)
	self.hitConfirmSound.TimePosition = 0
	self.hitConfirmSound:Play()
end

function CombatFeedbackController:SpawnDamageNumber(worldPosition, damage, hitCount, isMelee)
	if typeof(worldPosition) ~= "Vector3" then
		return false
	end

	local label = Instance.new("TextLabel")
	label.Name = "DamageNumber"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(120, 34)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.TextStrokeTransparency = 0.35
	label.TextColor3 = isMelee and Color3.fromRGB(255, 188, 128) or Color3.fromRGB(255, 226, 154)
	label.Text = ("-%d"):format(math.max(1, math.floor(tonumber(damage) or 0)))
	label.ZIndex = 56
	label.Parent = self.combatFxLayer

	local count = math.max(1, math.floor(tonumber(hitCount) or 1))
	if count > 1 then
		label.Text = ("%s x%d"):format(label.Text, count)
	end
	table.insert(self.activeDamageNumbers, {
		label = label,
		worldPosition = worldPosition,
		age = 0,
		verticalRise = 4 + math.random() * 2,
		horizontalOffset = (math.random() - 0.5) * 2,
	})
	return true
end

function CombatFeedbackController:Handle(data)
	if typeof(data) ~= "table" or data.type ~= "hit" then
		return false
	end

	local damage = math.max(1, math.floor(tonumber(data.damage) or 0))
	local hitCount = math.max(1, math.floor(tonumber(data.hitCount) or 1))
	local isMelee = tostring(data.category) == "Melee"
	self:ShowHitMarker(hitCount)
	self:PlayHitConfirm(hitCount, isMelee)
	if typeof(data.worldPosition) == "Vector3" then
		self:SpawnDamageNumber(data.worldPosition, damage, hitCount, isMelee)
	end
	return true
end

function CombatFeedbackController:Update(deltaTime)
	if self.hitMarkerTimer > 0 then
		self.hitMarkerTimer = math.max(0, self.hitMarkerTimer - deltaTime)
		if self.hitMarkerTimer <= 0 then
			self.hitMarkerFrame.Visible = false
		end
	end

	local camera = self.workspace.CurrentCamera
	if not camera then
		return
	end
	for index = #self.activeDamageNumbers, 1, -1 do
		local entry = self.activeDamageNumbers[index]
		entry.age += deltaTime
		local progress = entry.age / self.damageNumberLifetime
		local label = entry.label
		if progress >= 1 or not label or not label.Parent then
			if label and label.Parent then
				label:Destroy()
			end
			table.remove(self.activeDamageNumbers, index)
		else
			local rise = entry.verticalRise * progress
			local worldPosition = entry.worldPosition
				+ Vector3.new(entry.horizontalOffset * progress, 2.4 + rise, 0)
			local viewportPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
			if onScreen and viewportPosition.Z > 0 then
				label.Visible = true
				label.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
			else
				label.Visible = false
			end
			label.TextTransparency = 0.08 + progress * 0.92
			label.TextStrokeTransparency = 0.35 + progress * 0.65
		end
	end
end

function CombatFeedbackController:Destroy()
	for _, entry in ipairs(self.activeDamageNumbers) do
		if entry.label and entry.label.Parent then
			entry.label:Destroy()
		end
	end
	table.clear(self.activeDamageNumbers)
	if self.combatFxLayer.Parent then
		self.combatFxLayer:Destroy()
	end
	if self.hitConfirmSound.Parent then
		self.hitConfirmSound:Destroy()
	end
end

return CombatFeedbackController
