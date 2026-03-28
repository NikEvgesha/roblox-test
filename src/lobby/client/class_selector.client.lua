local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QUEUE_EVENT_NAME = "LobbyQueueEvent"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local queueEvent = ReplicatedStorage:WaitForChild(QUEUE_EVENT_NAME)

local classState = {
	classes = { "Assault", "Builder", "Healer", "Melee" },
	classDisplayNames = {},
	selectedClass = "Assault",
}

local classButtons = {}

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyClassGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Position = UDim2.fromOffset(18, 248)
root.Size = UDim2.fromOffset(360, 170)
root.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
root.BackgroundTransparency = 0.16
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = root

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, 0, 0, 24)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
titleLabel.Text = "Class Select"
titleLabel.Parent = root

local selectedLabel = Instance.new("TextLabel")
selectedLabel.BackgroundTransparency = 1
selectedLabel.Position = UDim2.fromOffset(0, 24)
selectedLabel.Size = UDim2.new(1, 0, 0, 20)
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.TextSize = 14
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.TextColor3 = Color3.fromRGB(208, 208, 208)
selectedLabel.Text = "Selected: Assault"
selectedLabel.Parent = root

local buttonsFrame = Instance.new("Frame")
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.Position = UDim2.fromOffset(0, 52)
buttonsFrame.Size = UDim2.new(1, 0, 0, 64)
buttonsFrame.Parent = root

local buttonsLayout = Instance.new("UIGridLayout")
buttonsLayout.CellSize = UDim2.fromOffset(160, 28)
buttonsLayout.CellPadding = UDim2.fromOffset(8, 8)
buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
buttonsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
buttonsLayout.FillDirectionMaxCells = 2
buttonsLayout.Parent = buttonsFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.fromOffset(0, 126)
hintLabel.Size = UDim2.new(1, 0, 0, 24)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextColor3 = Color3.fromRGB(173, 173, 173)
hintLabel.Text = "Class persists and is used at run start."
hintLabel.Parent = root

local function getClassDisplayName(classKey)
	return classState.classDisplayNames[classKey] or classKey
end

local function fireAction(action, payload)
	local data = { action = action }
	if type(payload) == "table" then
		for key, value in pairs(payload) do
			data[key] = value
		end
	end
	queueEvent:FireServer(data)
end

local function rebuildButtons()
	for _, button in pairs(classButtons) do
		if button and button.Parent then
			button:Destroy()
		end
	end
	table.clear(classButtons)

	for _, classKey in ipairs(classState.classes) do
		local button = Instance.new("TextButton")
		button.Name = classKey
		button.BackgroundColor3 = Color3.fromRGB(58, 67, 84)
		button.TextColor3 = Color3.fromRGB(245, 245, 245)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.Text = getClassDisplayName(classKey)
		button.Parent = buttonsFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			fireAction("set_class", { classKey = classKey })
		end)

		classButtons[classKey] = button
	end
end

local function render()
	selectedLabel.Text = ("Selected: %s"):format(getClassDisplayName(classState.selectedClass))

	for classKey, button in pairs(classButtons) do
		local isSelected = classKey == classState.selectedClass
		button.BackgroundColor3 = isSelected and Color3.fromRGB(86, 136, 94) or Color3.fromRGB(58, 67, 84)
	end
end

local function applyState(data)
	if typeof(data.classes) == "table" and #data.classes > 0 then
		classState.classes = data.classes
	end
	if typeof(data.classDisplayNames) == "table" then
		classState.classDisplayNames = data.classDisplayNames
	end
	if type(data.selectedClass) == "string" and data.selectedClass ~= "" then
		classState.selectedClass = data.selectedClass
	elseif type(data.defaultClass) == "string" and data.defaultClass ~= "" then
		classState.selectedClass = data.defaultClass
	end

	rebuildButtons()
	render()
end

queueEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if data.type == "state" then
		applyState(data)
	end
end)

rebuildButtons()
render()
fireAction("request_state")
