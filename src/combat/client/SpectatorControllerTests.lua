local SpectatorController = require(script.Parent:WaitForChild("SpectatorController"))

local SpectatorControllerTests = {}

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

function SpectatorControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, label)
		expectNear(actual, expected, 0.001, label)
		assertions += 1
	end

	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local player = { Character = character }
	local camera = {
		CameraType = Enum.CameraType.Custom,
		CameraSubject = nil,
		CFrame = CFrame.lookAt(Vector3.new(4, 10, 12), Vector3.new(4, 10, 11)),
	}
	local workspaceService = { CurrentCamera = camera }
	local inputService = {
		MouseBehavior = Enum.MouseBehavior.Default,
		MouseIconEnabled = true,
		mousePressed = true,
		mouseDelta = Vector2.zero,
	}
	function inputService:IsMouseButtonPressed()
		return self.mousePressed
	end
	function inputService:GetMouseDelta()
		return self.mouseDelta
	end
	local mouse = { Icon = "rbxasset://SystemCursors/Arrow" }
	local modeChanges = {}
	local controller = SpectatorController.new({
		player = player,
		workspace = workspaceService,
		userInputService = inputService,
		mouse = mouse,
		onModeChanged = function(enabled)
			table.insert(modeChanges, enabled)
		end,
	})

	equal(controller:IsEnabled(), false, "starts outside spectator")
	equal(controller:IsDowned(), false, "starts alive")
	controller:SetDowned(true)
	equal(controller:IsEnabled(), true, "downed enables spectator")
	equal(controller:IsDowned(), true, "downed state stored")
	equal(camera.CameraType, Enum.CameraType.Scriptable, "camera becomes scriptable")
	equal(modeChanges[1], true, "enable callback")

	local rmb = { UserInputType = Enum.UserInputType.MouseButton2, KeyCode = Enum.KeyCode.Unknown }
	equal(controller:HandleInputBegan(rmb), true, "RMB is consumed")
	equal(controller:IsLookActive(), true, "RMB enables look")
	equal(inputService.MouseBehavior, Enum.MouseBehavior.LockCurrentPosition, "look locks current cursor position")
	equal(inputService.MouseIconEnabled, false, "look hides cursor")
	controller:HandleInputEnded(rmb)
	equal(controller:IsLookActive(), false, "RMB release disables look")
	equal(inputService.MouseBehavior, Enum.MouseBehavior.Default, "RMB release restores cursor")

	local forward = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.W }
	equal(controller:HandleInputBegan(forward), true, "forward input is consumed")
	controller:Update(1)
	near(camera.CFrame.Position.X, 4, "forward keeps X")
	near(camera.CFrame.Position.Y, 10, "forward keeps Y")
	near(camera.CFrame.Position.Z, -24, "forward follows camera look")
	controller:HandleInputEnded(forward)

	local unknown = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q }
	equal(controller:HandleInputBegan(unknown), false, "unmapped input is not consumed")
	controller:SetDowned(false)
	equal(controller:IsEnabled(), false, "revive disables spectator")
	equal(controller:IsDowned(), false, "revive clears downed state")
	equal(camera.CameraType, Enum.CameraType.Custom, "gameplay camera restored")
	equal(camera.CameraSubject, humanoid, "camera follows humanoid")
	equal(modeChanges[2], false, "disable callback")

	character:Destroy()
	return assertions
end

return SpectatorControllerTests
