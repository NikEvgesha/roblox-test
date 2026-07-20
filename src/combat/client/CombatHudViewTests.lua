local CombatHudView = require(script.Parent:WaitForChild("CombatHudView"))

local CombatHudViewTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function CombatHudViewTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local root = Instance.new("Folder")
	root.Name = "CombatHudViewTests"
	local unlimited = CombatHudView.new({
		playerGui = root,
		combatConfig = { Ammo = { MagazinesEnabled = false } },
	})
	equal(unlimited.Gui.Name, "MainHudGui", "screen GUI name")
	equal(unlimited.Gui.Parent, root, "screen GUI parent")
	equal(unlimited.AmmoLabel.Visible, false, "unlimited ammo label hidden")
	equal(unlimited.WeaponLabel.Position, UDim2.fromOffset(18, 58), "unlimited weapon label position")
	equal(unlimited.ControlsLabel.Position, UDim2.fromOffset(18, 91), "unlimited controls position")
	equal(unlimited.CrosshairFrame.Name, "Crosshair", "crosshair created")
	equal(unlimited.CrosshairFrame.Visible, false, "crosshair starts hidden")
	equal(unlimited.ShopFrame.Visible, false, "shop starts closed")
	equal(unlimited.SkillsFrame.Visible, false, "skills start closed")
	equal(unlimited.ReviveButtonsFrame.Visible, false, "revive controls start hidden")
	equal(unlimited.ShopList:FindFirstChildOfClass("UIListLayout") ~= nil, true, "shop layout parented")
	equal(unlimited.SkillsList:FindFirstChildOfClass("UIListLayout") ~= nil, true, "skills layout parented")
	equal(unlimited.PlayerHealthFill.Parent ~= nil, true, "health fill created")
	equal(unlimited.XpFill.Parent ~= nil, true, "XP fill created")
	equal(unlimited.SoloReviveButton.Parent, unlimited.ReviveButtonsFrame, "solo revive button parent")
	equal(unlimited.TeamReviveButton.Parent, unlimited.ReviveButtonsFrame, "team revive button parent")

	local magazines = CombatHudView.new({
		playerGui = root,
		combatConfig = { Ammo = { MagazinesEnabled = true } },
	})
	equal(magazines.AmmoLabel.Visible, true, "magazine ammo label visible")
	equal(magazines.WeaponLabel.Position, UDim2.fromOffset(18, 95), "magazine weapon label position")
	equal(magazines.ControlsLabel.Position, UDim2.fromOffset(18, 128), "magazine controls position")

	unlimited.Gui:Destroy()
	magazines.Gui:Destroy()
	root:Destroy()
	return assertions
end

return CombatHudViewTests
