local CombatInputController = require(script.Parent:WaitForChild("CombatInputController"))

local CombatInputControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function CombatInputControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local spectatorEnabled = false
	local spectatorBegan = 0
	local spectatorEnded = 0
	local primaryDown = 0
	local primaryUp = 0
	local reloadRequests = 0
	local aimChanges = {}
	local shopOpens = 0
	local skillOpens = 0
	local reviveVisible = false
	local blockingUi = false
	local spectator = {}
	function spectator:IsEnabled()
		return spectatorEnabled
	end
	function spectator:HandleInputBegan()
		spectatorBegan += 1
	end
	function spectator:HandleInputEnded()
		spectatorEnded += 1
	end
	local weapon = {}
	function weapon:HandlePrimaryDown()
		primaryDown += 1
		return true
	end
	function weapon:HandlePrimaryUp()
		primaryUp += 1
	end
	function weapon:RequestReload()
		reloadRequests += 1
		return true
	end

	local controller = CombatInputController.new({
		mouse = {},
		userInputService = {},
		spectatorController = spectator,
		weaponController = weapon,
		setAimEnabled = function(enabled)
			table.insert(aimChanges, enabled)
		end,
		isReviveUiVisible = function()
			return reviveVisible
		end,
		hasBlockingUiOpen = function()
			return blockingUi
		end,
		openShop = function()
			shopOpens += 1
		end,
		openSkills = function()
			skillOpens += 1
		end,
	})

	equal(controller:HandlePrimaryDown(), true, "primary down forwarded")
	controller:HandlePrimaryUp()
	equal(primaryDown, 1, "primary down count")
	equal(primaryUp, 1, "primary up count")

	local rmb = { UserInputType = Enum.UserInputType.MouseButton2, KeyCode = Enum.KeyCode.Unknown }
	equal(controller:HandleInputBegan(rmb, false), true, "RMB began consumed")
	equal(aimChanges[1], true, "RMB enables aim")
	equal(controller:HandleInputEnded(rmb), true, "RMB ended consumed")
	equal(aimChanges[2], false, "RMB release disables aim")

	local b = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.B }
	local k = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }
	local r = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.R }
	equal(controller:HandleInputBegan(b, false), true, "shop input consumed")
	equal(shopOpens, 1, "shop opened")
	equal(aimChanges[3], false, "shop clears aim")
	equal(controller:HandleInputBegan(k, false), true, "skills input consumed")
	equal(skillOpens, 1, "skills opened")
	equal(controller:HandleInputBegan(r, false), true, "reload input consumed")
	equal(reloadRequests, 1, "reload forwarded")

	blockingUi = true
	equal(controller:HandleInputBegan(r, false), false, "blocking UI rejects reload")
	equal(reloadRequests, 1, "blocked reload not forwarded")
	blockingUi = false
	reviveVisible = true
	equal(controller:HandleInputBegan(b, false), false, "revive UI blocks shortcuts")
	equal(shopOpens, 1, "revive UI keeps shop closed")
	reviveVisible = false
	equal(controller:HandleInputBegan(b, true), false, "processed input ignored")
	equal(shopOpens, 1, "processed input keeps shop closed")

	spectatorEnabled = true
	equal(controller:HandleInputBegan(r, false), true, "spectator input consumed")
	equal(spectatorBegan, 1, "spectator began forwarded")
	equal(controller:HandleInputEnded(r), true, "spectator ended consumed")
	equal(spectatorEnded, 1, "spectator ended forwarded")
	equal(reloadRequests, 1, "spectator cannot reload")

	return assertions
end

return CombatInputControllerTests
