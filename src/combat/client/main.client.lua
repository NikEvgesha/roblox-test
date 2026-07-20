local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local COMBAT_ACTION_EVENT_NAME = "CombatAction"
local COMBAT_STATE_EVENT_NAME = "CombatState"
local COMBAT_FEEDBACK_EVENT_NAME = "CombatFeedback"
local SHOP_EVENT_NAME = "ShopEvent"
local SKILL_EVENT_NAME = "SkillEvent"
local SURVIVAL_EVENT_NAME = "SurvivalEvent"
local REVIVE_PURCHASE_EVENT_NAME = "RevivePurchaseEvent"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local SpectatorController = require(script.Parent:WaitForChild("SpectatorController"))
local WeaponController = require(script.Parent:WaitForChild("WeaponController"))
local CombatInputController = require(script.Parent:WaitForChild("CombatInputController"))
local AimController = require(script.Parent:WaitForChild("AimController"))
local CombatHudView = require(script.Parent:WaitForChild("CombatHudView"))
local CombatFeedbackController = require(script.Parent:WaitForChild("CombatFeedbackController"))

local combatActionEvent = ReplicatedStorage:WaitForChild(COMBAT_ACTION_EVENT_NAME)
local combatStateEvent = ReplicatedStorage:WaitForChild(COMBAT_STATE_EVENT_NAME)
local combatFeedbackEvent = ReplicatedStorage:WaitForChild(COMBAT_FEEDBACK_EVENT_NAME)
local shopEvent = ReplicatedStorage:WaitForChild(SHOP_EVENT_NAME)
local skillEvent = ReplicatedStorage:WaitForChild(SKILL_EVENT_NAME)
local survivalEvent = ReplicatedStorage:WaitForChild(SURVIVAL_EVENT_NAME)
local revivePurchaseEvent = ReplicatedStorage:WaitForChild(REVIVE_PURCHASE_EVENT_NAME)

local weaponByToolName = {}
for weaponKey, definition in pairs(combatConfig.Weapons) do
	weaponByToolName[definition.ToolName] = weaponKey
end

local hud = CombatHudView.new({
	playerGui = playerGui,
	combatConfig = combatConfig,
})
local moneyLabel = hud.MoneyLabel
local ammoLabel = hud.AmmoLabel
local weaponLabel = hud.WeaponLabel
local controlsLabel = hud.ControlsLabel
local survivalStatusLabel = hud.SurvivalStatusLabel
local respawnStatusLabel = hud.RespawnStatusLabel
local reviveButtonsFrame = hud.ReviveButtonsFrame
local soloReviveButton = hud.SoloReviveButton
local teamReviveButton = hud.TeamReviveButton
local openSkillsButton = hud.OpenSkillsButton
local skillPointsBadge = hud.SkillPointsBadge
local skillPointsBadgeLabel = hud.SkillPointsBadgeLabel
local playerHealthFill = hud.PlayerHealthFill
local playerHealthLabel = hud.PlayerHealthLabel
local xpFill = hud.XpFill
local xpLabel = hud.XpLabel
local crosshairFrame = hud.CrosshairFrame
local shopFrame = hud.ShopFrame
local closeShopButton = hud.CloseShopButton
local shopStatusLabel = hud.ShopStatusLabel
local shopList = hud.ShopList
local skillsFrame = hud.SkillsFrame
local closeSkillsButton = hud.CloseSkillsButton
local skillPointsLabel = hud.SkillPointsLabel
local skillsStatusLabel = hud.SkillsStatusLabel
local skillsList = hud.SkillsList
local feedbackController = CombatFeedbackController.new({
	workspace = Workspace,
	gui = hud.Gui,
	soundService = SoundService,
})
local hitMarkerFrame = feedbackController:GetHitMarkerFrame()

local currentToolName = ""
local ammoMag = 0
local ammoReserve = 0
local currentHealth = 100
local maxHealth = 100
local currentXp = 0
local currentLevel = 1
local shopItems = {}
local skillPoints = 0
local skillStateItems = {}
local animationTracksByHumanoid = setmetatable({}, { __mode = "k" })
local SHOP_AUTO_CLOSE_DISTANCE = 15
local getCurrentWeapon
local mouse = player:GetMouse()
local spectatorController
local aimController
local weaponController
local inputController
local MELEE_AUTO_LOCK_DISTANCE = 8


local function hasBlockingUiOpen()
	return shopFrame.Visible or skillsFrame.Visible or reviveButtonsFrame.Visible
end


spectatorController = SpectatorController.new({
	player = player,
	workspace = Workspace,
	userInputService = UserInputService,
	mouse = mouse,
	onModeChanged = function(enabled)
		if aimController then
			if enabled then
				aimController:SetAimModeEnabled(false)
			else
				aimController:UpdateCrosshairVisibility()
			end
		end
	end,
})


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

aimController = AimController.new({
	player = player,
	workspace = Workspace,
	userInputService = UserInputService,
	mouse = mouse,
	crosshairFrame = crosshairFrame,
	hitMarkerFrame = hitMarkerFrame,
	spectatorController = spectatorController,
	getCurrentWeapon = getCurrentWeapon,
	hasBlockingUiOpen = hasBlockingUiOpen,
	meleeLockDistance = MELEE_AUTO_LOCK_DISTANCE,
})

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
		if (combatConfig.Ammo or {}).MagazinesEnabled then
			local suffix = weaponController and weaponController:IsReloading() and " (reloading)" or ""
			if ammoReserve < 0 then
				ammoLabel.Text = ("Ammo: %d / INF%s"):format(ammoMag, suffix)
			else
				ammoLabel.Text = ("Ammo: %d / %d%s"):format(ammoMag, ammoReserve, suffix)
			end
			controlsLabel.Text = "LMB fire | RMB aim | R reload | E interact | B open shop"
		else
			controlsLabel.Text = "LMB fire | RMB aim | E interact | B open shop"
		end
	elseif weapon and weapon.Category == "Melee" then
		ammoLabel.Text = "Ammo: --"
		controlsLabel.Text = "LMB melee attack | RMB camera lock | E interact | B open shop"
	else
		ammoLabel.Text = "Ammo: --"
		controlsLabel.Text = "Equip a weapon from Backpack | RMB camera lock | E interact | B open shop"
	end

	aimController:UpdateCrosshairVisibility()
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

	if item.category == "Ranged" and (item.ammoPackPrice or 0) > 0 and (item.ammoPackAmount or 0) > 0 then
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
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
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
			return nil
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
	return track
end

local function clearAnimationCacheForCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		animationTracksByHumanoid[humanoid] = nil
	end
end

local function playWeaponFireAnimation(weaponKey, meleeCooldown)
	local weapon = combatConfig.Weapons[weaponKey]
	if not weapon then
		return
	end

	if weapon.Category == "Ranged" then
		playAnimationById(weapon.FireAnimationId, weapon.FireAnimationSpeed or 1)
		return
	end

	if weapon.Category ~= "Melee" then
		return
	end

	local animationId = weapon.SwingAnimationId
	if type(animationId) ~= "string" or animationId == "" then
		animationId = weapon.SwingAltAnimationId
	end
	local baseSpeed = weapon.SwingAnimationSpeed or 1
	local targetCooldown = math.max(0.2, tonumber(meleeCooldown) or tonumber(weapon.Cooldown) or 0.75)
	local track = playAnimationById(animationId, 1)
	if track then
		local trackLength = tonumber(track.Length) or 0
		if trackLength > 0.01 then
			local targetDuration = math.max(0.16, targetCooldown * 0.9)
			local speedScale = math.clamp(trackLength / targetDuration, 0.35, 3.5)
			track:AdjustSpeed(baseSpeed * speedScale)
		else
			track:AdjustSpeed(baseSpeed)
		end

		local stopAfter = math.max(0.12, math.min(targetCooldown, targetCooldown * 0.95))
		task.delay(stopAfter, function()
			if track and track.IsPlaying then
				track:Stop(0.08)
			end
		end)
	end
end

local function playWeaponReloadAnimation(weaponKey)
	local weapon = combatConfig.Weapons[weaponKey]
	if not weapon or weapon.Category ~= "Ranged" then
		return
	end

	return
end

weaponController = WeaponController.new({
	player = player,
	workspace = Workspace,
	combatConfig = combatConfig,
	combatActionEvent = combatActionEvent,
	getCurrentWeapon = getCurrentWeapon,
	resolveRangedAimData = function(...)
		return aimController:ResolveRangedAimData(...)
	end,
	findNearestEnemyRoot = function(...)
		return aimController:FindNearestEnemyRoot(...)
	end,
	playFireAnimation = playWeaponFireAnimation,
	playReloadAnimation = playWeaponReloadAnimation,
	applyShotRecoil = function(weapon)
		aimController:ApplyShotRecoil(weapon)
	end,
	meleeLockDistance = MELEE_AUTO_LOCK_DISTANCE,
	canAct = function()
		return not spectatorController:IsEnabled() and not hasBlockingUiOpen()
	end,
})

inputController = CombatInputController.new({
	mouse = mouse,
	userInputService = UserInputService,
	spectatorController = spectatorController,
	weaponController = weaponController,
	setAimEnabled = function(enabled)
		aimController:SetAimModeEnabled(enabled)
	end,
	isReviveUiVisible = function()
		return reviveButtonsFrame.Visible
	end,
	hasBlockingUiOpen = hasBlockingUiOpen,
	openShop = function()
		shopEvent:FireServer("open")
	end,
	openSkills = function()
		skillEvent:FireServer("open")
	end,
})
inputController:Start()

local function bindCharacter(character)
	spectatorController:SetDowned(false)
	clearAnimationCacheForCharacter(character)
	aimController:BindCharacter(character)
	setCurrentToolNameByCharacter(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		bindHumanoid(humanoid)
		spectatorController:RestoreGameplayCamera()
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

closeShopButton.MouseButton1Click:Connect(function()
	aimController:SetAimModeEnabled(false)
	shopFrame.Visible = false
end)

openSkillsButton.MouseButton1Click:Connect(function()
	aimController:SetAimModeEnabled(false)
	skillEvent:FireServer("open")
end)

closeSkillsButton.MouseButton1Click:Connect(function()
	aimController:SetAimModeEnabled(false)
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

	if typeof(data.mag) == "number" then
		ammoMag = math.max(0, math.floor(data.mag))
	end

	if typeof(data.reserve) == "number" then
		ammoReserve = math.max(0, math.floor(data.reserve))
	end

	if typeof(data.equippedToolName) == "string" then
		currentToolName = data.equippedToolName
	end
	weaponController:ApplyCombatState(data)

	refreshCombatHud()
end)

combatFeedbackEvent.OnClientEvent:Connect(function(data)
	feedbackController:Handle(data)
end)

shopEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if data.type == "close" then
		shopFrame.Visible = false
		aimController:UpdateCrosshairVisibility()
		return
	end

	aimController:SetAimModeEnabled(false)
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

	aimController:SetAimModeEnabled(false)
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
		spectatorController:SetDowned(true)
		local seconds = tonumber(data.seconds) or 0
		respawnStatusLabel.Visible = true
		if typeof(data.text) == "string" and data.text ~= "" then
			respawnStatusLabel.Text = ("%s | Spectate: WASD + Space/Ctrl, hold RMB to look"):format(data.text)
		else
			respawnStatusLabel.Text = ("Downed. Auto-respawn in %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
				:format(math.max(0, math.floor(seconds)))
		end
	elseif data.type == "wipe_timer" then
		spectatorController:SetDowned(true)
		local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
		respawnStatusLabel.Visible = true
		respawnStatusLabel.Text = ("Team wipe. Revive window: %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
			:format(seconds)
	elseif data.type == "revive_options" then
		spectatorController:SetDowned(true)
		aimController:SetAimModeEnabled(false)
		showReviveButtons(data)
		if data.wipeOnly then
			local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
			respawnStatusLabel.Visible = true
			respawnStatusLabel.Text = ("Team wipe. Buy revive in %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
				:format(seconds)
		end
	elseif data.type == "revive_options_clear" then
		hideReviveButtons()
	elseif data.type == "respawn_clear" then
		spectatorController:SetDowned(false)
		respawnStatusLabel.Visible = false
		respawnStatusLabel.Text = ""
		hideReviveButtons()
	elseif data.type == "match" then
		if not spectatorController:IsDowned() then
			respawnStatusLabel.Visible = false
			respawnStatusLabel.Text = ""
			hideReviveButtons()
		end
	end
end)

task.spawn(bindStatsListeners)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(character)
	clearAnimationCacheForCharacter(character)
	aimController:UnbindCharacter(character)
	hideReviveButtons()
	weaponController:HandlePrimaryUp()
end)

RunService.RenderStepped:Connect(function(deltaTime)
	feedbackController:Update(deltaTime)
	aimController:Update(deltaTime)

	weaponController:Update()
	aimController:ReconcileRightMouse()

	spectatorController:Update(deltaTime)
	aimController:ReconcileBlockingUi()

	if not shopFrame.Visible then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shopRoot = getShopkeeperRoot()
	if not root or not root:IsA("BasePart") or not shopRoot then
		shopFrame.Visible = false
		aimController:UpdateCrosshairVisibility()
		return
	end

	if (root.Position - shopRoot.Position).Magnitude > SHOP_AUTO_CLOSE_DISTANCE then
		shopFrame.Visible = false
		shopStatusLabel.Text = "You moved away from the shop."
		aimController:UpdateCrosshairVisibility()
	end
end)

refreshCombatHud()
refreshHealthHud()
refreshXpHud()
refreshSkillPointsBadge()
hideReviveButtons()
