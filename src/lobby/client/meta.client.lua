local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local META_EVENT_NAME = "LobbyMetaEvent"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local metaEvent = ReplicatedStorage:WaitForChild(META_EVENT_NAME)

local metaState = {
	crystals = 0,
	upgrades = {},
}

local upgradeButtons = {}

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyMetaGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Position = UDim2.fromOffset(18, 18)
root.Size = UDim2.fromOffset(360, 220)
root.BackgroundColor3 = Color3.fromRGB(19, 20, 23)
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
titleLabel.Text = "Meta Upgrades"
titleLabel.Parent = root

local crystalsLabel = Instance.new("TextLabel")
crystalsLabel.BackgroundTransparency = 1
crystalsLabel.Position = UDim2.fromOffset(0, 26)
crystalsLabel.Size = UDim2.new(1, 0, 0, 22)
crystalsLabel.Font = Enum.Font.GothamBold
crystalsLabel.TextSize = 15
crystalsLabel.TextXAlignment = Enum.TextXAlignment.Left
crystalsLabel.TextColor3 = Color3.fromRGB(121, 208, 255)
crystalsLabel.Text = "Crystals: 0"
crystalsLabel.Parent = root

local listFrame = Instance.new("Frame")
listFrame.BackgroundTransparency = 1
listFrame.Position = UDim2.fromOffset(0, 54)
listFrame.Size = UDim2.new(1, 0, 0, 122)
listFrame.Parent = root

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = listFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(0, 182)
statusLabel.Size = UDim2.new(1, 0, 0, 24)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(235, 206, 145)
statusLabel.Text = ""
statusLabel.Parent = root

local function fireMeta(action, payload)
	metaEvent:FireServer(action, payload)
end

local function rebuildButtons()
	for _, item in pairs(upgradeButtons) do
		if item.button and item.button.Parent then
			item.button:Destroy()
		end
	end
	table.clear(upgradeButtons)

	for _, entry in ipairs(metaState.upgrades) do
		local button = Instance.new("TextButton")
		button.Name = entry.key
		button.Size = UDim2.new(1, 0, 0, 34)
		button.BackgroundColor3 = Color3.fromRGB(54, 63, 80)
		button.TextColor3 = Color3.fromRGB(245, 245, 245)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.AutoButtonColor = true
		button.Parent = listFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			fireMeta("upgrade", entry.key)
		end)

		upgradeButtons[entry.key] = {
			button = button,
			entry = entry,
		}
	end
end

local function render()
	crystalsLabel.Text = ("Crystals: %d"):format(math.max(0, math.floor(metaState.crystals or 0)))

	for _, entry in ipairs(metaState.upgrades) do
		local buttonState = upgradeButtons[entry.key]
		if buttonState and buttonState.button then
			local button = buttonState.button
			local maxed = entry.level >= entry.maxLevel
			if maxed then
				button.Text = ("%s  L%d/%d  [MAX]"):format(entry.displayName, entry.level, entry.maxLevel)
				button.BackgroundColor3 = Color3.fromRGB(72, 112, 72)
				button.Active = false
				button.AutoButtonColor = false
			else
				button.Text = ("%s  L%d/%d  [Cost %d]"):format(entry.displayName, entry.level, entry.maxLevel, entry.nextCost)
				button.BackgroundColor3 = Color3.fromRGB(54, 63, 80)
				button.Active = true
				button.AutoButtonColor = true
			end
		end
	end
end

local function applyState(data)
	if typeof(data.upgrades) == "table" then
		metaState.upgrades = data.upgrades
	else
		metaState.upgrades = {}
	end

	if type(data.crystals) == "number" then
		metaState.crystals = data.crystals
	end

	rebuildButtons()
	render()

	if type(data.message) == "string" then
		statusLabel.Text = data.message
	end
end

metaEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if data.type == "state" then
		applyState(data)
	end
end)

fireMeta("open", nil)
