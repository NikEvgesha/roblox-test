local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ProceduralEnemyAnimator = require(sharedFolder:WaitForChild("ProceduralEnemyAnimator"))

local PROCEDURAL_ENEMY_TAG = "ProceduralEnemy"
local MOVEMENT_GRACE_SECONDS = 0.16
local activeAnimations = {}
local pendingModels = {}

local function unregisterModel(model)
	local state = activeAnimations[model]
	if state then
		ProceduralEnemyAnimator.Reset(state.animation)
		activeAnimations[model] = nil
	end
	pendingModels[model] = nil
end

local function tryRegisterModel(model)
	if activeAnimations[model] or pendingModels[model] or not model:IsA("Model") then
		return
	end
	pendingModels[model] = true

	task.defer(function()
		for _ = 1, 5 do
			if not model.Parent or not CollectionService:HasTag(model, PROCEDURAL_ENEMY_TAG) then
				break
			end

			local style = model:GetAttribute("ProceduralAnimationStyle")
			local animation = ProceduralEnemyAnimator.Capture(model, style)
			if animation then
				local position = model:GetPivot().Position
				activeAnimations[model] = {
					animation = animation,
					lastAttackSerial = tonumber(model:GetAttribute("ProceduralAnimationAttackSerial")) or 0,
					lastMovedAt = 0,
					lastPosition = position,
				}
				break
			end
			task.wait()
		end
		pendingModels[model] = nil
	end)
end

CollectionService:GetInstanceAddedSignal(PROCEDURAL_ENEMY_TAG):Connect(tryRegisterModel)
CollectionService:GetInstanceRemovedSignal(PROCEDURAL_ENEMY_TAG):Connect(unregisterModel)

for _, model in CollectionService:GetTagged(PROCEDURAL_ENEMY_TAG) do
	tryRegisterModel(model)
end

RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for model, state in pairs(activeAnimations) do
		if not model.Parent or not CollectionService:HasTag(model, PROCEDURAL_ENEMY_TAG) then
			unregisterModel(model)
			continue
		end

		local currentPosition = model:GetPivot().Position
		if (currentPosition - state.lastPosition).Magnitude > 0.015 then
			state.lastMovedAt = now
		end
		state.lastPosition = currentPosition

		local attackSerial = tonumber(model:GetAttribute("ProceduralAnimationAttackSerial")) or 0
		if attackSerial ~= state.lastAttackSerial then
			state.lastAttackSerial = attackSerial
			ProceduralEnemyAnimator.TriggerAttack(
				state.animation,
				now,
				tonumber(model:GetAttribute("ProceduralAnimationAttackDuration")) or 0.3
			)
		end

		ProceduralEnemyAnimator.Update(
			state.animation,
			now - state.lastMovedAt <= MOVEMENT_GRACE_SECONDS,
			now,
			tonumber(model:GetAttribute("ProceduralAnimationMoveSpeed")) or 0
		)
	end
end)
