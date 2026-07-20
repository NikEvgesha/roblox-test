local CombatHudController = {}
CombatHudController.__index = CombatHudController

local SHOP_AUTO_CLOSE_DISTANCE = 15

local function noOp() end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

function CombatHudController.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, CombatHudController)
	self.player = assert(options.player, "CombatHudController requires player")
	self.workspace = assert(options.workspace, "CombatHudController requires workspace")
	self.combatConfig = assert(options.combatConfig, "CombatHudController requires combatConfig")
	self.view = assert(options.view, "CombatHudController requires view")
	self.combatStateEvent = assert(options.combatStateEvent, "CombatHudController requires combatStateEvent")
	self.shopEvent = assert(options.shopEvent, "CombatHudController requires shopEvent")
	self.skillEvent = assert(options.skillEvent, "CombatHudController requires skillEvent")
	self.survivalEvent = assert(options.survivalEvent, "CombatHudController requires survivalEvent")
	self.revivePurchaseEvent = assert(options.revivePurchaseEvent, "CombatHudController requires revivePurchaseEvent")
	self.spectatorController = assert(options.spectatorController, "CombatHudController requires spectatorController")
	self.setAimModeEnabled = options.setAimModeEnabled or noOp
	self.updateCrosshairVisibility = options.updateCrosshairVisibility or noOp
	self.weaponController = options.weaponController
	self.currentToolName = ""
	self.ammoMag = 0
	self.ammoReserve = 0
	self.currentHealth = 100
	self.maxHealth = 100
	self.currentXp = 0
	self.currentLevel = 1
	self.skillPoints = 0
	self.skillStateItems = {}
	self.connections = {}
	self.characterConnections = {}
	self.humanoidConnections = {}
	self.statsConnections = {}
	self.started = false
	self.weaponByToolName = {}
	for weaponKey, definition in pairs(self.combatConfig.Weapons) do
		self.weaponByToolName[definition.ToolName] = weaponKey
	end
	return self
end

function CombatHudController:SetAimCallbacks(setAimModeEnabled, updateCrosshairVisibility)
	self.setAimModeEnabled = setAimModeEnabled or noOp
	self.updateCrosshairVisibility = updateCrosshairVisibility or noOp
end

function CombatHudController:SetWeaponController(weaponController)
	self.weaponController = weaponController
end

function CombatHudController:HasBlockingUiOpen()
	local view = self.view
	return view.ShopFrame.Visible or view.SkillsFrame.Visible or view.ReviveButtonsFrame.Visible
end

function CombatHudController:IsReviveUiVisible()
	return self.view.ReviveButtonsFrame.Visible
end

function CombatHudController:GetCurrentWeapon()
	local weaponKey = self.weaponByToolName[self.currentToolName]
	if not weaponKey then
		return nil, nil
	end
	return weaponKey, self.combatConfig.Weapons[weaponKey]
end

function CombatHudController:HideReviveButtons()
	local view = self.view
	view.ReviveButtonsFrame.Visible = false
	view.SoloReviveButton.Visible = false
	view.TeamReviveButton.Visible = false
end

function CombatHudController:ShowReviveButtons(data)
	local view = self.view
	local canSolo = data.canSolo == true
	local canTeam = data.canTeam == true
	local soloPrice = tonumber(data.soloPrice) or 10
	local teamPrice = tonumber(data.teamPrice) or 50

	view.SoloReviveButton.Text = ("Solo Revive (%d R$)"):format(soloPrice)
	view.TeamReviveButton.Text = ("Team Revive (%d R$)"):format(teamPrice)
	view.SoloReviveButton.Visible = canSolo
	view.TeamReviveButton.Visible = canTeam
	view.ReviveButtonsFrame.Visible = canSolo or canTeam
end

function CombatHudController:GetShopkeeperRoot()
	local shopsFolder = self.workspace:FindFirstChild("Shops")
	local shopModel = shopsFolder and shopsFolder:FindFirstChild("WeaponShop")
	local npc = shopModel and shopModel:FindFirstChild("Shopkeeper")
	local root = npc and npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CombatHudController:XpForLevel(level)
	local progression = self.combatConfig.Progression
	return progression.BaseXpForLevel + math.max(0, level - 1) * progression.XpGrowthPerLevel
end

function CombatHudController:RefreshHealthHud()
	local safeMax = math.max(1, self.maxHealth)
	local ratio = math.clamp(self.currentHealth / safeMax, 0, 1)
	self.view.PlayerHealthFill.Size = UDim2.fromScale(ratio, 1)
	self.view.PlayerHealthLabel.Text = ("HP: %d / %d"):format(
		math.floor(self.currentHealth + 0.5),
		math.floor(safeMax + 0.5)
	)
end

function CombatHudController:RefreshXpHud()
	local needed = self:XpForLevel(self.currentLevel)
	local ratio = needed > 0 and math.clamp(self.currentXp / needed, 0, 1) or 0
	self.view.XpFill.Size = UDim2.fromScale(ratio, 1)
	self.view.XpLabel.Text = ("Lvl %d | XP %d/%d"):format(self.currentLevel, self.currentXp, needed)
end

function CombatHudController:RefreshSkillPointsBadge()
	local hasPoints = self.skillPoints > 0
	self.view.SkillPointsBadge.Visible = hasPoints
	self.view.SkillPointsBadgeLabel.Text = tostring(self.skillPoints)
	self.view.SkillPointsLabel.Text = ("Available points: %d"):format(self.skillPoints)
end

function CombatHudController:ClearSkillRows()
	for _, child in ipairs(self.view.SkillsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function CombatHudController:BuildSkillRow(item)
	local row = Instance.new("Frame")
	row.Name = "Skill_" .. tostring(item.key)
	row.Size = UDim2.new(1, -6, 0, 58)
	row.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	row.BorderSizePixel = 0
	row.Parent = self.view.SkillsList

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

	if item.level >= item.maxLevel then
		upgradeButton.Text = "Maxed"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
		upgradeButton.Active = false
	elseif self.skillPoints <= 0 then
		upgradeButton.Text = "No points"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
		upgradeButton.Active = false
	else
		upgradeButton.Text = "Upgrade +1"
		upgradeButton.BackgroundColor3 = Color3.fromRGB(70, 120, 78)
		upgradeButton.MouseButton1Click:Connect(function()
			self.skillEvent:FireServer("upgrade", item.key)
		end)
	end
end

function CombatHudController:RefreshSkillsUi(items, message)
	if items then
		self.skillStateItems = items
	end
	if message and message ~= "" then
		self.view.SkillsStatusLabel.Text = message
	end

	self:RefreshSkillPointsBadge()
	self:ClearSkillRows()
	for _, item in ipairs(self.skillStateItems) do
		self:BuildSkillRow(item)
	end
end

function CombatHudController:RefreshCombatHud()
	local _, weapon = self:GetCurrentWeapon()
	self.view.WeaponLabel.Text = ("Weapon: %s"):format(weapon and weapon.DisplayName or "None")

	if weapon and weapon.Category == "Ranged" then
		if (self.combatConfig.Ammo or {}).MagazinesEnabled then
			local suffix = self.weaponController and self.weaponController:IsReloading() and " (reloading)" or ""
			if self.ammoReserve < 0 then
				self.view.AmmoLabel.Text = ("Ammo: %d / INF%s"):format(self.ammoMag, suffix)
			else
				self.view.AmmoLabel.Text = ("Ammo: %d / %d%s"):format(self.ammoMag, self.ammoReserve, suffix)
			end
			self.view.ControlsLabel.Text = "LMB fire | RMB aim | R reload | E interact | B open shop"
		else
			self.view.ControlsLabel.Text = "LMB fire | RMB aim | E interact | B open shop"
		end
	elseif weapon and weapon.Category == "Melee" then
		self.view.AmmoLabel.Text = "Ammo: --"
		self.view.ControlsLabel.Text = "LMB melee attack | RMB camera lock | E interact | B open shop"
	else
		self.view.AmmoLabel.Text = "Ammo: --"
		self.view.ControlsLabel.Text = "Equip a weapon from Backpack | RMB camera lock | E interact | B open shop"
	end

	self.updateCrosshairVisibility()
end

function CombatHudController:RefreshMoneyLabel()
	local leaderstats = self.player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	self.view.MoneyLabel.Text = ("Money: %d$"):format(money and money.Value or 0)
end

function CombatHudController:RefreshXpFromStats()
	local leaderstats = self.player:FindFirstChild("leaderstats")
	if not leaderstats then
		self.currentXp = 0
		self.currentLevel = 1
		self:RefreshXpHud()
		return
	end

	local xp = leaderstats:FindFirstChild("XP")
	local level = leaderstats:FindFirstChild("Level")
	if xp and xp:IsA("IntValue") then
		self.currentXp = math.max(0, xp.Value)
	end
	if level and level:IsA("IntValue") then
		self.currentLevel = math.max(1, level.Value)
	end
	self:RefreshXpHud()
end

function CombatHudController:RefreshSkillPointsFromStats()
	local progression = self.player:FindFirstChild("Progression")
	local points = progression and progression:FindFirstChild("SkillPoints")
	self.skillPoints = points and points:IsA("IntValue") and math.max(0, points.Value) or 0
	self:RefreshSkillPointsBadge()
	if self.view.SkillsFrame.Visible then
		self:RefreshSkillsUi(nil, "")
	end
end

function CombatHudController:BindStatsListeners()
	disconnectAll(self.statsConnections)
	local leaderstats = self.player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Money")
	local xp = leaderstats:WaitForChild("XP")
	local level = leaderstats:WaitForChild("Level")
	local progression = self.player:WaitForChild("Progression")
	local skillPointsStat = progression:WaitForChild("SkillPoints")

	self:RefreshMoneyLabel()
	self:RefreshXpFromStats()
	self:RefreshSkillPointsFromStats()
	table.insert(self.statsConnections, money:GetPropertyChangedSignal("Value"):Connect(function()
		self:RefreshMoneyLabel()
	end))
	table.insert(self.statsConnections, xp:GetPropertyChangedSignal("Value"):Connect(function()
		self:RefreshXpFromStats()
	end))
	table.insert(self.statsConnections, level:GetPropertyChangedSignal("Value"):Connect(function()
		self:RefreshXpFromStats()
	end))
	table.insert(self.statsConnections, skillPointsStat:GetPropertyChangedSignal("Value"):Connect(function()
		self:RefreshSkillPointsFromStats()
	end))
end

function CombatHudController:BindHumanoid(humanoid)
	disconnectAll(self.humanoidConnections)
	local function update()
		self.currentHealth = math.max(0, humanoid.Health)
		self.maxHealth = math.max(1, humanoid.MaxHealth)
		self:RefreshHealthHud()
	end

	update()
	table.insert(self.humanoidConnections, humanoid.HealthChanged:Connect(update))
	table.insert(self.humanoidConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
end

function CombatHudController:ClearShopRows()
	for _, child in ipairs(self.view.ShopList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function CombatHudController:BuildShopRow(item)
	local row = Instance.new("Frame")
	row.Name = "Row_" .. tostring(item.key)
	row.Size = UDim2.new(1, -6, 0, 88)
	row.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	row.BorderSizePixel = 0
	row.Parent = self.view.ShopList

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
			self.shopEvent:FireServer("buyWeapon", item.key)
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
				self.shopEvent:FireServer("buyAmmo", item.key)
			end)
		else
			ammoButton.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
			ammoButton.Active = false
		end
	end
end

function CombatHudController:RefreshShopUi(items, message)
	if message and message ~= "" then
		self.view.ShopStatusLabel.Text = message
	end
	self:ClearShopRows()
	for _, item in ipairs(items or {}) do
		self:BuildShopRow(item)
	end
end

function CombatHudController:SetCurrentToolNameByCharacter(character)
	local foundToolName = ""
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				foundToolName = child.Name
				break
			end
		end
	end
	self.currentToolName = foundToolName
	self:RefreshCombatHud()
end

function CombatHudController:BindCharacter(character)
	disconnectAll(self.characterConnections)
	self:SetCurrentToolNameByCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		self:BindHumanoid(humanoid)
	end
	table.insert(self.characterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self.currentToolName = child.Name
			self:RefreshCombatHud()
		end
	end))
	table.insert(self.characterConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			self:SetCurrentToolNameByCharacter(character)
		end
	end))
	return humanoid
end

function CombatHudController:UnbindCharacter()
	disconnectAll(self.characterConnections)
	disconnectAll(self.humanoidConnections)
	self:HideReviveButtons()
end

function CombatHudController:HandleCombatState(data)
	if typeof(data) ~= "table" then
		return false
	end
	if typeof(data.mag) == "number" then
		self.ammoMag = math.max(0, math.floor(data.mag))
	end
	if typeof(data.reserve) == "number" then
		self.ammoReserve = math.max(0, math.floor(data.reserve))
	end
	if typeof(data.equippedToolName) == "string" then
		self.currentToolName = data.equippedToolName
	end
	if self.weaponController then
		self.weaponController:ApplyCombatState(data)
	end
	self:RefreshCombatHud()
	return true
end

function CombatHudController:HandleShopEvent(data)
	if typeof(data) ~= "table" then
		return false
	end
	if data.type == "close" then
		self.view.ShopFrame.Visible = false
		self.updateCrosshairVisibility()
		return true
	end

	self.setAimModeEnabled(false)
	if typeof(data.money) == "number" then
		self.view.MoneyLabel.Text = ("Money: %d$"):format(data.money)
	end
	self:RefreshShopUi(data.items or {}, data.message or "")
	self.view.ShopFrame.Visible = true
	return true
end

function CombatHudController:HandleSkillEvent(data)
	if typeof(data) ~= "table" then
		return false
	end
	self.setAimModeEnabled(false)
	if typeof(data.points) == "number" then
		self.skillPoints = math.max(0, math.floor(data.points))
	end
	self:RefreshSkillsUi(data.skills or self.skillStateItems, data.message or "")
	self.view.SkillsFrame.Visible = true
	return true
end

function CombatHudController:HandleSurvivalEvent(data)
	if typeof(data) ~= "table" then
		return false
	end
	local view = self.view
	if typeof(data.text) == "string" and data.text ~= "" then
		view.SurvivalStatusLabel.Text = data.text
	end

	if data.type == "respawn" then
		self.spectatorController:SetDowned(true)
		local seconds = tonumber(data.seconds) or 0
		view.RespawnStatusLabel.Visible = true
		if typeof(data.text) == "string" and data.text ~= "" then
			view.RespawnStatusLabel.Text = ("%s | Spectate: WASD + Space/Ctrl, hold RMB to look"):format(data.text)
		else
			view.RespawnStatusLabel.Text = ("Downed. Auto-respawn in %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
				:format(math.max(0, math.floor(seconds)))
		end
	elseif data.type == "wipe_timer" then
		self.spectatorController:SetDowned(true)
		local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
		view.RespawnStatusLabel.Visible = true
		view.RespawnStatusLabel.Text = ("Team wipe. Revive window: %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
			:format(seconds)
	elseif data.type == "revive_options" then
		self.spectatorController:SetDowned(true)
		self.setAimModeEnabled(false)
		self:ShowReviveButtons(data)
		if data.wipeOnly then
			local seconds = math.max(0, math.floor(tonumber(data.seconds) or 0))
			view.RespawnStatusLabel.Visible = true
			view.RespawnStatusLabel.Text = ("Team wipe. Buy revive in %ds | Spectate: WASD + Space/Ctrl, hold RMB to look")
				:format(seconds)
		end
	elseif data.type == "revive_options_clear" then
		self:HideReviveButtons()
	elseif data.type == "respawn_clear" then
		self.spectatorController:SetDowned(false)
		view.RespawnStatusLabel.Visible = false
		view.RespawnStatusLabel.Text = ""
		self:HideReviveButtons()
	elseif data.type == "match" and not self.spectatorController:IsDowned() then
		view.RespawnStatusLabel.Visible = false
		view.RespawnStatusLabel.Text = ""
		self:HideReviveButtons()
	end
	return true
end

function CombatHudController:OpenShop()
	self.shopEvent:FireServer("open")
end

function CombatHudController:OpenSkills()
	self.skillEvent:FireServer("open")
end

function CombatHudController:Start()
	if self.started then
		return
	end
	self.started = true
	local view = self.view

	table.insert(self.connections, view.CloseShopButton.MouseButton1Click:Connect(function()
		self.setAimModeEnabled(false)
		view.ShopFrame.Visible = false
	end))
	table.insert(self.connections, view.OpenSkillsButton.MouseButton1Click:Connect(function()
		self.setAimModeEnabled(false)
		self:OpenSkills()
	end))
	table.insert(self.connections, view.CloseSkillsButton.MouseButton1Click:Connect(function()
		self.setAimModeEnabled(false)
		view.SkillsFrame.Visible = false
	end))
	table.insert(self.connections, view.SoloReviveButton.MouseButton1Click:Connect(function()
		self.revivePurchaseEvent:FireServer("request_solo")
	end))
	table.insert(self.connections, view.TeamReviveButton.MouseButton1Click:Connect(function()
		self.revivePurchaseEvent:FireServer("request_team")
	end))
	table.insert(self.connections, self.combatStateEvent.OnClientEvent:Connect(function(data)
		self:HandleCombatState(data)
	end))
	table.insert(self.connections, self.shopEvent.OnClientEvent:Connect(function(data)
		self:HandleShopEvent(data)
	end))
	table.insert(self.connections, self.skillEvent.OnClientEvent:Connect(function(data)
		self:HandleSkillEvent(data)
	end))
	table.insert(self.connections, self.survivalEvent.OnClientEvent:Connect(function(data)
		self:HandleSurvivalEvent(data)
	end))

	task.spawn(function()
		self:BindStatsListeners()
	end)
	self:RefreshCombatHud()
	self:RefreshHealthHud()
	self:RefreshXpHud()
	self:RefreshSkillPointsBadge()
	self:HideReviveButtons()
end

function CombatHudController:Update()
	if not self.view.ShopFrame.Visible then
		return
	end
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shopRoot = self:GetShopkeeperRoot()
	if not root or not root:IsA("BasePart") or not shopRoot then
		self.view.ShopFrame.Visible = false
		self.updateCrosshairVisibility()
		return
	end
	if (root.Position - shopRoot.Position).Magnitude > SHOP_AUTO_CLOSE_DISTANCE then
		self.view.ShopFrame.Visible = false
		self.view.ShopStatusLabel.Text = "You moved away from the shop."
		self.updateCrosshairVisibility()
	end
end

function CombatHudController:Destroy()
	disconnectAll(self.connections)
	disconnectAll(self.characterConnections)
	disconnectAll(self.humanoidConnections)
	disconnectAll(self.statsConnections)
	self.started = false
end

return CombatHudController
