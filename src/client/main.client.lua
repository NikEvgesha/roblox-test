local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local OPEN_DIALOG_EVENT_NAME = "OpenNpcDialog"
local DIALOG_CHOICE_EVENT_NAME = "NpcDialogChoice"
local COMBAT_ACTION_EVENT_NAME = "CombatAction"
local COMBAT_STATE_EVENT_NAME = "CombatState"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local legacyGui = playerGui:FindFirstChild("NpcDialogGui")
if legacyGui and legacyGui:IsA("ScreenGui") then
	legacyGui.Enabled = false
end

local openDialogEvent = ReplicatedStorage:WaitForChild(OPEN_DIALOG_EVENT_NAME)
local dialogChoiceEvent = ReplicatedStorage:WaitForChild(DIALOG_CHOICE_EVENT_NAME)
local combatActionEvent = ReplicatedStorage:WaitForChild(COMBAT_ACTION_EVENT_NAME)
local combatStateEvent = ReplicatedStorage:WaitForChild(COMBAT_STATE_EVENT_NAME)

local gui = Instance.new("ScreenGui")
gui.Name = "NpcDialogRojoGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.AnchorPoint = Vector2.new(0, 0)
moneyLabel.Position = UDim2.fromOffset(18, 18)
moneyLabel.Size = UDim2.fromOffset(250, 36)
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

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "AmmoLabel"
ammoLabel.AnchorPoint = Vector2.new(0, 0)
ammoLabel.Position = UDim2.fromOffset(18, 58)
ammoLabel.Size = UDim2.fromOffset(320, 34)
ammoLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ammoLabel.BackgroundTransparency = 0.2
ammoLabel.TextColor3 = Color3.fromRGB(198, 224, 255)
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 18
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.Text = "Патроны: 0 / 0"
ammoLabel.Parent = gui

local ammoCorner = Instance.new("UICorner")
ammoCorner.CornerRadius = UDim.new(0, 8)
ammoCorner.Parent = ammoLabel

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "WeaponLabel"
weaponLabel.AnchorPoint = Vector2.new(0, 0)
weaponLabel.Position = UDim2.fromOffset(18, 95)
weaponLabel.Size = UDim2.fromOffset(320, 30)
weaponLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
weaponLabel.BackgroundTransparency = 0.3
weaponLabel.TextColor3 = Color3.fromRGB(233, 233, 233)
weaponLabel.Font = Enum.Font.Gotham
weaponLabel.TextSize = 16
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Text = "Оружие: Нет"
weaponLabel.Parent = gui

local weaponCorner = Instance.new("UICorner")
weaponCorner.CornerRadius = UDim.new(0, 8)
weaponCorner.Parent = weaponLabel

local controlsLabel = Instance.new("TextLabel")
controlsLabel.Name = "ControlsLabel"
controlsLabel.AnchorPoint = Vector2.new(0, 0)
controlsLabel.Position = UDim2.fromOffset(18, 128)
controlsLabel.Size = UDim2.fromOffset(420, 26)
controlsLabel.BackgroundTransparency = 1
controlsLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
controlsLabel.Font = Enum.Font.Gotham
controlsLabel.TextSize = 14
controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
controlsLabel.Text = "Подсказка: E с Noob, ЛКМ стрелять/бить, R перезарядка"
controlsLabel.Parent = gui

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

local equippedWeapon = "None"
local ammoMag = 0
local ammoReserve = 0
local isReloading = false
local swordComboToggle = false

local swordSlashAnimation = Instance.new("Animation")
swordSlashAnimation.AnimationId = combatConfig.Sword.SlashAnimationId

local swordLungeAnimation = Instance.new("Animation")
swordLungeAnimation.AnimationId = combatConfig.Sword.LungeAnimationId

local function refreshCombatHud()
	local prettyWeapon = "Нет"
	if equippedWeapon == combatConfig.Gun.ToolName then
		prettyWeapon = "Пистолет"
	elseif equippedWeapon == combatConfig.Sword.ToolName then
		prettyWeapon = "Меч"
	end

	weaponLabel.Text = ("Оружие: %s"):format(prettyWeapon)
	local suffix = isReloading and " (перезарядка...)" or ""
	ammoLabel.Text = ("Патроны: %d / %d%s"):format(ammoMag, ammoReserve, suffix)

	if equippedWeapon == combatConfig.Gun.ToolName then
		controlsLabel.Text = "ЛКМ: выстрел | R: перезарядка | E: диалог с Noob"
	elseif equippedWeapon == combatConfig.Sword.ToolName then
		controlsLabel.Text = "ЛКМ: удар мечом | E: диалог с Noob"
	else
		controlsLabel.Text = "Выбери Пистолет или Меч в инвентаре | E: диалог с Noob"
	end
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

local function updateEquippedWeaponFromCharacter(character)
	if not character then
		equippedWeapon = "None"
		refreshCombatHud()
		return
	end

	if character:FindFirstChild(combatConfig.Gun.ToolName) then
		equippedWeapon = combatConfig.Gun.ToolName
	elseif character:FindFirstChild(combatConfig.Sword.ToolName) then
		equippedWeapon = combatConfig.Sword.ToolName
	else
		equippedWeapon = "None"
	end

	refreshCombatHud()
end

local function bindCharacter(character)
	updateEquippedWeaponFromCharacter(character)

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			updateEquippedWeaponFromCharacter(character)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			updateEquippedWeaponFromCharacter(character)
		end
	end)
end

local function playSwordAnimation()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animationToPlay = swordSlashAnimation
	if swordComboToggle then
		animationToPlay = swordLungeAnimation
	end
	swordComboToggle = not swordComboToggle

	local track = humanoid:LoadAnimation(animationToPlay)
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05, 1, 1.05)
end

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if dialogFrame.Visible then
		return
	end

	if equippedWeapon == combatConfig.Gun.ToolName then
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local origin = camera.CFrame.Position
		local direction = mouse.Hit.Position - origin
		if direction.Magnitude < 0.01 then
			direction = camera.CFrame.LookVector
		end

		combatActionEvent:FireServer("shoot", {
			origin = origin,
			direction = direction,
		})
	elseif equippedWeapon == combatConfig.Sword.ToolName then
		playSwordAnimation()
		combatActionEvent:FireServer("swing")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if dialogFrame.Visible then
		return
	end

	if input.KeyCode == Enum.KeyCode.R and equippedWeapon == combatConfig.Gun.ToolName then
		combatActionEvent:FireServer("reload")
	end
end)

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

combatStateEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.mag) == "number" then
		ammoMag = math.max(0, math.floor(data.mag))
	end

	if typeof(data.reserve) == "number" then
		ammoReserve = math.max(0, math.floor(data.reserve))
	end

	if typeof(data.reloading) == "boolean" then
		isReloading = data.reloading
	end

	if typeof(data.equipped) == "string" then
		equippedWeapon = data.equipped
	end

	refreshCombatHud()
end)

task.spawn(bindMoneyListeners)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

refreshCombatHud()
