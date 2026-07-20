local WeaponController = require(script.Parent:WaitForChild("WeaponController"))

local WeaponControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function WeaponControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local now = 10
	local canAct = true
	local rangedShots = 0
	local meleeSwings = 0
	local reloadAnimations = 0
	local sent = {}
	local currentKey = "Rifle"
	local currentWeapon = { Category = "Ranged", FireCooldown = 0.2 }
	local actionEvent = {}
	function actionEvent:FireServer(action, payload)
		table.insert(sent, { action = action, payload = payload })
	end

	local controller = WeaponController.new({
		player = {},
		workspace = {},
		combatConfig = { Ammo = { MagazinesEnabled = true } },
		combatActionEvent = actionEvent,
		getCurrentWeapon = function()
			return currentKey, currentWeapon
		end,
		resolveRangedAimData = function() end,
		findNearestEnemyRoot = function() end,
		canAct = function()
			return canAct
		end,
		clock = function()
			return now
		end,
		fireRanged = function()
			rangedShots += 1
			return true
		end,
		fireMelee = function()
			meleeSwings += 1
			return true
		end,
		playReloadAnimation = function()
			reloadAnimations += 1
		end,
	})

	equal(controller:IsReloading(), false, "starts ready")
	equal(controller:IsPrimaryHeld(), false, "primary starts released")
	equal(controller:HandlePrimaryDown(), true, "initial ranged shot")
	equal(controller:IsPrimaryHeld(), true, "primary becomes held")
	equal(rangedShots, 1, "initial shot count")
	now = 10.16
	equal(controller:Update(), false, "initial cadence blocks early shot")
	equal(rangedShots, 1, "early update does not fire")
	now = 10.17
	equal(controller:Update(), true, "automatic shot at cadence")
	equal(rangedShots, 2, "automatic shot count")

	controller:ApplyCombatState({ fireRateMultiplier = 2 })
	equal(controller:GetFireRateMultiplier(), 2, "fire-rate state applied")
	now = 10.339
	equal(controller:Update(), false, "scheduled cadence still blocks early shot")
	now = 10.34
	equal(controller:Update(), true, "scheduled shot fires")
	equal(rangedShots, 3, "scheduled shot count")
	now = 10.424
	equal(controller:Update(), false, "multiplied cadence blocks early shot")
	now = 10.425
	equal(controller:Update(), true, "multiplied cadence fires")
	equal(rangedShots, 4, "multiplied shot count")

	equal(controller:ApplyCombatState({ reloading = true }), true, "reload transition detected")
	equal(controller:IsReloading(), true, "reload state stored")
	equal(reloadAnimations, 1, "server reload transition animates")
	now = 11
	equal(controller:Update(), false, "reload blocks automatic fire")
	controller:ApplyCombatState({ reloading = false })
	equal(controller:IsReloading(), false, "reload completion stored")
	equal(controller:RequestReload(), true, "manual reload request")
	equal(sent[1].action, "reload", "reload action sent")
	equal(reloadAnimations, 2, "manual reload animates")

	controller:HandlePrimaryUp()
	equal(controller:IsPrimaryHeld(), false, "primary release stored")
	currentKey = "Sword"
	currentWeapon = { Category = "Melee", Cooldown = 0.75 }
	equal(controller:HandlePrimaryDown(), true, "melee dispatch")
	equal(meleeSwings, 1, "melee swing count")
	equal(controller:Update(), false, "melee does not auto-repeat")
	controller:HandlePrimaryUp()

	canAct = false
	currentKey = "Rifle"
	currentWeapon = { Category = "Ranged", FireCooldown = 0.2 }
	equal(controller:HandlePrimaryDown(), false, "blocking state rejects primary")
	equal(rangedShots, 4, "blocked primary does not fire")
	equal(controller:RequestReload(), false, "blocking state rejects reload")

	return assertions
end

return WeaponControllerTests
