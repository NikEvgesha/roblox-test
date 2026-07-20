local WeaponAnimationController = require(script.Parent:WaitForChild("WeaponAnimationController"))

local WeaponAnimationControllerTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function WeaponAnimationControllerTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local player = { Character = character }
	local loadCount = 0
	local pendingDelay
	local track = {
		IsPlaying = false,
		Length = 0.9,
		playCount = 0,
		stopCount = 0,
		adjustedSpeed = 0,
	}
	function track:Play(_, _, speed)
		self.IsPlaying = true
		self.playCount += 1
		self.adjustedSpeed = speed
	end
	function track:AdjustSpeed(speed)
		self.adjustedSpeed = speed
	end
	function track:Stop()
		self.IsPlaying = false
		self.stopCount += 1
	end

	local controller = WeaponAnimationController.new({
		player = player,
		combatConfig = {
			Weapons = {
				Pistol = {
					Category = "Ranged",
					FireAnimationId = "rbxassetid://1",
					FireAnimationSpeed = 1.25,
				},
				Sword = {
					Category = "Melee",
					SwingAnimationId = "rbxassetid://2",
					SwingAnimationSpeed = 1.1,
					Cooldown = 0.75,
				},
			},
		},
		loadTrack = function(_, animationId)
			loadCount += 1
			equal(animationId == "rbxassetid://1" or animationId == "rbxassetid://2", true, "known animation loaded")
			return track
		end,
		delay = function(seconds, callback)
			pendingDelay = { seconds = seconds, callback = callback }
		end,
	})

	equal(controller:PlayFire("Missing"), nil, "unknown weapon ignored")
	equal(controller:PlayFire("Pistol"), track, "ranged fire returns track")
	equal(track.playCount, 1, "ranged track played")
	equal(track.adjustedSpeed, 1.25, "ranged speed applied")
	equal(controller:PlayFire("Pistol"), track, "ranged track reused")
	equal(loadCount, 1, "animation cached per humanoid")
	equal(track.stopCount, 1, "playing cached track restarted")

	controller:ClearCharacter(character)
	equal(controller:PlayFire("Sword", 0.5), track, "melee fire returns track")
	equal(loadCount, 2, "cache cleared for character")
	equal(track.adjustedSpeed > 1.1, true, "melee animation scales to cooldown")
	equal(pendingDelay ~= nil, true, "melee stop scheduled")
	equal(math.abs(pendingDelay.seconds - 0.475) < 0.001, true, "melee stop timing follows cooldown")
	pendingDelay.callback()
	equal(track.IsPlaying, false, "scheduled melee stop executed")
	equal(controller:PlayReload("Sword"), nil, "melee reload ignored")
	equal(controller:PlayById("", 1), nil, "empty animation ignored")

	character:Destroy()
	return assertions
end

return WeaponAnimationControllerTests
