local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OPEN_DIALOG_EVENT_NAME = "OpenNpcDialog"
local DIALOG_CHOICE_EVENT_NAME = "NpcDialogChoice"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local legacyGui = playerGui:FindFirstChild("NpcDialogGui")
if legacyGui and legacyGui:IsA("ScreenGui") then
	legacyGui.Enabled = false
end

local openDialogEvent = ReplicatedStorage:WaitForChild(OPEN_DIALOG_EVENT_NAME)
local dialogChoiceEvent = ReplicatedStorage:WaitForChild(DIALOG_CHOICE_EVENT_NAME)

local gui = Instance.new("ScreenGui")
gui.Name = "NpcDialogRojoGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.AnchorPoint = Vector2.new(0, 0)
moneyLabel.Position = UDim2.fromOffset(18, 18)
moneyLabel.Size = UDim2.fromOffset(220, 36)
moneyLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
moneyLabel.BackgroundTransparency = 0.2
moneyLabel.TextColor3 = Color3.fromRGB(255, 224, 102)
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextSize = 20
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Text = "Деньги: 0$"
moneyLabel.Parent = gui

local moneyCorner = Instance.new("UICorner")
moneyCorner.CornerRadius = UDim.new(0, 8)
moneyCorner.Parent = moneyLabel

local dialogFrame = Instance.new("Frame")
dialogFrame.Name = "DialogFrame"
dialogFrame.AnchorPoint = Vector2.new(0.5, 1)
dialogFrame.Position = UDim2.new(0.5, 0, 1, -30)
dialogFrame.Size = UDim2.fromOffset(560, 210)
dialogFrame.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
dialogFrame.BackgroundTransparency = 0.1
dialogFrame.Visible = false
dialogFrame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = dialogFrame

local npcNameLabel = Instance.new("TextLabel")
npcNameLabel.Name = "NpcName"
npcNameLabel.BackgroundTransparency = 1
npcNameLabel.Position = UDim2.fromOffset(16, 12)
npcNameLabel.Size = UDim2.new(1, -32, 0, 30)
npcNameLabel.Font = Enum.Font.GothamBold
npcNameLabel.TextSize = 24
npcNameLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
npcNameLabel.Text = "Noob"
npcNameLabel.Parent = dialogFrame

local dialogTextLabel = Instance.new("TextLabel")
dialogTextLabel.Name = "DialogText"
dialogTextLabel.BackgroundTransparency = 1
dialogTextLabel.Position = UDim2.fromOffset(16, 50)
dialogTextLabel.Size = UDim2.new(1, -32, 0, 50)
dialogTextLabel.Font = Enum.Font.Gotham
dialogTextLabel.TextSize = 20
dialogTextLabel.TextColor3 = Color3.fromRGB(228, 228, 228)
dialogTextLabel.TextWrapped = true
dialogTextLabel.TextXAlignment = Enum.TextXAlignment.Left
dialogTextLabel.TextYAlignment = Enum.TextYAlignment.Top
dialogTextLabel.Text = ""
dialogTextLabel.Parent = dialogFrame

local choicesFrame = Instance.new("Frame")
choicesFrame.Name = "ChoicesFrame"
choicesFrame.BackgroundTransparency = 1
choicesFrame.Position = UDim2.fromOffset(16, 112)
choicesFrame.Size = UDim2.new(1, -32, 1, -124)
choicesFrame.Parent = dialogFrame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = choicesFrame

local function clearChoices()
	for _, child in ipairs(choicesFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function addChoiceButton(choiceData)
	local button = Instance.new("TextButton")
	local suffix = tostring(choiceData.id or "unknown")
	suffix = suffix:gsub("[^%w_]", "_")
	button.Name = "Choice_" .. suffix
	button.Size = UDim2.fromOffset(170, 70)
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 18
	button.TextWrapped = true
	button.Text = choiceData.text or "..."
	button.Parent = choicesFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		if choiceData.id then
			dialogChoiceEvent:FireServer(choiceData.id)
		end
	end)
end

local function refreshMoneyLabel()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		moneyLabel.Text = "Деньги: 0$"
		return
	end

	local money = leaderstats:FindFirstChild("Money")
	if not money then
		moneyLabel.Text = "Деньги: 0$"
		return
	end

	moneyLabel.Text = ("Деньги: %d$"):format(money.Value)
end

local function bindMoneyListeners()
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Money")

	refreshMoneyLabel()
	money:GetPropertyChangedSignal("Value"):Connect(refreshMoneyLabel)
end

task.spawn(bindMoneyListeners)

openDialogEvent.OnClientEvent:Connect(function(data)
	if not data then
		return
	end

	if data.mode == "close" then
		dialogFrame.Visible = false
		clearChoices()
		return
	end

	npcNameLabel.Text = data.npcName or "NPC"
	dialogTextLabel.Text = data.text or "..."
	dialogFrame.Visible = true

	clearChoices()
	for _, choiceData in ipairs(data.choices or {}) do
		addChoiceButton(choiceData)
	end
end)
