local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local abilityConfig = require(sharedFolder:WaitForChild("AbilityConfig"))
local abilityEvent = ReplicatedStorage:WaitForChild(abilityConfig.EventName)

local currentState = {
	professionDisplayName = "Profession",
	resourceDisplayName = "Resource",
	resource = 0,
	maxResource = 0,
	stanceKey = "",
	stances = {},
	abilities = {},
	message = "",
}

local gui = Instance.new("ScreenGui")
gui.Name = "AbilityHudGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 1)
root.Position = UDim2.new(0, 18, 1, -18)
root.Size = UDim2.fromOffset(430, 128)
root.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
root.BackgroundTransparency = 0.16
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = root

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 8)
titleLabel.Size = UDim2.fromOffset(250, 22)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
titleLabel.Text = "Profession"
titleLabel.Parent = root

local stanceLabel = Instance.new("TextLabel")
stanceLabel.Name = "Stance"
stanceLabel.BackgroundTransparency = 1
stanceLabel.Position = UDim2.fromOffset(270, 8)
stanceLabel.Size = UDim2.fromOffset(150, 22)
stanceLabel.Font = Enum.Font.GothamBold
stanceLabel.TextSize = 14
stanceLabel.TextXAlignment = Enum.TextXAlignment.Right
stanceLabel.TextColor3 = Color3.fromRGB(178, 214, 255)
stanceLabel.Text = ""
stanceLabel.Parent = root

local resourceBack = Instance.new("Frame")
resourceBack.Name = "ResourceBack"
resourceBack.Position = UDim2.fromOffset(12, 36)
resourceBack.Size = UDim2.fromOffset(406, 22)
resourceBack.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
resourceBack.BorderSizePixel = 0
resourceBack.Parent = root

local resourceBackCorner = Instance.new("UICorner")
resourceBackCorner.CornerRadius = UDim.new(0, 8)
resourceBackCorner.Parent = resourceBack

local resourceFill = Instance.new("Frame")
resourceFill.Name = "Fill"
resourceFill.Size = UDim2.fromScale(0, 1)
resourceFill.BackgroundColor3 = Color3.fromRGB(76, 145, 255)
resourceFill.BorderSizePixel = 0
resourceFill.Parent = resourceBack

local resourceFillCorner = Instance.new("UICorner")
resourceFillCorner.CornerRadius = UDim.new(0, 8)
resourceFillCorner.Parent = resourceFill

local resourceLabel = Instance.new("TextLabel")
resourceLabel.Name = "ResourceText"
resourceLabel.BackgroundTransparency = 1
resourceLabel.Size = UDim2.fromScale(1, 1)
resourceLabel.Font = Enum.Font.GothamBold
resourceLabel.TextSize = 13
resourceLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
resourceLabel.Text = "Resource: 0 / 0"
resourceLabel.Parent = resourceBack

local hotkeyLabel = Instance.new("TextLabel")
hotkeyLabel.Name = "Hotkeys"
hotkeyLabel.BackgroundTransparency = 1
hotkeyLabel.Position = UDim2.fromOffset(12, 64)
hotkeyLabel.Size = UDim2.fromOffset(406, 20)
hotkeyLabel.Font = Enum.Font.Gotham
hotkeyLabel.TextSize = 12
hotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
hotkeyLabel.TextColor3 = Color3.fromRGB(198, 198, 198)
hotkeyLabel.Text = "1/2 stance | Q/C/F abilities"
hotkeyLabel.Parent = root

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.BackgroundTransparency = 1
messageLabel.Position = UDim2.fromOffset(12, 88)
messageLabel.Size = UDim2.fromOffset(406, 30)
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextSize = 12
messageLabel.TextWrapped = true
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextYAlignment = Enum.TextYAlignment.Top
messageLabel.TextColor3 = Color3.fromRGB(255, 226, 158)
messageLabel.Text = ""
messageLabel.Parent = root

local function getAbilityByType(typeName, index)
	local count = 0
	for _, ability in ipairs(currentState.abilities or {}) do
		if ability.type == typeName then
			count += 1
			if count == index then
				return ability
			end
		end
	end
	return nil
end

local function render()
	local maxResource = math.max(0, tonumber(currentState.maxResource) or 0)
	local resource = math.clamp(tonumber(currentState.resource) or 0, 0, maxResource)
	local ratio = maxResource > 0 and resource / maxResource or 0
	local resourceName = currentState.resourceDisplayName or "Resource"

	titleLabel.Text = currentState.professionDisplayName or "Profession"
	stanceLabel.Text = currentState.stanceKey ~= "" and ("Stance: " .. currentState.stanceKey) or ""
	resourceFill.Size = UDim2.fromScale(ratio, 1)
	resourceFill.BackgroundColor3 = resourceName == "Rage" and Color3.fromRGB(224, 79, 58) or Color3.fromRGB(76, 145, 255)
	resourceLabel.Text = ("%s: %d / %d"):format(resourceName, math.floor(resource + 0.5), math.floor(maxResource + 0.5))

	local stanceText = {}
	for index, stance in ipairs(currentState.stances or {}) do
		table.insert(stanceText, ("%d=%s"):format(index, stance.displayName or stance.key))
	end

	local qAbility = getAbilityByType("Active", 1)
	local cAbility = getAbilityByType("Active", 2)
	local fAbility = getAbilityByType("Aura", 1) or getAbilityByType("Ultimate", 1)
	hotkeyLabel.Text = ("%s | Q=%s | C=%s | F=%s"):format(
		#stanceText > 0 and table.concat(stanceText, " / ") or "No stance",
		qAbility and qAbility.displayName or "-",
		cAbility and cAbility.displayName or "-",
		fAbility and fAbility.displayName or "-"
	)

	messageLabel.Text = currentState.message or ""
end

local function setStanceByIndex(index)
	local stance = currentState.stances and currentState.stances[index]
	if stance and stance.key then
		abilityEvent:FireServer("setStance", { stanceKey = stance.key })
	end
end

local function useAbilityBySlot(slot)
	local ability = nil
	if slot == 1 then
		ability = getAbilityByType("Active", 1)
	elseif slot == 2 then
		ability = getAbilityByType("Active", 2)
	elseif slot == 3 then
		ability = getAbilityByType("Aura", 1) or getAbilityByType("Ultimate", 1)
	end

	if ability and ability.key then
		abilityEvent:FireServer("useAbility", { abilityKey = ability.key })
	end
end

abilityEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" or data.type ~= "state" then
		return
	end

	for key, value in pairs(data) do
		currentState[key] = value
	end
	render()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.One then
		setStanceByIndex(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		setStanceByIndex(2)
	elseif input.KeyCode == Enum.KeyCode.Q then
		useAbilityBySlot(1)
	elseif input.KeyCode == Enum.KeyCode.C then
		useAbilityBySlot(2)
	elseif input.KeyCode == Enum.KeyCode.F then
		useAbilityBySlot(3)
	end
end)

render()
abilityEvent:FireServer("refresh")
