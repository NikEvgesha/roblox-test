local SpectatorController = {}
SpectatorController.__index = SpectatorController

local DEFAULT_MOVE_SPEED = 36
local DEFAULT_FAST_MULTIPLIER = 2
local DEFAULT_SLOW_MULTIPLIER = 0.45
local DEFAULT_MOUSE_SENSITIVITY = 0.0025
local DEFAULT_MAX_PITCH = math.rad(82)

local INPUT_FIELD_BY_KEY = {
	[Enum.KeyCode.W] = "forward",
	[Enum.KeyCode.S] = "back",
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Space] = "up",
	[Enum.KeyCode.LeftControl] = "down",
	[Enum.KeyCode.C] = "down",
	[Enum.KeyCode.LeftShift] = "fast",
	[Enum.KeyCode.LeftAlt] = "slow",
}

local function noOp() end

function SpectatorController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, SpectatorController)
	self.player = assert(options.player, "SpectatorController requires player")
	self.workspace = assert(options.workspace, "SpectatorController requires workspace")
	self.userInputService = assert(options.userInputService, "SpectatorController requires userInputService")
	self.mouse = assert(options.mouse, "SpectatorController requires mouse")
	self.onModeChanged = options.onModeChanged or noOp
	self.moveSpeed = tonumber(options.moveSpeed) or DEFAULT_MOVE_SPEED
	self.fastMultiplier = tonumber(options.fastMultiplier) or DEFAULT_FAST_MULTIPLIER
	self.slowMultiplier = tonumber(options.slowMultiplier) or DEFAULT_SLOW_MULTIPLIER
	self.mouseSensitivity = tonumber(options.mouseSensitivity) or DEFAULT_MOUSE_SENSITIVITY
	self.maxPitch = tonumber(options.maxPitch) or DEFAULT_MAX_PITCH
	self.enabled = false
	self.downed = false
	self.lookActive = false
	self.position = Vector3.new(0, 10, 0)
	self.yaw = 0
	self.pitch = 0
	self.input = {
		forward = false,
		back = false,
		left = false,
		right = false,
		up = false,
		down = false,
		fast = false,
		slow = false,
	}
	return self
end

function SpectatorController:IsEnabled()
	return self.enabled
end

function SpectatorController:IsDowned()
	return self.downed
end

function SpectatorController:IsLookActive()
	return self.lookActive
end

function SpectatorController:ClearInput()
	for key in pairs(self.input) do
		self.input[key] = false
	end
end

function SpectatorController:SetLookActive(enabled)
	enabled = enabled == true and self.enabled
	if self.lookActive == enabled then
		return
	end

	self.lookActive = enabled
	if enabled then
		self.userInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		self.userInputService.MouseIconEnabled = false
		self.mouse.Icon = ""
	else
		self.userInputService.MouseBehavior = Enum.MouseBehavior.Default
		self.userInputService.MouseIconEnabled = true
		self.mouse.Icon = "rbxasset://SystemCursors/Arrow"
	end
end

function SpectatorController:RestoreGameplayCamera()
	local camera = self.workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function SpectatorController:SetEnabled(enabled)
	enabled = enabled == true
	if self.enabled == enabled then
		return
	end

	if enabled then
		self.enabled = true
		self.onModeChanged(true)
		self:ClearInput()
		self.lookActive = false

		local camera = self.workspace.CurrentCamera
		if camera then
			local cameraCFrame = camera.CFrame
			local look = cameraCFrame.LookVector
			self.position = cameraCFrame.Position
			self.pitch = math.asin(math.clamp(look.Y, -1, 1))
			self.yaw = math.atan2(-look.X, -look.Z)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraCFrame
		end

		self.userInputService.MouseBehavior = Enum.MouseBehavior.Default
		self.userInputService.MouseIconEnabled = true
		self.mouse.Icon = "rbxasset://SystemCursors/Arrow"
		return
	end

	self:SetLookActive(false)
	self:ClearInput()
	self.enabled = false
	self:RestoreGameplayCamera()
	self.userInputService.MouseBehavior = Enum.MouseBehavior.Default
	self.userInputService.MouseIconEnabled = true
	self.mouse.Icon = "rbxasset://SystemCursors/Arrow"
	self.onModeChanged(false)
end

function SpectatorController:SetDowned(downed)
	downed = downed == true
	if self.downed == downed and self.enabled == downed then
		return
	end

	self.downed = downed
	if not downed then
		self:SetLookActive(false)
	end
	self:SetEnabled(downed)
end

function SpectatorController:HandleInputBegan(input)
	if not self.enabled then
		return false
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:SetLookActive(true)
		return true
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end

	local field = INPUT_FIELD_BY_KEY[input.KeyCode]
	if not field then
		return false
	end
	self.input[field] = true
	return true
end

function SpectatorController:HandleInputEnded(input)
	if not self.enabled then
		return false
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:SetLookActive(false)
		return true
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end

	local field = INPUT_FIELD_BY_KEY[input.KeyCode]
	if not field then
		return false
	end
	self.input[field] = false
	return true
end

function SpectatorController:Update(deltaTime)
	if not self.enabled then
		return
	end

	if self.lookActive
		and not self.userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	then
		self:SetLookActive(false)
	end

	local camera = self.workspace.CurrentCamera
	if not camera then
		return
	end

	if self.lookActive then
		local mouseDelta = self.userInputService:GetMouseDelta()
		self.yaw -= mouseDelta.X * self.mouseSensitivity
		self.pitch = math.clamp(
			self.pitch - mouseDelta.Y * self.mouseSensitivity,
			-self.maxPitch,
			self.maxPitch
		)
	end

	local lookDirection = Vector3.new(
		-math.sin(self.yaw) * math.cos(self.pitch),
		math.sin(self.pitch),
		-math.cos(self.yaw) * math.cos(self.pitch)
	)
	local right = Vector3.new(math.cos(self.yaw), 0, -math.sin(self.yaw))
	local moveDirection = Vector3.zero

	if self.input.forward then
		moveDirection += lookDirection
	end
	if self.input.back then
		moveDirection -= lookDirection
	end
	if self.input.right then
		moveDirection += right
	end
	if self.input.left then
		moveDirection -= right
	end
	if self.input.up then
		moveDirection += Vector3.yAxis
	end
	if self.input.down then
		moveDirection -= Vector3.yAxis
	end

	local speed = self.moveSpeed
	if self.input.fast then
		speed *= self.fastMultiplier
	elseif self.input.slow then
		speed *= self.slowMultiplier
	end
	if moveDirection.Magnitude > 0 then
		self.position += moveDirection.Unit * speed * deltaTime
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(self.position, self.position + lookDirection)
end

return SpectatorController
