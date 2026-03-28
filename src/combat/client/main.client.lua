local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local COMBAT_ACTION_EVENT_NAME = "CombatAction"
local COMBAT_STATE_EVENT_NAME = "CombatState"
local SHOP_EVENT_NAME = "ShopEvent"
local SKILL_EVENT_NAME = "SkillEvent"
local SURVIVAL_EVENT_NAME = "SurvivalEvent"
local REVIVE_PURCHASE_EVENT_NAME = "RevivePurchaseEvent"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local combatActionEvent = ReplicatedStorage:WaitForChild(COMBAT_ACTION_EVENT_NAME)
local combatStateEvent = ReplicatedStorage:WaitForChild(COMBAT_STATE_EVENT_NAME)
local shopEvent = ReplicatedStorage:WaitForChild(SHOP_EVENT_NAME)
local skillEvent = ReplicatedStorage:WaitForChild(SKILL_EVENT_NAME)
local survivalEvent = ReplicatedStorage:WaitForChild(SURVIVAL_EVENT_NAME)
local revivePurchaseEvent = ReplicatedStorage:WaitForChild(REVIVE_PURCHASE_EVENT_NAME)

local weaponByToolName = {}
for weaponKey, definition in pairs(combatConfig.Weapons) do
	weaponByToolName[definition.ToolName] = weaponKey
end

local gui = Instance.new("ScreenGui")
gui.Name = "MainHudGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Position = UDim2.fromOffset(18, 18)
moneyLabel.Size = UDim2.fromOffset(280, 36)
moneyLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
moneyLabel.BackgroundTransparency = 0.2
moneyLabel.TextColor3 = Color3.fromRGB(255, 224, 102)
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.TextSize = 20
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Text = "Money: 0$"
moneyLabel.Parent = gui

local moneyCorner = Instance.new("UICorner")
moneyCorner.CornerRadius = UDim.new(0, 8)
moneyCorner.Parent = moneyLabel

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "AmmoLabel"
ammoLabel.Position = UDim2.fromOffset(18, 58)
ammoLabel.Size = UDim2.fromOffset(350, 34)
ammoLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ammoLabel.BackgroundTransparency = 0.2
ammoLabel.TextColor3 = Color3.fromRGB(198, 224, 255)
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 18
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.Text = "Ammo: 0 / 0"
ammoLabel.Parent = gui

local ammoCorner = Instance.new("UICorner")
ammoCorner.CornerRadius = UDim.new(0, 8)
ammoCorner.Parent = ammoLabel

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "WeaponLabel"
weaponLabel.Position = UDim2.fromOffset(18, 95)
weaponLabel.Size = UDim2.fromOffset(350, 30)
weaponLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
weaponLabel.BackgroundTransparency = 0.3
weaponLabel.TextColor3 = Color3.fromRGB(233, 233, 233)
weaponLabel.Font = Enum.Font.Gotham
weaponLabel.TextSize = 16
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Text = "Weapon: None"
weaponLabel.Parent = gui

local weaponCorner = Instance.new("UICorner")
weaponCorner.CornerRadius = UDim.new(0, 8)
weaponCorner.Parent = weaponLabel

local controlsLabel = Instance.new("TextLabel")
controlsLabel.Name = "ControlsLabel"
controlsLabel.Position = UDim2.fromOffset(18, 128)
controlsLabel.Size = UDim2.fromOffset(600, 26)
controlsLabel.BackgroundTransparency = 1
controlsLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
controlsLabel.Font = Enum.Font.Gotham
controlsLabel.TextSize = 14
controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
controlsLabel.Text = "LMB fire/attack | RMB aim | R reload | E interact | B open shop"
controlsLabel.Parent = gui

local survivalStatusLabel = Instance.new("TextLabel")
survivalStatusLabel.Name = "SurvivalStatusLabel"
survivalStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
survivalStatusLabel.Position = UDim2.fromScale(0.5, 0.02)
survivalStatusLabel.Size = UDim2.fromOffset(560, 34)
survivalStatusLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
survivalStatusLabel.BackgroundTransparency = 0.24
survivalStatusLabel.TextColor3 = Color3.fromRGB(241, 241, 241)
survivalStatusLabel.Font = Enum.Font.GothamBold
survivalStatusLabel.TextSize = 16
survivalStatusLabel.Text = "Survive as long as possible."
survivalStatusLabel.Parent = gui

local survivalStatusCorner = Instance.new("UICorner")
survivalStatusCorner.CornerRadius = UDim.new(0, 8)
survivalStatusCorner.Parent = survivalStatusLabel

local respawnStatusLabel = Instance.new("TextLabel")
respawnStatusLabel.Name = "RespawnStatusLabel"
respawnStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
respawnStatusLabel.Position = UDim2.fromScale(0.5, 0.065)
respawnStatusLabel.Size = UDim2.fromOffset(560, 30)
respawnStatusLabel.BackgroundTransparency = 1
respawnStatusLabel.TextColor3 = Color3.fromRGB(255, 186, 186)
respawnStatusLabel.Font = Enum.Font.GothamBold
respawnStatusLabel.TextSize = 15
respawnStatusLabel.Text = ""
respawnStatusLabel.Visible = false
respawnStatusLabel.Parent = gui

local reviveButtonsFrame = Instance.new("Frame")
reviveButtonsFrame.Name = "ReviveButtonsFrame"
reviveButtonsFrame.AnchorPoint = Vector2.new(0.5, 0)
reviveButtonsFrame.Position = UDim2.fromScale(0.5, 0.1)
reviveButtonsFrame.Size = UDim2.fromOffset(560, 40)
reviveButtonsFrame.BackgroundTransparency = 1
reviveButtonsFrame.Visible = false
reviveButtonsFrame.Parent = gui

local reviveLayout = Instance.new("UIListLayout")
reviveLayout.FillDirection = Enum.FillDirection.Horizontal
reviveLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
reviveLayout.VerticalAlignment = Enum.VerticalAlignment.Center
reviveLayout.Padding = UDim.new(0, 12)
reviveLayout.Parent = reviveButtonsFrame

local soloReviveButton = Instance.new("TextButton")
soloReviveButton.Name = "SoloReviveButton"
soloReviveButton.Size = UDim2.fromOffset(220, 34)
soloReviveButton.BackgroundColor3 = Color3.fromRGB(86, 130, 86)
soloReviveButton.TextColor3 = Color3.fromRGB(245, 245, 245)
soloReviveButton.Font = Enum.Font.GothamBold
soloReviveButton.TextSize = 14
soloReviveButton.Text = "Solo Revive"
soloReviveButton.Visible = false
soloReviveButton.Parent = reviveButtonsFrame

local soloReviveCorner = Instance.new("UICorner")
soloReviveCorner.CornerRadius = UDim.new(0, 8)
soloReviveCorner.Parent = soloReviveButton

local teamReviveButton = Instance.new("TextButton")
teamReviveButton.Name = "TeamReviveButton"
teamReviveButton.Size = UDim2.fromOffset(220, 34)
teamReviveButton.BackgroundColor3 = Color3.fromRGB(118, 88, 146)
teamReviveButton.TextColor3 = Color3.fromRGB(245, 245, 245)
teamReviveButton.Font = Enum.Font.GothamBold
teamReviveButton.TextSize = 14
teamReviveButton.Text = "Team Revive"
teamReviveButton.Visible = false
teamReviveButton.Parent = reviveButtonsFrame

local teamReviveCorner = Instance.new("UICorner")
teamReviveCorner.CornerRadius = UDim.new(0, 8)
teamReviveCorner.Parent = teamReviveButton

local openSkillsButton = Instance.new("TextButton")
openSkillsButton.Name = "OpenSkillsButton"
openSkillsButton.Position = UDim2.fromOffset(380, 18)
openSkillsButton.Size = UDim2.fromOffset(170, 34)
openSkillsButton.BackgroundColor3 = Color3.fromRGB(58, 80, 120)
openSkillsButton.TextColor3 = Color3.fromRGB(245, 245, 245)
openSkillsButton.Font = Enum.Font.GothamBold
openSkillsButton.TextSize = 14
openSkillsButton.Text = "Skills [K]"
openSkillsButton.Parent = gui

local openSkillsCorner = Instance.new("UICorner")
openSkillsCorner.CornerRadius = UDim.new(0, 8)
openSkillsCorner.Parent = openSkillsButton

local skillPointsBadge = Instance.new("Frame")
skillPointsBadge.Name = "PointsBadge"
skillPointsBadge.AnchorPoint = Vector2.new(1, 0)
skillPointsBadge.Position = UDim2.new(1, 8, 0, -6)
skillPointsBadge.Size = UDim2.fromOffset(52, 26)
skillPointsBadge.BackgroundColor3 = Color3.fromRGB(214, 83, 83)
skillPointsBadge.Visible = false
skillPointsBadge.Parent = openSkillsButton

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = skillPointsBadge

local skillArrowLabel = Instance.new("TextLabel")
skillArrowLabel.Name = "Arrow"
skillArrowLabel.BackgroundTransparency = 1
skillArrowLabel.Position = UDim2.fromOffset(5, 2)
skillArrowLabel.Size = UDim2.fromOffset(18, 22)
skillArrowLabel.Font = Enum.Font.GothamBlack
skillArrowLabel.TextColor3 = Color3.fromRGB(255, 245, 245)
skillArrowLabel.TextSize = 20
skillArrowLabel.Text = "^"
skillArrowLabel.Parent = skillPointsBadge

local skillPointsBadgeLabel = Instance.new("TextLabel")
skillPointsBadgeLabel.Name = "Count"
skillPointsBadgeLabel.BackgroundTransparency = 1
skillPointsBadgeLabel.Position = UDim2.fromOffset(22, 2)
skillPointsBadgeLabel.Size = UDim2.fromOffset(26, 22)
skillPointsBadgeLabel.Font = Enum.Font.GothamBold
skillPointsBadgeLabel.TextColor3 = Color3.fromRGB(255, 245, 245)
skillPointsBadgeLabel.TextSize = 14
skillPointsBadgeLabel.Text = "0"
skillPointsBadgeLabel.Parent = skillPointsBadge

local playerHealthContainer = Instance.new("Frame")
playerHealthContainer.Name = "PlayerHealthContainer"
playerHealthContainer.Position = UDim2.fromOffset(18, 160)
playerHealthContainer.Size = UDim2.fromOffset(320, 24)
playerHealthContainer.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
playerHealthContainer.BackgroundTransparency = 0.25
playerHealthContainer.BorderSizePixel = 0
playerHealthContainer.Parent = gui

local playerHealthCorner = Instance.new("UICorner")
playerHealthCorner.CornerRadius = UDim.new(0, 8)
playerHealthCorner.Parent = playerHealthContainer

local playerHealthFill = Instance.new("Frame")
playerHealthFill.Name = "Fill"
playerHealthFill.Size = UDim2.fromScale(1, 1)
playerHealthFill.BackgroundColor3 = Color3.fromRGB(228, 81, 81)
playerHealthFill.BorderSizePixel = 0
playerHealthFill.Parent = playerHealthContainer

local playerHealthFillCorner = Instance.new("UICorner")
playerHealthFillCorner.CornerRadius = UDim.new(0, 8)
playerHealthFillCorner.Parent = playerHealthFill

local playerHealthLabel = Instance.new("TextLabel")
playerHealthLabel.Name = "Text"
playerHealthLabel.Size = UDim2.fromScale(1, 1)
playerHealthLabel.BackgroundTransparency = 1
playerHealthLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
playerHealthLabel.Font = Enum.Font.GothamBold
playerHealthLabel.TextSize = 14
playerHealthLabel.Text = "HP: 100 / 100"
playerHealthLabel.Parent = playerHealthContainer

local xpContainer = Instance.new("Frame")
xpContainer.Name = "XPContainer"
xpContainer.AnchorPoint = Vector2.new(0.5, 1)
xpContainer.Position = UDim2.new(0.5, 0, 1, -8)
xpContainer.Size = UDim2.fromOffset(520, 30)
xpContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
xpContainer.BackgroundTransparency = 0.2
xpContainer.BorderSizePixel = 0
xpContainer.Parent = gui

local xpCorner = Instance.new("UICorner")
xpCorner.CornerRadius = UDim.new(0, 10)
xpCorner.Parent = xpContainer

local xpFill = Instance.new("Frame")
xpFill.Name = "Fill"
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = Color3.fromRGB(103, 150, 255)
xpFill.BorderSizePixel = 0
xpFill.Parent = xpContainer

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 10)
xpFillCorner.Parent = xpFill

local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "Text"
xpLabel.Size = UDim2.fromScale(1, 1)
xpLabel.BackgroundTransparency = 1
xpLabel.TextColor3 = Color3.fromRGB(241, 241, 241)
xpLabel.Font = Enum.Font.GothamBold
xpLabel.TextSize = 14
xpLabel.Text = "Lvl 1 | XP 0/100"
xpLabel.Parent = xpContainer

local crosshairFrame = Instance.new("Frame")
crosshairFrame.Name = "Crosshair"
crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
crosshairFrame.Size = UDim2.fromOffset(24, 24)
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.Visible = false
crosshairFrame.Parent = gui

local crosshairHorizontal = Instance.new("Frame")
crosshairHorizontal.Name = "Horizontal"
crosshairHorizontal.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairHorizontal.Position = UDim2.fromScale(0.5, 0.5)
crosshairHorizontal.Size = UDim2.fromOffset(18, 2)
crosshairHorizontal.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
crosshairHorizontal.BorderSizePixel = 0
crosshairHorizontal.Parent = crosshairFrame

local crosshairVertical = Instance.new("Frame")
crosshairVertical.Name = "Vertical"
crosshairVertical.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairVertical.Position = UDim2.fromScale(0.5, 0.5)
crosshairVertical.Size = UDim2.fromOffset(2, 18)
crosshairVertical.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
crosshairVertical.BorderSizePixel = 0
crosshairVertical.Parent = crosshairFrame

local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.AnchorPoint = Vector2.new(1, 0)
shopFrame.Position = UDim2.new(1, -18, 0, 18)
shopFrame.Size = UDim2.fromOffset(430, 430)
shopFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
shopFrame.BackgroundTransparency = 0.06
shopFrame.Visible = false
shopFrame.Parent = gui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopFrame

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "Title"
shopTitle.Position = UDim2.fromOffset(12, 10)
shopTitle.Size = UDim2.new(1, -90, 0, 28)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextColor3 = Color3.fromRGB(241, 241, 241)
shopTitle.TextSize = 20
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "Weapon Shop"
shopTitle.Parent = shopFrame

local closeShopButton = Instance.new("TextButton")
closeShopButton.Name = "CloseButton"
closeShopButton.Position = UDim2.new(1, -66, 0, 8)
closeShopButton.Size = UDim2.fromOffset(56, 30)
closeShopButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
closeShopButton.TextColor3 = Color3.fromRGB(245, 245, 245)
closeShopButton.Font = Enum.Font.GothamBold
closeShopButton.TextSize = 16
closeShopButton.Text = "Close"
closeShopButton.Parent = shopFrame

local closeShopCorner = Instance.new("UICorner")
closeShopCorner.CornerRadius = UDim.new(0, 8)
closeShopCorner.Parent = closeShopButton

local shopStatusLabel = Instance.new("TextLabel")
shopStatusLabel.Name = "Status"
shopStatusLabel.Position = UDim2.fromOffset(12, 42)
shopStatusLabel.Size = UDim2.new(1, -24, 0, 36)
shopStatusLabel.BackgroundTransparency = 1
shopStatusLabel.Font = Enum.Font.Gotham
shopStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
shopStatusLabel.TextSize = 14
shopStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
shopStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
shopStatusLabel.TextWrapped = true
shopStatusLabel.Text = "Interact with shop NPC to buy gear."
shopStatusLabel.Parent = shopFrame

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Position = UDim2.fromOffset(12, 84)
shopList.Size = UDim2.new(1, -24, 1, -96)
shopList.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
shopList.BackgroundTransparency = 0.2
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 8
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.fromOffset(0, 0)
shopList.Parent = shopFrame

local shopListCorner = Instance.new("UICorner")
shopListCorner.CornerRadius = UDim.new(0, 8)
shopListCorner.Parent = shopList

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.Padding = UDim.new(0, 8)
shopListLayout.Parent = shopList

local skillsFrame = Instance.new("Frame")
skillsFrame.Name = "SkillsFrame"
skillsFrame.AnchorPoint = Vector2.new(1, 0)
skillsFrame.Position = UDim2.new(1, -18, 0, 460)
skillsFrame.Size = UDim2.fromOffset(430, 300)
skillsFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
skillsFrame.BackgroundTransparency = 0.06
skillsFrame.Visible = false
skillsFrame.Parent = gui

local skillsCorner = Instance.new("UICorner")
skillsCorner.CornerRadius = UDim.new(0, 12)
skillsCorner.Parent = skillsFrame

local skillsTitle = Instance.new("TextLabel")
skillsTitle.Name = "Title"
skillsTitle.Position = UDim2.fromOffset(12, 10)
skillsTitle.Size = UDim2.new(1, -90, 0, 28)
skillsTitle.BackgroundTransparency = 1
skillsTitle.Font = Enum.Font.GothamBold
skillsTitle.TextColor3 = Color3.fromRGB(241, 241, 241)
skillsTitle.TextSize = 20
skillsTitle.TextXAlignment = Enum.TextXAlignment.Left
skillsTitle.Text = "Character Skills"
skillsTitle.Parent = skillsFrame

local closeSkillsButton = Instance.new("TextButton")
closeSkillsButton.Name = "CloseButton"
closeSkillsButton.Position = UDim2.new(1, -66, 0, 8)
closeSkillsButton.Size = UDim2.fromOffset(56, 30)
closeSkillsButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
closeSkillsButton.TextColor3 = Color3.fromRGB(245, 245, 245)
closeSkillsButton.Font = Enum.Font.GothamBold
closeSkillsButton.TextSize = 16
closeSkillsButton.Text = "Close"
closeSkillsButton.Parent = skillsFrame

local closeSkillsCorner = Instance.new("UICorner")
closeSkillsCorner.CornerRadius = UDim.new(0, 8)
closeSkillsCorner.Parent = closeSkillsButton

local skillPointsLabel = Instance.new("TextLabel")
skillPointsLabel.Name = "PointsLabel"
skillPointsLabel.Position = UDim2.fromOffset(12, 42)
skillPointsLabel.Size = UDim2.new(1, -24, 0, 24)
skillPointsLabel.BackgroundTransparency = 1
skillPointsLabel.Font = Enum.Font.GothamBold
skillPointsLabel.TextColor3 = Color3.fromRGB(255, 224, 124)
skillPointsLabel.TextSize = 16
skillPointsLabel.TextXAlignment = Enum.TextXAlignment.Left
skillPointsLabel.Text = "Available points: 0"
skillPointsLabel.Parent = skillsFrame

local skillsStatusLabel = Instance.new("TextLabel")
skillsStatusLabel.Name = "StatusLabel"
skillsStatusLabel.Position = UDim2.fromOffset(12, 66)
skillsStatusLabel.Size = UDim2.new(1, -24, 0, 32)
skillsStatusLabel.BackgroundTransparency = 1
skillsStatusLabel.Font = Enum.Font.Gotham
skillsStatusLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
skillsStatusLabel.TextSize = 14
skillsStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
skillsStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
skillsStatusLabel.TextWrapped = true
skillsStatusLabel.Text = "Spend 1 point to upgrade 1 skill level."
skillsStatusLabel.Parent = skillsFrame

local skillsList = Instance.new("ScrollingFrame")
skillsList.Name = "SkillsList"
skillsList.Position = UDim2.fromOffset(12, 102)
skillsList.Size = UDim2.new(1, -24, 1, -114)
skillsList.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
skillsList.BackgroundTransparency = 0.2
skillsList.BorderSizePixel = 0
skillsList.ScrollBarThickness = 8
skillsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
skillsList.CanvasSize = UDim2.fromOffset(0, 0)
skillsList.Parent = skillsFrame

local skillsListCorner = Instance.new("UICorner")
skillsListCorner.CornerRadius = UDim.new(0, 8)
skillsListCorner.Parent = skillsList

local skillsListLayout = Instance.new("UIListLayout")
skillsListLayout.Padding = UDim.new(0, 8)
skillsListLayout.Parent = skillsList

local currentToolName = ""
local ammoMag = 0
local ammoReserve = 0
local isReloading = false
local aimModeEnabled = false
local currentHealth = 100
local maxHealth = 100
local currentXp = 0
local currentLevel = 1
local meleeAnimationToggle = false
local shopItems = {}
local skillPoints = 0
local skillStateItems = {}
local animationTracksByHumanoid = setmetatable({}, { __mode = "k" })
local SHOP_AUTO_CLOSE_DISTANCE = 15
local getCurrentWeapon

local function hasBlockingUiOpen()
	return shopFrame.Visible or skillsFrame.Visible or reviveButtonsFrame.Visible
end

local function updateCrosshairVisibility()
	local _, weapon = getCurrentWeapon()
	crosshairFrame.Visible = aimModeEnabled and weapon and weapon.Category == "Ranged" and not hasBlockingUiOpen()
end

local function setAimModeEnabled(enabled)
	if enabled and hasBlockingUiOpen() then
		enabled = false
	end

	if aimModeEnabled == enabled then
		updateCrosshairVisibility()
		return
	end

	aimModeEnabled = enabled
	if aimModeEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
	end

	updateCrosshairVisibility()
end

local function hideReviveButtons()
	reviveButtonsFrame.Visible = false
	soloReviveButton.Visible = false
	teamReviveButton.Visible = false
end

local function showReviveButtons(data)
	local canSolo = data.canSolo == true
	local canTeam = data.canTeam == true
	local soloPrice = tonumber(data.soloPrice) or 10
	local teamPrice = tonumber(data.teamPrice) or 50

	soloReviveButton.Text = ("Solo Revive (%d R$)"):format(soloPrice)
	teamReviveButton.Text = ("Team Revive (%d R$)"):format(teamPrice)
	soloReviveButton.Visible = canSolo
	teamReviveButton.Visible = canTeam
	reviveButtonsFrame.Visible = canSolo or canTeam
end

local function getShopkeeperRoot()
	local shopsFolder = Workspace:FindFirstChild("Shops")
	local shopModel = shopsFolder and shopsFolder:FindFirstChild("WeaponShop")
	local npc = shopModel and shopModel:FindFirstChild("Shopkeeper")
	local root = npc and npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function xpForLevel(level)
	return combatConfig.Progression.BaseXpForLevel + math.max(0, level - 1) * combatConfig.Progression.XpGrowthPerLevel
end

local function getWeaponByToolName(toolName)
	local weaponKey = weaponByToolName[toolName]
	if not weaponKey then
		return nil, nil
	end

	return weaponKey, combatConfig.Weapons[weaponKey]
end

getCurrentWeapon = function()
	local weaponKey, weapon = getWeaponByToolName(currentToolName)
	return weaponKey, weapon
end

local function refreshHealthHud()
	local safeMax = math.max(1, maxHealth)
	local ratio = math.clamp(currentHealth / safeMax, 0, 1)
	playerHealthFill.Size = UDim2.fromScale(ratio, 1)
	playerHealthLabel.Text = ("HP: %d / %d"):format(math.floor(currentHealth + 0.5), math.floor(safeMax + 0.5))
end

local function refreshXpHud()
	local needed = xpForLevel(currentLevel)
	local ratio = 0
	if needed > 0 then
		ratio = math.clamp(currentXp / needed, 0, 1)
	end

	xpFill.Size = UDim2.fromScale(ratio, 1)
	xpLabel.Text = ("Lvl %d | XP %d/%d"):format(currentLevel, currentXp, needed)
end

local function refreshSkillPointsBadge()
	local hasPoints = skillPoints > 0
	skillPointsBadge.Visible = hasPoints
	skillPointsBadgeLabel.Text = tostring(skillPoints)
	skillPointsLabel.Text = ("Available points: %d"):format(skillPoints)
end

local function clearSkillRows()
	for _, child in ipairs(skillsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function buildSkillRow(item)
	local row = Instance.new("Frame")
	row.Name = "Skill_" .. tostring(item.key)
	row.Size = UDim2.new(1, -6, 0, 58)
	row.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	row.BorderSizePixel = 0
	row.Parent = skillsList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -160, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(240, 240, 240)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ("%s  [%d/%d]"):format(item.displayName, item.level, item.maxLevel)
	title.Parent = row

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(10, 28)
	hint.Size = UDim2.new(1, -160, 0, 20)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(198, 198, 198)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "1 level = 1 point"
	hint.Parent = row

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Position = UDim2.new(1, -138, 0.5, -14)
	upgradeButton.Size = UDim2.fromOffset(126, 28)
	upgradeButton.Font = Enum.Font.GothamBold
	upgradeButton.TextSize = 13
	upgradeButton.TextColor3 = Color3.fromRGB(245, 245, 245)
	upgradeButton.Parent = row

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = upgradeButton

	local isMaxed = item.level >= item.maxLevel
	if isMaxed then
		upgradeButton.Text = "Maxed"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
		upgradeButton.Active = false
	elseif skillPoints <= 0 then
		upgradeButton.Text = "No points"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
		upgradeButton.Active = false
	else
		upgradeButton.Text = "Upgrade +1"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(70, 120, 78)
		upgradeButton.MouseButton1Click:Connect(function()
			skillEvent:FireServer("upgrade", item.key)
		end)
	end
end

local function refreshSkillsUi(items, message)
	if items then
		skillStateItems = items
	end
	if message and message ~= "" then
		skillsStatusLabel.Text = message
	end

	refreshSkillPointsBadge()
	clearSkillRows()
	for _, item in ipairs(skillStateItems) do
		buildSkillRow(item)
	end
end

local function refreshCombatHud()
	local _, weapon = getWeaponByToolName(currentToolName)
	local prettyName = "None"
	if weapon then
		prettyName = weapon.DisplayName
	end

	weaponLabel.Text = ("Weapon: %s"):format(prettyName)

	if weapon and weapon.Category == "Ranged" then
		local suffix = isReloading and " (reloading)" or ""
		ammoLabel.Text = ("Ammo: %d / %d%s"):format(ammoMag, ammoReserve, suffix)
		controlsLabel.Text = "LMB fire | RMB aim | R reload | E interact | B open shop"
	elseif weapon and weapon.Category == "Melee" then
		ammoLabel.Text = "Ammo: --"
		controlsLabel.Text = "LMB melee attack | RMB camera lock | E interact | B open shop"
	else
		ammoLabel.Text = "Ammo: --"
		controlsLabel.Text = "Equip a weapon from Backpack | RMB camera lock | E interact | B open shop"
	end

	updateCrosshairVisibility()
end

local function refreshMoneyLabel()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		moneyLabel.Text = "Money: 0$"
		return
	end

	local money = leaderstats:FindFirstChild("Money")
	if not money then
		moneyLabel.Text = "Money: 0$"
		return
	end

	moneyLabel.Text = ("Money: %d$"):format(money.Value)
end

local function refreshXpFromStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		currentXp = 0
		currentLevel = 1
		refreshXpHud()
		return
	end

	local xp = leaderstats:FindFirstChild("XP")
	local level = leaderstats:FindFirstChild("Level")
	if xp and xp:IsA("IntValue") then
		currentXp = math.max(0, xp.Value)
	end
	if level and level:IsA("IntValue") then
		currentLevel = math.max(1, level.Value)
	end

	refreshXpHud()
end

local function refreshSkillPointsFromStats()
	local progression = player:FindFirstChild("Progression")
	if not progression then
		skillPoints = 0
		refreshSkillPointsBadge()
		return
	end

	local points = progression:FindFirstChild("SkillPoints")
	if points and points:IsA("IntValue") then
		skillPoints = math.max(0, points.Value)
	else
		skillPoints = 0
	end

	refreshSkillPointsBadge()
	if skillsFrame.Visible then
		refreshSkillsUi(nil, "")
	end
end

local function bindStatsListeners()
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Money")
	local xp = leaderstats:WaitForChild("XP")
	local level = leaderstats:WaitForChild("Level")
	local progression = player:WaitForChild("Progression")
	local skillPointsStat = progression:WaitForChild("SkillPoints")

	refreshMoneyLabel()
	refreshXpFromStats()
	refreshSkillPointsFromStats()
	money:GetPropertyChangedSignal("Value"):Connect(refreshMoneyLabel)
	xp:GetPropertyChangedSignal("Value"):Connect(refreshXpFromStats)
	level:GetPropertyChangedSignal("Value"):Connect(refreshXpFromStats)
	skillPointsStat:GetPropertyChangedSignal("Value"):Connect(refreshSkillPointsFromStats)
end

local function bindHumanoid(humanoid)
	local function update()
		currentHealth = math.max(0, humanoid.Health)
		maxHealth = math.max(1, humanoid.MaxHealth)
		refreshHealthHud()
	end

	update()
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
end

local function clearShopRows()
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function buildShopRow(item)
	local row = Instance.new("Frame")
	row.Name = "Row_" .. tostring(item.key)
	row.Size = UDim2.new(1, -6, 0, 88)
	row.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	row.BorderSizePixel = 0
	row.Parent = shopList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -20, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(243, 243, 243)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ("%s (%s)"):format(item.displayName, item.category)
	title.Parent = row

	local priceLabel = Instance.new("TextLabel")
	priceLabel.BackgroundTransparency = 1
	priceLabel.Position = UDim2.fromOffset(10, 30)
	priceLabel.Size = UDim2.new(1, -20, 0, 18)
	priceLabel.Font = Enum.Font.Gotham
	priceLabel.TextSize = 14
	priceLabel.TextColor3 = Color3.fromRGB(206, 206, 206)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Text = ("Weapon price: $%d"):format(item.price)
	priceLabel.Parent = row

	local buyWeaponButton = Instance.new("TextButton")
	buyWeaponButton.Position = UDim2.new(0, 10, 1, -34)
	buyWeaponButton.Size = UDim2.fromOffset(160, 26)
	buyWeaponButton.Font = Enum.Font.GothamBold
	buyWeaponButton.TextSize = 13
	buyWeaponButton.TextColor3 = Color3.fromRGB(245, 245, 245)
	buyWeaponButton.Parent = row

	local buyWeaponCorner = Instance.new("UICorner")
	buyWeaponCorner.CornerRadius = UDim.new(0, 6)
	buyWeaponCorner.Parent = buyWeaponButton

	if item.owned then
		buyWeaponButton.Text = "Owned"
		buyWeaponButton.BackgroundColor3 = Color3.fromRGB(44, 122, 72)
		buyWeaponButton.Active = false
	else
		buyWeaponButton.Text = "Buy Weapon"
		buyWeaponButton.BackgroundColor3 = Color3.fromRGB(67, 88, 142)
		buyWeaponButton.MouseButton1Click:Connect(function()
			shopEvent:FireServer("buyWeapon", item.key)
		end)
	end

	if item.category == "Ranged" then
		local ammoButton = Instance.new("TextButton")
		ammoButton.Position = UDim2.new(1, -202, 1, -34)
		ammoButton.Size = UDim2.fromOffset(192, 26)
		ammoButton.Font = Enum.Font.GothamBold
		ammoButton.TextSize = 13
		ammoButton.TextColor3 = Color3.fromRGB(245, 245, 245)
		ammoButton.Text = ("Buy Ammo +%d ($%d)"):format(item.ammoPackAmount, item.ammoPackPrice)
		ammoButton.Parent = row

		local ammoCorner = Instance.new("UICorner")
		ammoCorner.CornerRadius = UDim.new(0, 6)
		ammoCorner.Parent = ammoButton

		if item.owned then
			ammoButton.BackgroundColor3 = Color3.fromRGB(93, 80, 46)
			ammoButton.MouseButton1Click:Connect(function()
				shopEvent:FireServer("buyAmmo", item.key)
			end)
		else
			ammoButton.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
			ammoButton.Active = false
		end
	end
end

local function refreshShopUi(items, message)
	shopItems = items or {}
	if message and message ~= "" then
		shopStatusLabel.Text = message
	end

	clearShopRows()
	for _, item in ipairs(shopItems) do
		buildShopRow(item)
	end
end

local function setCurrentToolNameByCharacter(character)
	if not character then
		currentToolName = ""
		refreshCombatHud()
		return
	end

	local foundToolName = ""
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			foundToolName = child.Name
			break
		end
	end

	currentToolName = foundToolName
	refreshCombatHud()
end

local function playAnimationById(animationId, speed)
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local tracks = animationTracksByHumanoid[humanoid]
	if not tracks then
		tracks = {}
		animationTracksByHumanoid[humanoid] = tracks
	end

	local track = tracks[animationId]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local ok, loadedTrack = pcall(function()
			return humanoid:LoadAnimation(animation)
		end)
		animation:Destroy()
		if not ok or not loadedTrack then
			return
		end

		track = loadedTrack
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		tracks[animationId] = track
	end

	if track.IsPlaying then
		track:Stop(0.04)
	end

	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.05, 1, speed or 1)
	track:AdjustSpeed(speed or 1)
end

local function clearAnimationCacheForCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		animationTracksByHumanoid[humanoid] = nil
	end
end

local function playWeaponFireAnimation(weaponKey)
	local weapon = combatConfig.Weapons[weaponKey]
	if not weapon then
		return
	end

	if weapon.Category == "Ranged" then
		playAnimationById(weapon.FireAnimationId, 1.05)
	else
		local animationId = weapon.SwingAnimationId
		if meleeAnimationToggle and weapon.SwingAltAnimationId then
			animationId = weapon.SwingAltAnimationId
		end
		meleeAnimationToggle = not meleeAnimationToggle
		playAnimationById(animationId, 1.08)
	end
end

local function playWeaponReloadAnimation(weaponKey)
	local weapon = combatConfig.Weapons[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return
	end

	playAnimationById(weapon.ReloadAnimationId, 1)
end

local function bindCharacter(character)
	setAimModeEnabled(false)
	clearAnimationCacheForCharacter(character)
	setCurrentToolNameByCharacter(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		bindHumanoid(humanoid)
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentToolName = child.Name
			refreshCombatHud()
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			setCurrentToolNameByCharacter(character)
		end
	end)
end

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
	if hasBlockingUiOpen() then
		return
	end

	local weaponKey, weapon = getCurrentWeapon()
	if not weaponKey or not weapon then
		return
	end

	if weapon.Category == "Ranged" then
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local direction
		if aimModeEnabled then
			local viewport = camera.ViewportSize
			local centerRay = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
			direction = centerRay.Direction
		else
			local origin = camera.CFrame.Position
			direction = mouse.Hit.Position - origin
			if direction.Magnitude < 0.01 then
				direction = camera.CFrame.LookVector
			end
		end

		playWeaponFireAnimation(weaponKey)
		combatActionEvent:FireServer("fire", {
			direction = direction,
		})
	else
		playWeaponFireAnimation(weaponKey)
		combatActionEvent:FireServer("melee")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAimModeEnabled(true)
		return
	end

	if reviveButtonsFrame.Visible then
		return
	end

	if input.KeyCode == Enum.KeyCode.B then
		setAimModeEnabled(false)
		shopEvent:FireServer("open")
		return
	end

	if input.KeyCode == Enum.KeyCode.K then
		setAimModeEnabled(false)
		skillEvent:FireServer("open")
		return
	end

	if hasBlockingUiOpen() then
		return
	end

	local weaponKey, weapon = getCurrentWeapon()
	if not weaponKey or not weapon then
		return
	end

	if input.KeyCode == Enum.KeyCode.R and weapon.Category == "Ranged" then
		playWeaponReloadAnimation(weaponKey)
		combatActionEvent:FireServer("reload")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAimModeEnabled(false)
	end
end)

closeShopButton.MouseButton1Click:Connect(function()
	setAimModeEnabled(false)
	shopFrame.Visible = false
end)

openSkillsButton.MouseButton1Click:Connect(function()
	setAimModeEnabled(false)
	skillEvent:FireServer("open")
end)

closeSkillsButton.MouseButton1Click:Connect(function()
	setAimModeEnabled(false)
	skillsFrame.Visible = false
end)

soloReviveButton.MouseButton1Click:Connect(function()
	revivePurchaseEvent:FireServer("request_solo")
end)

teamReviveButton.MouseButton1Click:Connect(function()
	revivePurchaseEvent:FireServer("request_team")
end)

combatStateEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	local wasReloading = isReloading

	if typeof(data.mag) == "number" then
		ammoMag = math.max(0, math.floor(data.mag))
	end

	if typeof(data.reserve) == "number" then
		ammoReserve = math.max(0, math.floor(data.reserve))
	end

	if typeof(data.reloading) == "boolean" then
		isReloading = data.reloading
	end

	if typeof(data.equippedToolName) == "string" then
		currentToolName = data.equippedToolName
	end

	if not wasReloading and isReloading then
		local weaponKey, weapon = getCurrentWeapon()
		if weaponKey and weapon and weapon.Category == "Ranged" then
			playWeaponReloadAnimation(weaponKey)
		end
	end

	refreshCombatHud()
end)

shopEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if data.type == "close" then
		shopFrame.Visible = false
		updateCrosshairVisibility()
		return
	end

	setAimModeEnabled(false)
	if typeof(data.money) == "number" then
		moneyLabel.Text = ("Money: %d$"):format(data.money)
	end

	refreshShopUi(data.items or {}, data.message or "")
	shopFrame.Visible = true
end)

skillEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	setAimModeEnabled(false)
	if typeof(data.points) == "number" then
		skillPoints = math.max(0, math.floor(data.points))
	end

	refreshSkillsUi(data.skills or skillStateItems, data.message or "")
	skillsFrame.Visible = true
end)

survivalEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.text) == "string" and data.text ~= "" then
		survivalStatusLabel.Text = data.text
	end

	if data.type == "respawn" then
		local seconds = tonumber(data.seconds) or 0
		respawnStatusLabel.Visible = true
		if typeof(data.text) == "string" and data.text ~= "" then
			respawnStatusLabel.Text = data.text
		else
			respawnStatusLabel.Text = ("Downed. Auto-respawn in %ds"):format(math.max(0, math.floor(seconds)))
		end
	elseif data.type == "wipe_timer" then
		local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
		respawnStatusLabel.Visible = true
		respawnStatusLabel.Text = ("Team wipe. Revive window: %ds"):format(seconds)
	elseif data.type == "revive_options" then
		setAimModeEnabled(false)
		showReviveButtons(data)
		if data.wipeOnly then
			local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
			respawnStatusLabel.Visible = true
			respawnStatusLabel.Text = ("Team wipe. Buy revive in %ds"):format(seconds)
		end
	elseif data.type == "revive_options_clear" then
		hideReviveButtons()
	elseif data.type == "respawn_clear" then
		respawnStatusLabel.Visible = false
		respawnStatusLabel.Text = ""
		hideReviveButtons()
	elseif data.type == "match" then
		respawnStatusLabel.Visible = false
		respawnStatusLabel.Text = ""
		hideReviveButtons()
	end
end)

task.spawn(bindStatsListeners)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(character)
	clearAnimationCacheForCharacter(character)
	setAimModeEnabled(false)
	hideReviveButtons()
end)

RunService.RenderStepped:Connect(function()
	if hasBlockingUiOpen() and aimModeEnabled then
		setAimModeEnabled(false)
	end

	if not shopFrame.Visible then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shopRoot = getShopkeeperRoot()
	if not root or not root:IsA("BasePart") or not shopRoot then
		shopFrame.Visible = false
		updateCrosshairVisibility()
		return
	end

	if (root.Position - shopRoot.Position).Magnitude > SHOP_AUTO_CLOSE_DISTANCE then
		shopFrame.Visible = false
		shopStatusLabel.Text = "You moved away from the shop."
		updateCrosshairVisibility()
	end
end)

refreshCombatHud()
refreshHealthHud()
refreshXpHud()
refreshSkillPointsBadge()
hideReviveButtons()
