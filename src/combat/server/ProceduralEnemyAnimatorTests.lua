local ProceduralEnemyAnimator = require(script.Parent:WaitForChild("ProceduralEnemyAnimator"))

local ProceduralEnemyAnimatorTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local function buildRig(motorNames)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = model
	for _, name in ipairs(motorNames) do
		local part = Instance.new("Part")
		part.Name = name .. "Part"
		part.Parent = model
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = root
		motor.Part1 = part
		motor.Parent = root
	end
	return model
end

function ProceduralEnemyAnimatorTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end

	equal(ProceduralEnemyAnimator.Capture(nil, "Scuttle"), nil, "nil model rejected")
	local empty = Instance.new("Model")
	equal(ProceduralEnemyAnimator.Capture(empty, "Unknown"), nil, "unknown style rejected")
	equal(ProceduralEnemyAnimator.Capture(empty, "Hover"), nil, "rig without motors rejected")
	empty:Destroy()

	local scuttleRig = buildRig({
		"BodyMotor",
		"LegFrontLeft",
		"LegFrontRight",
		"LegBackLeft",
		"LegBackRight",
		"MandibleLeft",
		"MandibleRight",
	})
	local scuttle = ProceduralEnemyAnimator.Capture(scuttleRig, "Scuttle")
	equal(scuttle.style, "Scuttle", "scuttle style captured")
	equal(scuttle.motors.LegFrontLeft ~= nil, true, "scuttle leg captured")
	equal(ProceduralEnemyAnimator.Update(scuttle, true, 10, 12), true, "scuttle first update")
	equal(scuttle.motors.LegFrontLeft.Transform ~= CFrame.identity, true, "scuttle leg animated")
	equal(ProceduralEnemyAnimator.Update(scuttle, true, 10.01, 12), false, "scuttle update throttled")
	equal(ProceduralEnemyAnimator.TriggerAttack(scuttle, 11, 0.4), true, "scuttle attack triggered")
	equal(scuttle.attackEndsAt, 11.4, "scuttle attack duration")

	local stompRig = buildRig({ "BodyMotor", "HeadMotor", "LeftLeg", "RightLeg", "LeftArm", "RightArm" })
	local stomp = ProceduralEnemyAnimator.Capture(stompRig, "Stomp")
	equal(ProceduralEnemyAnimator.Update(stomp, true, 20, 5), true, "stomp updated")
	equal(stomp.motors.LeftArm.Transform ~= CFrame.identity, true, "stomp arm animated")
	ProceduralEnemyAnimator.TriggerAttack(stomp, 21, 0.3)
	stomp.nextUpdateAt = 0
	ProceduralEnemyAnimator.Update(stomp, false, 21.15, 5)
	equal(stomp.motors.RightArm.Transform ~= CFrame.identity, true, "stomp attack animated")

	local hoverRig = buildRig({ "CoreMotor", "Orbit1", "Orbit2", "Orbit3" })
	local hover = ProceduralEnemyAnimator.Capture(hoverRig, "Hover")
	equal(ProceduralEnemyAnimator.Update(hover, false, 30, 4), true, "hover updated")
	equal(hover.motors.CoreMotor.Transform ~= CFrame.identity, true, "hover core animated")
	equal(hover.motors.Orbit1.Transform ~= hover.motors.Orbit2.Transform, true, "hover shards offset")

	ProceduralEnemyAnimator.Reset(scuttle)
	equal(scuttle.motors.LegFrontLeft.Transform, CFrame.identity, "scuttle reset")
	ProceduralEnemyAnimator.Reset(stomp)
	equal(stomp.motors.LeftArm.Transform, CFrame.identity, "stomp reset")
	ProceduralEnemyAnimator.Reset(hover)
	equal(hover.motors.Orbit1.Transform, CFrame.identity, "hover reset")
	equal(ProceduralEnemyAnimator.TriggerAttack(nil), false, "nil attack rejected")
	equal(ProceduralEnemyAnimator.Update(nil), false, "nil update rejected")

	scuttleRig:Destroy()
	stompRig:Destroy()
	hoverRig:Destroy()
	return assertions
end

return ProceduralEnemyAnimatorTests
