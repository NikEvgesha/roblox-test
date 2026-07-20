local ProceduralEnemyAnimator = {}

local UPDATE_INTERVAL = 1 / 30
local VALID_STYLES = {
	Scuttle = true,
	Stomp = true,
	Hover = true,
}

local function captureMotors(model)
	local motors = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	return motors
end

local function setTransform(animation, name, transform)
	local motor = animation.motors[name]
	if motor then
		motor.Transform = transform
	end
end

local function attackCurve(animation, now)
	if animation.attackEndsAt <= now or animation.attackDuration <= 0 then
		return 0
	end
	local progress = math.clamp((now - animation.attackStartedAt) / animation.attackDuration, 0, 1)
	return math.sin(progress * math.pi)
end

local function updateScuttle(animation, isMoving, now, moveSpeed)
	local movementWeight = isMoving and 1 or 0
	local rate = isMoving and (7 + moveSpeed * 0.28) or 1.6
	local phase = now * rate + animation.phaseOffset
	local stride = math.sin(phase) * movementWeight
	local opposite = -stride
	local leftLift = math.max(0, math.sin(phase)) * movementWeight
	local rightLift = math.max(0, -math.sin(phase)) * movementWeight
	local attack = attackCurve(animation, now)

	local idleBreath = math.sin(now * 2.1 + animation.phaseOffset) * 0.025
	setTransform(
		animation,
		"BodyMotor",
		CFrame.new(0, idleBreath, -attack * 0.42) * CFrame.Angles(attack * 0.18, stride * 0.1, stride * 0.06)
	)
	setTransform(
		animation,
		"LegFrontLeft",
		CFrame.new(0, leftLift * 0.2, stride * 0.12) * CFrame.Angles(stride * 0.82, 0, -0.24)
	)
	setTransform(
		animation,
		"LegBackRight",
		CFrame.new(0, leftLift * 0.2, stride * 0.12) * CFrame.Angles(stride * 0.82, 0, 0.24)
	)
	setTransform(
		animation,
		"LegFrontRight",
		CFrame.new(0, rightLift * 0.2, opposite * 0.12) * CFrame.Angles(opposite * 0.82, 0, 0.24)
	)
	setTransform(
		animation,
		"LegBackLeft",
		CFrame.new(0, rightLift * 0.2, opposite * 0.12) * CFrame.Angles(opposite * 0.82, 0, -0.24)
	)
	setTransform(animation, "MandibleLeft", CFrame.Angles(0, -attack * 0.95, -attack * 0.22))
	setTransform(animation, "MandibleRight", CFrame.Angles(0, attack * 0.95, attack * 0.22))
end

local function updateStomp(animation, isMoving, now, moveSpeed)
	local movementWeight = isMoving and 1 or 0
	local rate = isMoving and (3.1 + moveSpeed * 0.16) or 1.1
	local phase = now * rate + animation.phaseOffset
	local stride = math.sin(phase) * movementWeight
	local leftLift = math.max(0, stride)
	local rightLift = math.max(0, -stride)
	local attack = attackCurve(animation, now)

	local idleBreath = math.sin(now * 1.35 + animation.phaseOffset) * 0.018
	setTransform(
		animation,
		"BodyMotor",
		CFrame.new(0, idleBreath, -attack * 0.32) * CFrame.Angles(attack * 0.24, stride * 0.08, stride * 0.03)
	)
	setTransform(animation, "HeadMotor", CFrame.Angles(-attack * 0.3, -stride * 0.08, 0))
	setTransform(
		animation,
		"LeftLeg",
		CFrame.new(0, leftLift * 0.24, stride * 0.12) * CFrame.Angles(stride * 0.66, 0, 0)
	)
	setTransform(
		animation,
		"RightLeg",
		CFrame.new(0, rightLift * 0.24, -stride * 0.12) * CFrame.Angles(-stride * 0.66, 0, 0)
	)
	setTransform(
		animation,
		"LeftArm",
		CFrame.new(0, 0, -attack * 0.24) * CFrame.Angles(-stride * 0.42 - attack * 1.35, 0, -0.1)
	)
	setTransform(
		animation,
		"RightArm",
		CFrame.new(0, 0, -attack * 0.24) * CFrame.Angles(stride * 0.42 - attack * 1.35, 0, 0.1)
	)
end

local function updateHover(animation, isMoving, now)
	local rate = isMoving and 3.6 or 2.2
	local phase = now * rate + animation.phaseOffset
	local pulse = math.sin(phase)
	local attack = attackCurve(animation, now)

	setTransform(
		animation,
		"CoreMotor",
		CFrame.new(0, pulse * 0.16, -attack * 0.5) * CFrame.Angles(attack * 0.22, phase * 0.22, pulse * 0.05)
	)
	for index = 1, 3 do
		local angle = phase * (0.7 + index * 0.12) + (index - 1) * math.pi * 2 / 3
		local radius = 0.28 + attack * 0.62
		setTransform(
			animation,
			"Orbit" .. index,
			CFrame.new(math.cos(angle) * radius, math.sin(angle * 1.7) * 0.22, math.sin(angle) * radius)
				* CFrame.Angles(angle * 0.4, angle, -angle * 0.25)
		)
	end
end

function ProceduralEnemyAnimator.Capture(model, style)
	if not model or not VALID_STYLES[style] then
		return nil
	end
	local motors = captureMotors(model)
	if next(motors) == nil then
		return nil
	end
	return {
		style = style,
		motors = motors,
		phaseOffset = math.random() * math.pi * 2,
		nextUpdateAt = 0,
		attackStartedAt = 0,
		attackEndsAt = 0,
		attackDuration = 0.3,
	}
end

function ProceduralEnemyAnimator.TriggerAttack(animation, now, duration)
	if not animation then
		return false
	end
	animation.attackStartedAt = tonumber(now) or os.clock()
	animation.attackDuration = math.max(0.05, tonumber(duration) or 0.3)
	animation.attackEndsAt = animation.attackStartedAt + animation.attackDuration
	return true
end

function ProceduralEnemyAnimator.Update(animation, isMoving, now, moveSpeed)
	if not animation then
		return false
	end
	local currentTime = tonumber(now) or os.clock()
	if currentTime < animation.nextUpdateAt then
		return false
	end
	animation.nextUpdateAt = currentTime + UPDATE_INTERVAL

	if animation.style == "Scuttle" then
		updateScuttle(animation, isMoving == true, currentTime, tonumber(moveSpeed) or 0)
	elseif animation.style == "Stomp" then
		updateStomp(animation, isMoving == true, currentTime, tonumber(moveSpeed) or 0)
	elseif animation.style == "Hover" then
		updateHover(animation, isMoving == true, currentTime)
	end
	return true
end

function ProceduralEnemyAnimator.Reset(animation)
	if not animation then
		return
	end
	for _, motor in pairs(animation.motors) do
		if motor and motor.Parent then
			motor.Transform = CFrame.identity
		end
	end
end

return ProceduralEnemyAnimator
