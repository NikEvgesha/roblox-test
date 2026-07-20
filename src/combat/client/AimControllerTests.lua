local AimController = require(script.Parent:WaitForChild("AimController"))

local AimControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local function expectNear(actual, expected, epsilon, label)
	if math.abs(actual - expected) > epsilon then
		error(("%s: expected %.4f, got %.4f"):format(label, expected, actual), 2)
	end
end

local function createEnemy(name, position, health)
	local model = Instance.new("Model")
	model.Name = name
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = health
	humanoid.Parent = model
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = model
	return model, humanoid, root
end

function AimControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, label)
		expectNear(actual, expected, 0.001, label)
		assertions += 1
	end

	local zombies = Instance.new("Folder")
	zombies.Name = "Zombies"
	local nearEnemy, nearHumanoid, nearRoot = createEnemy("Near", Vector3.new(4, 0, 0), 100)
	nearEnemy.Parent = zombies
	local farEnemy, _, farRoot = createEnemy("Far", Vector3.new(8, 0, 0), 100)
	farEnemy.Parent = zombies
	local deadEnemy = createEnemy("Dead", Vector3.new(1, 0, 0), 0)
	deadEnemy.Parent = zombies

	local camera = {
		CameraType = Enum.CameraType.Custom,
		CFrame = CFrame.lookAt(Vector3.new(0, 4, 10), Vector3.new(0, 4, 0)),
	}
	local raycastPosition = Vector3.new(2, 3, -40)
	local workspaceService = { CurrentCamera = camera }
	function workspaceService:FindFirstChild(name)
		return name == "Zombies" and zombies or nil
	end
	function workspaceService:Raycast()
		return { Position = raycastPosition }
	end

	local inputService = {
		MouseBehavior = Enum.MouseBehavior.Default,
		MouseIconEnabled = true,
		rightPressed = true,
	}
	function inputService:IsMouseButtonPressed()
		return self.rightPressed
	end
	local mouse = {
		X = 120,
		Y = 240,
		Icon = "rbxasset://SystemCursors/Arrow",
		UnitRay = Ray.new(Vector3.new(0, 3, 0), Vector3.new(0, 0, -1)),
	}
	local crosshair = { Visible = false, Position = UDim2.fromScale(0.5, 0.5) }
	local hitMarker = { Position = UDim2.fromScale(0.5, 0.5) }
	local spectatorEnabled = false
	local spectator = {}
	function spectator:IsEnabled()
		return spectatorEnabled
	end
	local blockingUi = false
	local weaponKey = "Rifle"
	local weapon = { Category = "Ranged", Range = 100 }
	local player = { Character = nil }
	local controller = AimController.new({
		player = player,
		workspace = workspaceService,
		userInputService = inputService,
		mouse = mouse,
		crosshairFrame = crosshair,
		hitMarkerFrame = hitMarker,
		spectatorController = spectator,
		getCurrentWeapon = function()
			return weaponKey, weapon
		end,
		hasBlockingUiOpen = function()
			return blockingUi
		end,
	})

	equal(controller:IsAimModeEnabled(), false, "aim starts disabled")
	controller:UpdateCrosshairVisibility()
	equal(crosshair.Visible, true, "ranged weapon shows crosshair")
	controller:SetAimModeEnabled(true)
	equal(controller:IsAimModeEnabled(), true, "aim enables")
	equal(inputService.MouseBehavior, Enum.MouseBehavior.Default, "aim keeps free cursor")

	blockingUi = true
	controller:SetAimModeEnabled(true)
	equal(controller:IsAimModeEnabled(), false, "blocking UI rejects aim")
	equal(crosshair.Visible, false, "blocking UI hides crosshair")
	blockingUi = false
	controller:SetAimModeEnabled(true)

	equal(controller:FindNearestEnemyRoot(Vector3.zero, 10), nearRoot, "nearest living enemy selected")
	nearHumanoid.Health = 0
	equal(controller:FindNearestEnemyRoot(Vector3.zero, 10), farRoot, "dead nearest enemy ignored")
	nearHumanoid.Health = 100
	equal(controller:FindNearestEnemyRoot(Vector3.zero, 3), nil, "distance limit respected")

	local character = Instance.new("Model")
	local characterRoot = Instance.new("Part")
	characterRoot.Name = "HumanoidRootPart"
	characterRoot.Position = Vector3.zero
	characterRoot.Parent = character
	local targetPosition, lockDirection, lockOrigin = controller:ResolveRangedAimData(
		camera,
		character,
		characterRoot,
		weapon
	)
	equal(targetPosition, nearRoot.Position + Vector3.new(0, 1.2, 0), "aim mode locks enemy center")
	equal(lockOrigin, camera.CFrame.Position, "lock ray starts at camera")
	near(lockDirection.Magnitude, 1, "lock direction normalized")

	controller:SetAimModeEnabled(false)
	local rayTarget, rayDirection, rayOrigin = controller:ResolveRangedAimData(camera, character, characterRoot, weapon)
	equal(rayTarget, raycastPosition, "cursor ray uses raycast hit")
	equal(rayOrigin, mouse.UnitRay.Origin, "cursor ray preserves UnitRay origin")
	equal(rayDirection, mouse.UnitRay.Direction.Unit, "cursor ray preserves UnitRay direction")

	controller:Update(0.016)
	equal(crosshair.Position, UDim2.fromOffset(120, 240), "crosshair follows cursor")
	equal(hitMarker.Position, crosshair.Position, "hit marker follows crosshair")
	equal(inputService.MouseIconEnabled, false, "ranged cursor icon hidden")
	equal(mouse.Icon, "", "ranged mouse icon cleared")

	weaponKey = nil
	weapon = nil
	controller:Update(0.016)
	equal(crosshair.Visible, false, "missing weapon hides crosshair")
	equal(inputService.MouseIconEnabled, true, "missing weapon restores cursor")
	equal(mouse.Icon, "rbxasset://SystemCursors/Arrow", "arrow cursor restored")

	weaponKey = "Rifle"
	weapon = { Category = "Ranged", Range = 100 }
	controller:SetAimModeEnabled(true)
	inputService.rightPressed = false
	controller:ReconcileRightMouse()
	equal(controller:IsAimModeEnabled(), false, "released RMB clears aim")
	inputService.rightPressed = true
	controller:SetAimModeEnabled(true)
	blockingUi = true
	controller:ReconcileBlockingUi()
	equal(controller:IsAimModeEnabled(), false, "opened UI clears aim")

	blockingUi = false
	spectatorEnabled = true
	controller:UpdateCrosshairVisibility()
	equal(crosshair.Visible, false, "spectator hides crosshair")
	controller:ApplyShotRecoil({ Category = "Ranged" })
	equal(camera.CameraType, Enum.CameraType.Custom, "neutral recoil keeps camera type")

	character:Destroy()
	zombies:Destroy()
	return assertions
end

return AimControllerTests
