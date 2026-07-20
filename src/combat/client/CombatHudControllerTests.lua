local CombatHudController = require(script.Parent:WaitForChild("CombatHudController"))
local CombatHudView = require(script.Parent:WaitForChild("CombatHudView"))

local CombatHudControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function CombatHudControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local root = Instance.new("Folder")
	local player = Instance.new("Folder")
	player.Name = "Player"
	local config = {
		Ammo = { MagazinesEnabled = true },
		Progression = { BaseXpForLevel = 100, XpGrowthPerLevel = 25 },
		Weapons = {
			Pistol = { ToolName = "Pistol", DisplayName = "Test Pistol", Category = "Ranged" },
			Sword = { ToolName = "Sword", DisplayName = "Test Sword", Category = "Melee" },
		},
	}
	local view = CombatHudView.new({ playerGui = root, combatConfig = config })
	local fakeEvent = { calls = {} }
	function fakeEvent:FireServer(...)
		table.insert(self.calls, { ... })
	end
	local downed = false
	local spectator = {}
	function spectator:SetDowned(value)
		downed = value
	end
	function spectator:IsDowned()
		return downed
	end
	local aimEnabled
	local crosshairUpdates = 0
	local appliedCombatState
	local weaponController = {}
	function weaponController:IsReloading()
		return false
	end
	function weaponController:ApplyCombatState(data)
		appliedCombatState = data
	end

	local controller = CombatHudController.new({
		player = player,
		workspace = workspace,
		combatConfig = config,
		view = view,
		combatStateEvent = fakeEvent,
		shopEvent = fakeEvent,
		skillEvent = fakeEvent,
		survivalEvent = fakeEvent,
		revivePurchaseEvent = fakeEvent,
		spectatorController = spectator,
		weaponController = weaponController,
		setAimModeEnabled = function(value)
			aimEnabled = value
		end,
		updateCrosshairVisibility = function()
			crosshairUpdates += 1
		end,
	})

	equal(controller:XpForLevel(1), 100, "level one XP")
	equal(controller:XpForLevel(3), 150, "XP growth")
	equal(controller:HasBlockingUiOpen(), false, "UI initially unblocked")
	equal(controller:HandleCombatState("bad"), false, "invalid combat state rejected")
	local state = { equippedToolName = "Pistol", mag = 7, reserve = 21 }
	equal(controller:HandleCombatState(state), true, "combat state accepted")
	equal(appliedCombatState, state, "combat state forwarded")
	equal(select(1, controller:GetCurrentWeapon()), "Pistol", "current weapon resolved")
	equal(view.WeaponLabel.Text, "Weapon: Test Pistol", "weapon label updated")
	equal(view.AmmoLabel.Text, "Ammo: 7 / 21", "ammo label updated")
	equal(crosshairUpdates, 1, "crosshair refreshed")

	equal(controller:HandleShopEvent({
		money = 42,
		message = "Shop ready",
		items = {
			{ key = "Pistol", displayName = "Test Pistol", category = "Ranged", price = 10, owned = false },
		},
	}), true, "shop event accepted")
	equal(view.ShopFrame.Visible, true, "shop opened")
	equal(view.MoneyLabel.Text, "Money: 42$", "shop money updated")
	equal(view.ShopStatusLabel.Text, "Shop ready", "shop status updated")
	equal(view.ShopList:FindFirstChild("Row_Pistol") ~= nil, true, "shop row built")
	equal(controller:HasBlockingUiOpen(), true, "shop blocks combat")
	equal(aimEnabled, false, "shop disables aim")
	controller:HandleShopEvent({ type = "close" })
	equal(view.ShopFrame.Visible, false, "shop close handled")

	equal(controller:HandleSkillEvent({
		points = 2,
		message = "Choose an upgrade",
		skills = {
			{ key = "Damage", displayName = "Damage", level = 1, maxLevel = 20 },
		},
	}), true, "skill event accepted")
	equal(view.SkillsFrame.Visible, true, "skills opened")
	equal(view.SkillPointsBadge.Visible, true, "skill badge visible")
	equal(view.SkillPointsBadgeLabel.Text, "2", "skill badge count")
	equal(view.SkillsList:FindFirstChild("Skill_Damage") ~= nil, true, "skill row built")
	view.SkillsFrame.Visible = false

	controller:HandleSurvivalEvent({
		type = "revive_options",
		canSolo = true,
		canTeam = false,
		soloPrice = 10,
	})
	equal(downed, true, "revive options enter spectator state")
	equal(controller:IsReviveUiVisible(), true, "revive UI visible")
	equal(view.SoloReviveButton.Text, "Solo Revive (10 R$)", "solo revive price")
	equal(view.TeamReviveButton.Visible, false, "unavailable team revive hidden")
	equal(controller:HasBlockingUiOpen(), true, "revive UI blocks combat")
	controller:HandleSurvivalEvent({ type = "respawn_clear" })
	equal(downed, false, "respawn exits spectator state")
	equal(controller:IsReviveUiVisible(), false, "respawn hides revive UI")

	controller.currentHealth = 35
	controller.maxHealth = 70
	controller:RefreshHealthHud()
	equal(view.PlayerHealthFill.Size, UDim2.fromScale(0.5, 1), "health fill ratio")
	equal(view.PlayerHealthLabel.Text, "HP: 35 / 70", "health text")
	controller.currentLevel = 2
	controller.currentXp = 50
	controller:RefreshXpHud()
	equal(view.XpFill.Size, UDim2.fromScale(0.4, 1), "XP fill ratio")
	equal(view.XpLabel.Text, "Lvl 2 | XP 50/125", "XP text")

	controller:Destroy()
	view.Gui:Destroy()
	player:Destroy()
	root:Destroy()
	return assertions
end

return CombatHudControllerTests
