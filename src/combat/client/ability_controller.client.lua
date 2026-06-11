local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local abilityConfig = require(sharedFolder:WaitForChild("AbilityConfig"))
local abilityEvent = ReplicatedStorage:WaitForChild(abilityConfig.EventName)
local mouse = player:GetMouse()

local AIM_RAY_DISTANCE = 2000

local currentState = {
	professionDisplayName = "Profession",
	resourceDisplayName = "Resource",
	resource = 0,
	maxResource = 0,
	stanceKey = "",
	stances = {},
	abilities = {},
	skillPoints = 0,
	shield = 0,
	immortalRemaining = 0,
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
root.Size = UDim2.fromOffset(460, 310)
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
titleLabel.Size = UDim2.fromOffset(230, 22)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
titleLabel.Text = "Profession"
titleLabel.Parent = root

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Position = UDim2.fromOffset(248, 8)
pointsLabel.Size = UDim2.fromOffset(92, 22)
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.TextSize = 13
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.TextColor3 = Color3.fromRGB(255, 226, 158)
pointsLabel.Text = "SP: 0"
pointsLabel.Parent = root

local stanceLabel = Instance.new("TextLabel")
stanceLabel.Name = "Stance"
stanceLabel.BackgroundTransparency = 1
stanceLabel.Position = UDim2.fromOffset(340, 8)
stanceLabel.Size = UDim2.fromOffset(108, 22)
stanceLabel.Font = Enum.Font.GothamBold
stanceLabel.TextSize = 14
stanceLabel.TextXAlignment = Enum.TextXAlignment.Right
stanceLabel.TextColor3 = Color3.fromRGB(178, 214, 255)
stanceLabel.Text = ""
stanceLabel.Parent = root

local resourceBack = Instance.new("Frame")
resourceBack.Name = "ResourceBack"
resourceBack.Position = UDim2.fromOffset(12, 36)
resourceBack.Size = UDim2.fromOffset(436, 22)
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
hotkeyLabel.Size = UDim2.fromOffset(436, 20)
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
messageLabel.Size = UDim2.fromOffset(436, 28)
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextSize = 12
messageLabel.TextWrapped = true
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextYAlignment = Enum.TextYAlignment.Top
messageLabel.TextColor3 = Color3.fromRGB(255, 226, 158)
messageLabel.Text = ""
messageLabel.Parent = root

local abilityList = Instance.new("ScrollingFrame")
abilityList.Name = "AbilityList"
abilityList.Position = UDim2.fromOffset(12, 122)
abilityList.Size = UDim2.fromOffset(436, 176)
abilityList.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
abilityList.BackgroundTransparency = 0.18
abilityList.BorderSizePixel = 0
abilityList.ScrollBarThickness = 4
abilityList.CanvasSize = UDim2.fromOffset(0, 0)
abilityList.Parent = root

local abilityListCorner = Instance.new("UICorner")
abilityListCorner.CornerRadius = UDim.new(0, 8)
abilityListCorner.Parent = abilityList

local abilityListLayout = Instance.new("UIListLayout")
abilityListLayout.Padding = UDim.new(0, 4)
abilityListLayout.SortOrder = Enum.SortOrder.LayoutOrder
abilityListLayout.Parent = abilityList

local abilityListPadding = Instance.new("UIPadding")
abilityListPadding.PaddingTop = UDim.new(0, 6)
abilityListPadding.PaddingBottom = UDim.new(0, 6)
abilityListPadding.PaddingLeft = UDim.new(0, 6)
abilityListPadding.PaddingRight = UDim.new(0, 6)
abilityListPadding.Parent = abilityList

local abilityRows = {}

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

local function formatAbilityHotkey(ability)
	if not ability then
		return "-"
	end

	local label = ability.displayName or ability.key or "-"
	local cooldownRemaining = tonumber(ability.cooldownRemaining) or 0
	if cooldownRemaining > 0.05 then
		return ("%s %.0fs"):format(label, math.ceil(cooldownRemaining))
	end

	return label
end

local function clearAbilityRows()
	for _, row in ipairs(abilityRows) do
		if row and row.Parent then
			row:Destroy()
		end
	end
	table.clear(abilityRows)
end

local function buildAbilityRow(ability, index)
	local row = Instance.new("Frame")
	row.Name = "Ability_" .. tostring(ability.key)
	row.LayoutOrder = index
	row.Size = UDim2.new(1, -4, 0, 34)
	row.BackgroundColor3 = ability.unlocked and Color3.fromRGB(36, 43, 54) or Color3.fromRGB(44, 36, 36)
	row.BorderSizePixel = 0
	row.Parent = abilityList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 7)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(8, 3)
	nameLabel.Size = UDim2.fromOffset(218, 16)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
	nameLabel.Text = ("%s [%s]"):format(ability.displayName or ability.key, ability.type or "?")
	nameLabel.Parent = row

	local rank = math.max(0, math.floor(tonumber(ability.rank) or 0))
	local maxRank = math.max(1, math.floor(tonumber(ability.maxRank) or 1))
	local upgradeCost = math.max(1, math.floor(tonumber(ability.upgradeCost) or 1))

	local rankLabel = Instance.new("TextLabel")
	rankLabel.BackgroundTransparency = 1
	rankLabel.Position = UDim2.fromOffset(8, 18)
	rankLabel.Size = UDim2.fromOffset(218, 13)
	rankLabel.Font = Enum.Font.Gotham
	rankLabel.TextSize = 11
	rankLabel.TextXAlignment = Enum.TextXAlignment.Left
	rankLabel.TextColor3 = Color3.fromRGB(198, 205, 214)
	rankLabel.Text = ("Rank %d/%d | Cost %d SP"):format(rank, maxRank, upgradeCost)
	rankLabel.Parent = row

	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(230, 3)
	description.Size = UDim2.fromOffset(108, 28)
	description.Font = Enum.Font.Gotham
	description.TextSize = 10
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Center
	description.TextColor3 = Color3.fromRGB(177, 184, 194)
	description.Text = ability.description or ""
	description.Parent = row

	local button = Instance.new("TextButton")
	button.Position = UDim2.new(1, -80, 0.5, -12)
	button.Size = UDim2.fromOffset(72, 24)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.Parent = row

	local availablePoints = math.max(0, math.floor(tonumber(currentState.skillPoints) or 0))
	if ability.canUpgrade and availablePoints >= upgradeCost then
		button.Text = "+1"
		button.BackgroundColor3 = Color3.fromRGB(70, 116, 82)
		button.MouseButton1Click:Connect(function()
			abilityEvent:FireServer("upgradeAbility", { abilityKey = ability.key })
		end)
	elseif ability.canUpgrade then
		button.Text = "No SP"
		button.BackgroundColor3 = Color3.fromRGB(76, 64, 55)
		button.Active = false
	else
		button.Text = "Max"
		button.BackgroundColor3 = Color3.fromRGB(72, 72, 72)
		button.Active = false
	end

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	table.insert(abilityRows, row)
end

local function refreshAbilityRows()
	clearAbilityRows()
	for index, ability in ipairs(currentState.abilities or {}) do
		buildAbilityRow(ability, index)
	end
	abilityList.CanvasSize = UDim2.fromOffset(0, #abilityRows * 38 + 12)
end

local function render()
	local maxResource = math.max(0, tonumber(currentState.maxResource) or 0)
	local resource = math.clamp(tonumber(currentState.resource) or 0, 0, maxResource)
	local ratio = maxResource > 0 and resource / maxResource or 0
	local resourceName = currentState.resourceDisplayName or "Resource"

	titleLabel.Text = currentState.professionDisplayName or "Profession"
	pointsLabel.Text = ("SP: %d"):format(math.max(0, math.floor(tonumber(currentState.skillPoints) or 0)))
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
	local fAbility = getAbilityByType("Ultimate", 1) or getAbilityByType("Aura", 1)
	hotkeyLabel.Text = ("%s | Q=%s | C=%s | F=%s"):format(
		#stanceText > 0 and table.concat(stanceText, " / ") or "No stance",
		formatAbilityHotkey(qAbility),
		formatAbilityHotkey(cAbility),
		formatAbilityHotkey(fAbility)
	)

	local statusParts = {}
	local shield = tonumber(currentState.shield) or 0
	local immortalRemaining = tonumber(currentState.immortalRemaining) or 0
	if shield > 0.5 then
		table.insert(statusParts, ("Shield %.0f"):format(shield))
	end
	if immortalRemaining > 0.05 then
		table.insert(statusParts, ("Immortal %.0fs"):format(math.ceil(immortalRemaining)))
	end

	local message = currentState.message or ""
	if #statusParts > 0 then
		local statusText = table.concat(statusParts, " | ")
		messageLabel.Text = message ~= "" and (message .. " | " .. statusText) or statusText
	else
		messageLabel.Text = message
	end

	refreshAbilityRows()
end

local function setStanceByIndex(index)
	local stance = currentState.stances and currentState.stances[index]
	if stance and stance.key then
		abilityEvent:FireServer("setStance", { stanceKey = stance.key })
	end
end

local function buildAimPayload()
	local camera = Workspace.CurrentCamera
	if not camera then
		return {}
	end

	local unitRay = mouse.UnitRay
	local rayOrigin = unitRay and unitRay.Origin or camera.CFrame.Position
	local rayDirection = unitRay and unitRay.Direction or camera.CFrame.LookVector
	if typeof(rayDirection) ~= "Vector3" or rayDirection.Magnitude < 0.001 then
		rayDirection = camera.CFrame.LookVector
	end
	rayDirection = rayDirection.Unit

	local character = player.Character
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = character and { character } or {}

	local result = Workspace:Raycast(rayOrigin, rayDirection * AIM_RAY_DISTANCE, rayParams)
	local targetPosition = result and result.Position or (rayOrigin + rayDirection * AIM_RAY_DISTANCE)

	return {
		direction = rayDirection,
		rayOrigin = rayOrigin,
		rayDirection = rayDirection,
		targetPosition = targetPosition,
	}
end

local function useAbilityBySlot(slot)
	local ability = nil
	if slot == 1 then
		ability = getAbilityByType("Active", 1)
	elseif slot == 2 then
		ability = getAbilityByType("Active", 2)
	elseif slot == 3 then
		ability = getAbilityByType("Ultimate", 1) or getAbilityByType("Aura", 1)
	end

	if ability and ability.key then
		local payload = { abilityKey = ability.key }
		if ability.key == "PiercingShot" or ability.type == "Active" or ability.type == "Ultimate" then
			for key, value in pairs(buildAimPayload()) do
				payload[key] = value
			end
		end
		abilityEvent:FireServer("useAbility", payload)
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
