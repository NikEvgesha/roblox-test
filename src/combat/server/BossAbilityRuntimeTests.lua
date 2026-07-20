local BossAbilityRuntime = require(script.Parent:WaitForChild("BossAbilityRuntime"))

local BossAbilityRuntimeTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

function BossAbilityRuntimeTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	local center = Vector3.new(10, 2, -5)
	equal(BossAbilityRuntime.IsPointInCircle(center, center, 0), true, "circle includes center")
	equal(BossAbilityRuntime.IsPointInCircle(Vector3.new(16, 100, -5), center, 6), true, "circle ignores height")
	equal(BossAbilityRuntime.IsPointInCircle(Vector3.new(16.01, 2, -5), center, 6), false, "circle excludes outside point")
	equal(BossAbilityRuntime.IsPointInCircle(Vector3.new(10, 2, -5), center, -2), true, "negative radius clamps")

	local box = CFrame.lookAt(Vector3.new(0, 0, 10), Vector3.new(0, 0, 20))
	equal(BossAbilityRuntime.IsPointInBox(Vector3.new(0, 50, 10), box, 4, 12), true, "box ignores height")
	equal(BossAbilityRuntime.IsPointInBox(Vector3.new(2, 0, 10), box, 4, 12), true, "box includes width edge")
	equal(BossAbilityRuntime.IsPointInBox(Vector3.new(2.1, 0, 10), box, 4, 12), false, "box excludes width overflow")
	equal(BossAbilityRuntime.IsPointInBox(box.Position + box.LookVector * 6, box, 4, 12), true, "box includes length edge")
	equal(BossAbilityRuntime.IsPointInBox(box.Position + box.LookVector * 6.1, box, 4, 12), false, "box excludes length overflow")

	return assertions
end

return BossAbilityRuntimeTests
