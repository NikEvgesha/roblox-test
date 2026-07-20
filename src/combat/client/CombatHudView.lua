local CombatHudView = {}

function CombatHudView.new(options)
    options = type(options) == "table" and options or {}
    local playerGui = assert(options.playerGui, "CombatHudView requires playerGui")
    local combatConfig = assert(options.combatConfig, "CombatHudView requires combatConfig")
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
    ammoLabel.Visible = (combatConfig.Ammo or {}).MagazinesEnabled == true
    
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
    controlsLabel.Text = "LMB fire/attack | RMB aim | E interact | B open shop"
    controlsLabel.Parent = gui
    
    if not (combatConfig.Ammo or {}).MagazinesEnabled then
    	weaponLabel.Position = UDim2.fromOffset(18, 58)
    	controlsLabel.Position = UDim2.fromOffset(18, 91)
    end
    
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
    openSkillsButton.Text = "Run Stats [K]"
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
    skillsTitle.Text = "Run Stat Upgrades"
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
    skillsStatusLabel.Text = "Optional stat upgrades. Profession abilities use the left ability panel."
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

    return {
        Gui = gui,
        MoneyLabel = moneyLabel,
        AmmoLabel = ammoLabel,
        WeaponLabel = weaponLabel,
        ControlsLabel = controlsLabel,
        SurvivalStatusLabel = survivalStatusLabel,
        RespawnStatusLabel = respawnStatusLabel,
        ReviveButtonsFrame = reviveButtonsFrame,
        SoloReviveButton = soloReviveButton,
        TeamReviveButton = teamReviveButton,
        OpenSkillsButton = openSkillsButton,
        SkillPointsBadge = skillPointsBadge,
        SkillPointsBadgeLabel = skillPointsBadgeLabel,
        PlayerHealthFill = playerHealthFill,
        PlayerHealthLabel = playerHealthLabel,
        XpFill = xpFill,
        XpLabel = xpLabel,
        CrosshairFrame = crosshairFrame,
        ShopFrame = shopFrame,
        CloseShopButton = closeShopButton,
        ShopStatusLabel = shopStatusLabel,
        ShopList = shopList,
        SkillsFrame = skillsFrame,
        CloseSkillsButton = closeSkillsButton,
        SkillPointsLabel = skillPointsLabel,
        SkillsStatusLabel = skillsStatusLabel,
        SkillsList = skillsList,
    }
end

return CombatHudView
