local CombatFeedbackController = require(script.Parent:WaitForChild("CombatFeedbackController"))

local CombatFeedbackControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function CombatFeedbackControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local root = Instance.new("Folder")
	root.Name = "CombatFeedbackControllerTests"
	local gui = Instance.new("ScreenGui")
	gui.Parent = root
	local soundRoot = Instance.new("Folder")
	soundRoot.Parent = root
	local camera = {}
	function camera:WorldToViewportPoint()
		return Vector3.new(320, 180, 10), true
	end
	local workspaceService = { CurrentCamera = camera }
	local controller = CombatFeedbackController.new({
		workspace = workspaceService,
		gui = gui,
		soundService = soundRoot,
		damageNumberLifetime = 0.1,
	})

	local marker = controller:GetHitMarkerFrame()
	equal(marker.Name, "HitMarker", "marker created")
	equal(marker.Visible, false, "marker starts hidden")
	equal(controller:Handle({ type = "other" }), false, "non-hit ignored")
	equal(controller:Handle({
		type = "hit",
		damage = 25.9,
		hitCount = 3,
		category = "Ranged",
		worldPosition = Vector3.new(1, 2, 3),
	}), true, "hit handled")
	equal(marker.Visible, true, "hit shows marker")
	equal(marker.LineA.BackgroundColor3, Color3.fromRGB(255, 208, 140), "multi-hit marker color")
	equal(marker.LineB.BackgroundColor3, Color3.fromRGB(255, 208, 140), "both marker lines colored")

	local damageLabel = controller.combatFxLayer:FindFirstChild("DamageNumber")
	equal(damageLabel ~= nil, true, "damage number created")
	equal(damageLabel.Text, "-25 x3", "damage number text")
	controller:Update(0.05)
	equal(marker.Visible, true, "marker remains during lifetime")
	equal(damageLabel.Visible, true, "on-screen damage number visible")
	equal(damageLabel.Position, UDim2.fromOffset(320, 180), "damage number projected")
	controller:Update(0.07)
	equal(marker.Visible, false, "marker expires")
	equal(controller.combatFxLayer:FindFirstChild("DamageNumber"), nil, "damage number expires")

	equal(controller:SpawnDamageNumber("invalid", 1, 1, false), false, "invalid world position rejected")
	controller:ShowHitMarker(1)
	equal(marker.LineA.BackgroundColor3, Color3.fromRGB(255, 240, 196), "single-hit marker color")
	local fxLayer = controller.combatFxLayer
	local sound = controller.hitConfirmSound
	controller:Destroy()
	equal(fxLayer.Parent, nil, "feedback layer destroyed")
	equal(sound.Parent, nil, "feedback sound destroyed")

	root:Destroy()
	return assertions
end

return CombatFeedbackControllerTests
