local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SpectatorController = require(script.Parent:WaitForChild("SpectatorController"))
local WeaponController = require(script.Parent:WaitForChild("WeaponController"))
local CombatInputController = require(script.Parent:WaitForChild("CombatInputController"))
local AimController = require(script.Parent:WaitForChild("AimController"))
local CombatHudView = require(script.Parent:WaitForChild("CombatHudView"))
local CombatHudController = require(script.Parent:WaitForChild("CombatHudController"))
local CombatFeedbackController = require(script.Parent:WaitForChild("CombatFeedbackController"))
local WeaponAnimationController = require(script.Parent:WaitForChild("WeaponAnimationController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local combatActionEvent = ReplicatedStorage:WaitForChild("CombatAction")
local combatStateEvent = ReplicatedStorage:WaitForChild("CombatState")
local combatFeedbackEvent = ReplicatedStorage:WaitForChild("CombatFeedback")
local shopEvent = ReplicatedStorage:WaitForChild("ShopEvent")
local skillEvent = ReplicatedStorage:WaitForChild("SkillEvent")
local survivalEvent = ReplicatedStorage:WaitForChild("SurvivalEvent")
local revivePurchaseEvent = ReplicatedStorage:WaitForChild("RevivePurchaseEvent")
local mouse = player:GetMouse()

local hudView = CombatHudView.new({
	playerGui = playerGui,
	combatConfig = combatConfig,
})
local feedbackController = CombatFeedbackController.new({
	workspace = Workspace,
	gui = hudView.Gui,
	soundService = SoundService,
})

local aimController
local spectatorController = SpectatorController.new({
	player = player,
	workspace = Workspace,
	userInputService = UserInputService,
	mouse = mouse,
	onModeChanged = function(enabled)
		if not aimController then
			return
		end
		if enabled then
			aimController:SetAimModeEnabled(false)
		else
			aimController:UpdateCrosshairVisibility()
		end
	end,
})

local hudController = CombatHudController.new({
	player = player,
	workspace = Workspace,
	combatConfig = combatConfig,
	view = hudView,
	combatStateEvent = combatStateEvent,
	shopEvent = shopEvent,
	skillEvent = skillEvent,
	survivalEvent = survivalEvent,
	revivePurchaseEvent = revivePurchaseEvent,
	spectatorController = spectatorController,
})

aimController = AimController.new({
	player = player,
	workspace = Workspace,
	userInputService = UserInputService,
	mouse = mouse,
	crosshairFrame = hudView.CrosshairFrame,
	hitMarkerFrame = feedbackController:GetHitMarkerFrame(),
	spectatorController = spectatorController,
	getCurrentWeapon = function()
		return hudController:GetCurrentWeapon()
	end,
	hasBlockingUiOpen = function()
		return hudController:HasBlockingUiOpen()
	end,
	meleeLockDistance = 8,
})
hudController:SetAimCallbacks(function(enabled)
	aimController:SetAimModeEnabled(enabled)
end, function()
	aimController:UpdateCrosshairVisibility()
end)

local animationController = WeaponAnimationController.new({
	player = player,
	combatConfig = combatConfig,
})
local weaponController = WeaponController.new({
	player = player,
	workspace = Workspace,
	combatConfig = combatConfig,
	combatActionEvent = combatActionEvent,
	getCurrentWeapon = function()
		return hudController:GetCurrentWeapon()
	end,
	resolveRangedAimData = function(...)
		return aimController:ResolveRangedAimData(...)
	end,
	findNearestEnemyRoot = function(...)
		return aimController:FindNearestEnemyRoot(...)
	end,
	playFireAnimation = function(...)
		return animationController:PlayFire(...)
	end,
	playReloadAnimation = function(...)
		return animationController:PlayReload(...)
	end,
	applyShotRecoil = function(weapon)
		aimController:ApplyShotRecoil(weapon)
	end,
	meleeLockDistance = 8,
	canAct = function()
		return not spectatorController:IsEnabled() and not hudController:HasBlockingUiOpen()
	end,
})
hudController:SetWeaponController(weaponController)

local inputController = CombatInputController.new({
	mouse = mouse,
	userInputService = UserInputService,
	spectatorController = spectatorController,
	weaponController = weaponController,
	setAimEnabled = function(enabled)
		aimController:SetAimModeEnabled(enabled)
	end,
	isReviveUiVisible = function()
		return hudController:IsReviveUiVisible()
	end,
	hasBlockingUiOpen = function()
		return hudController:HasBlockingUiOpen()
	end,
	openShop = function()
		hudController:OpenShop()
	end,
	openSkills = function()
		hudController:OpenSkills()
	end,
})

local function bindCharacter(character)
	spectatorController:SetDowned(false)
	animationController:ClearCharacter(character)
	aimController:BindCharacter(character)
	local humanoid = hudController:BindCharacter(character)
	if humanoid then
		spectatorController:RestoreGameplayCamera()
	end
end

inputController:Start()
hudController:Start()
combatFeedbackEvent.OnClientEvent:Connect(function(data)
	feedbackController:Handle(data)
end)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(character)
	animationController:ClearCharacter(character)
	aimController:UnbindCharacter(character)
	hudController:UnbindCharacter()
	weaponController:HandlePrimaryUp()
end)

RunService.RenderStepped:Connect(function(deltaTime)
	feedbackController:Update(deltaTime)
	aimController:Update(deltaTime)
	weaponController:Update()
	aimController:ReconcileRightMouse()
	spectatorController:Update(deltaTime)
	aimController:ReconcileBlockingUi()
	hudController:Update()
end)
