local CombatInputController = {}
CombatInputController.__index = CombatInputController

local function noOp() end

function CombatInputController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, CombatInputController)
	self.mouse = assert(options.mouse, "CombatInputController requires mouse")
	self.userInputService = assert(options.userInputService, "CombatInputController requires userInputService")
	self.spectatorController = assert(options.spectatorController, "CombatInputController requires spectatorController")
	self.weaponController = assert(options.weaponController, "CombatInputController requires weaponController")
	self.setAimEnabled = options.setAimEnabled or noOp
	self.isReviveUiVisible = options.isReviveUiVisible or function()
		return false
	end
	self.hasBlockingUiOpen = options.hasBlockingUiOpen or function()
		return false
	end
	self.openShop = options.openShop or noOp
	self.openSkills = options.openSkills or noOp
	self.connections = {}
	return self
end

function CombatInputController:HandlePrimaryDown()
	return self.weaponController:HandlePrimaryDown()
end

function CombatInputController:HandlePrimaryUp()
	self.weaponController:HandlePrimaryUp()
end

function CombatInputController:HandleInputBegan(input, gameProcessed)
	if gameProcessed then
		return false
	end
	if self.spectatorController:IsEnabled() then
		self.spectatorController:HandleInputBegan(input)
		return true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self.setAimEnabled(true)
		return true
	end
	if self.isReviveUiVisible() then
		return false
	end
	if input.KeyCode == Enum.KeyCode.B then
		self.setAimEnabled(false)
		self.openShop()
		return true
	end
	if input.KeyCode == Enum.KeyCode.K then
		self.setAimEnabled(false)
		self.openSkills()
		return true
	end
	if self.hasBlockingUiOpen() then
		return false
	end
	if input.KeyCode == Enum.KeyCode.R then
		return self.weaponController:RequestReload()
	end
	return false
end

function CombatInputController:HandleInputEnded(input)
	if self.spectatorController:IsEnabled() then
		self.spectatorController:HandleInputEnded(input)
		return true
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self.setAimEnabled(false)
		return true
	end
	return false
end

function CombatInputController:Start()
	if #self.connections > 0 then
		return
	end
	table.insert(self.connections, self.mouse.Button1Down:Connect(function()
		self:HandlePrimaryDown()
	end))
	table.insert(self.connections, self.mouse.Button1Up:Connect(function()
		self:HandlePrimaryUp()
	end))
	table.insert(self.connections, self.userInputService.InputBegan:Connect(function(input, gameProcessed)
		self:HandleInputBegan(input, gameProcessed)
	end))
	table.insert(self.connections, self.userInputService.InputEnded:Connect(function(input)
		self:HandleInputEnded(input)
	end))
end

function CombatInputController:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.weaponController:HandlePrimaryUp()
	self.setAimEnabled(false)
end

return CombatInputController
