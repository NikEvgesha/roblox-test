local AimController = {}

function AimController.new(options)
    options = type(options) == "table" and options or {}

    local player = assert(options.player, "AimController requires player")
    local Workspace = assert(options.workspace, "AimController requires workspace")
    local UserInputService = assert(options.userInputService, "AimController requires userInputService")
    local mouse = assert(options.mouse, "AimController requires mouse")
    local crosshairFrame = assert(options.crosshairFrame, "AimController requires crosshairFrame")
    local hitMarkerFrame = assert(options.hitMarkerFrame, "AimController requires hitMarkerFrame")
    local spectatorController = assert(options.spectatorController, "AimController requires spectatorController")
    local getCurrentWeapon = assert(options.getCurrentWeapon, "AimController requires getCurrentWeapon")
    local hasBlockingUiOpen = assert(options.hasBlockingUiOpen, "AimController requires hasBlockingUiOpen")
    local aimModeEnabled = false
    local recoilPitch = 0
    local recoilYaw = 0
    local MELEE_AUTO_LOCK_DISTANCE = tonumber(options.meleeLockDistance) or 8
    local RANGED_AIM_LOCK_DISTANCE = tonumber(options.rangedAimLockDistance) or 10
    local LOOK_ROTATE_LERP_SPEED = tonumber(options.lookRotateLerpSpeed) or 20
    local CURSOR_RAY_DISTANCE = tonumber(options.cursorRayDistance) or 2000
    local AIM_MOTOR_LERP_SPEED = tonumber(options.aimMotorLerpSpeed) or 14
    local AIM_PITCH_UP_LIMIT = tonumber(options.aimPitchUpLimit) or math.rad(60)
    local AIM_PITCH_DOWN_LIMIT = tonumber(options.aimPitchDownLimit) or math.rad(80)
    local AIM_YAW_LIMIT = tonumber(options.aimYawLimit) or math.rad(50)
    local CFRAME_IDENTITY = CFrame.new()
    local HEAD_PITCH_FACTOR = tonumber(options.headPitchFactor) or 1
    local HEAD_YAW_FACTOR = tonumber(options.headYawFactor) or 1
    local RIGHT_ARM_IK = {
        WEIGHT = 1.0,
        MIN_REACH = 2.2,
        MAX_REACH = 6.2,
        SMOOTH_TIME = 0.08,
        POLE_RIGHT = 1.45,
        POLE_UP = 0.35,
        POLE_BACK = 0.45,
    }
    local aimRigByCharacter = setmetatable({}, { __mode = "k" })
    local aimIkByCharacter = setmetatable({}, { __mode = "k" })
    local function ensureRightArmAimIK(character)
    	local cached = aimIkByCharacter[character]
    	if cached and cached.ik and cached.ik.Parent and cached.targetPart and cached.targetPart.Parent then
    		return cached
    	end
    
    	local humanoid = character:FindFirstChildOfClass("Humanoid")
    	local rootPart = character:FindFirstChild("HumanoidRootPart")
    	local rightUpperArm = character:FindFirstChild("RightUpperArm")
    	local rightHand = character:FindFirstChild("RightHand")
    	if not (humanoid and rightUpperArm and rightHand) then
    		return nil
    	end
    	if not (rightUpperArm:IsA("BasePart") and rightHand:IsA("BasePart")) then
    		return nil
    	end
    
    	local targetPart = Instance.new("Part")
    	targetPart.Name = "AimIKTarget"
    	targetPart.Size = Vector3.new(0.1, 0.1, 0.1)
    	targetPart.Transparency = 1
    	targetPart.Anchored = true
    	targetPart.CanCollide = false
    	targetPart.CanTouch = false
    	targetPart.CanQuery = false
    	targetPart.Parent = character
    
    	local targetAttachment = Instance.new("Attachment")
    	targetAttachment.Name = "AimIKTargetAttachment"
    	targetAttachment.Parent = targetPart
    
    	local polePart = Instance.new("Part")
    	polePart.Name = "AimIKPole"
    	polePart.Size = Vector3.new(0.1, 0.1, 0.1)
    	polePart.Transparency = 1
    	polePart.Anchored = true
    	polePart.CanCollide = false
    	polePart.CanTouch = false
    	polePart.CanQuery = false
    	polePart.Parent = character
    
    	local poleAttachment = Instance.new("Attachment")
    	poleAttachment.Name = "AimIKPoleAttachment"
    	poleAttachment.Parent = polePart
    
    	local ik = Instance.new("IKControl")
    	ik.Name = "RangedRightArmIK"
    	ik.Type = Enum.IKControlType.Position
    	ik.ChainRoot = rightUpperArm
    	ik.EndEffector = rightHand
    	ik.Target = targetAttachment
    	ik.Pole = poleAttachment
    	ik.SmoothTime = RIGHT_ARM_IK.SMOOTH_TIME
    	ik.Weight = RIGHT_ARM_IK.WEIGHT
    	ik.Enabled = false
    	ik.Parent = humanoid
    
    	local state = {
    		ik = ik,
    		targetPart = targetPart,
    		targetAttachment = targetAttachment,
    		polePart = polePart,
    		poleAttachment = poleAttachment,
    		rightUpperArm = rightUpperArm,
    		rootPart = rootPart,
    	}
    	aimIkByCharacter[character] = state
    	return state
    end
    
    local function updateRightArmAimIK(character, targetPosition, enabled)
    	local state = ensureRightArmAimIK(character)
    	if not state then
    		return
    	end
    
    	if not enabled or typeof(targetPosition) ~= "Vector3" then
    		state.ik.Enabled = false
    		return
    	end
    
    	local shoulderPosition = state.rightUpperArm.Position
    	local toTarget = targetPosition - shoulderPosition
    	if toTarget.Magnitude < 0.001 then
    		state.ik.Enabled = false
    		return
    	end
    
    	local armReach = math.clamp(toTarget.Magnitude, RIGHT_ARM_IK.MIN_REACH, RIGHT_ARM_IK.MAX_REACH)
    	local ikTargetPosition = shoulderPosition + toTarget.Unit * armReach
    	state.targetPart.CFrame = CFrame.new(ikTargetPosition)
    
    	local basis = state.rootPart and state.rootPart.CFrame or state.rightUpperArm.CFrame
    	local polePosition = shoulderPosition
    		+ basis.RightVector * RIGHT_ARM_IK.POLE_RIGHT
    		+ basis.UpVector * RIGHT_ARM_IK.POLE_UP
    		- basis.LookVector * RIGHT_ARM_IK.POLE_BACK
    	state.polePart.CFrame = CFrame.new(polePosition)
    	state.ik.Enabled = true
    end
    
    local function cleanupRightArmAimIK(character)
    	local state = aimIkByCharacter[character]
    	if not state then
    		return
    	end
    
    	if state.ik and state.ik.Parent then
    		state.ik:Destroy()
    	end
    	if state.targetPart and state.targetPart.Parent then
    		state.targetPart:Destroy()
    	end
    	if state.polePart and state.polePart.Parent then
    		state.polePart:Destroy()
    	end
    	aimIkByCharacter[character] = nil
    end

    local function updateCrosshairVisibility()
    	local _, weapon = getCurrentWeapon()
        crosshairFrame.Visible = not (spectatorController and spectatorController:IsEnabled())
            and weapon ~= nil
            and weapon.Category == "Ranged"
            and not hasBlockingUiOpen()
    end
    
    local function setAimModeEnabled(enabled)
    	if enabled and hasBlockingUiOpen() then
    		enabled = false
    	end
    
    	if aimModeEnabled == enabled then
    		updateCrosshairVisibility()
    		return
    	end
    
    	aimModeEnabled = enabled
    	if not (spectatorController and spectatorController:IsEnabled())
    		and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default
    	then
    		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    	end
    
    	updateCrosshairVisibility()
    end
    
    local function findNearestZombieRoot(origin, maxDistance)
    	local zombiesFolder = Workspace:FindFirstChild("Zombies")
    	if not zombiesFolder then
    		return nil
    	end
    
    	local bestRoot = nil
    	local bestDistanceSq = maxDistance * maxDistance
    	for _, child in ipairs(zombiesFolder:GetChildren()) do
    		if child:IsA("Model") then
    			local humanoid = child:FindFirstChildOfClass("Humanoid")
    			local root = child:FindFirstChild("HumanoidRootPart")
    			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
    				local offset = root.Position - origin
    				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
    				if distanceSq <= bestDistanceSq then
    					bestDistanceSq = distanceSq
    					bestRoot = root
    				end
    			end
    		end
    	end
    
    	return bestRoot
    end
    
    local function getMouseViewportPosition()
    	return Vector2.new(math.max(0, mouse.X), math.max(0, mouse.Y))
    end
    
    local function getMouseAimRay(camera)
    	local unitRay = mouse.UnitRay
    	local rayOrigin = unitRay and unitRay.Origin or camera.CFrame.Position
    	local rayDirection = unitRay and unitRay.Direction or camera.CFrame.LookVector
    	if rayDirection.Magnitude < 0.001 then
    		rayDirection = camera.CFrame.LookVector
    	end
    	return rayOrigin, rayDirection.Unit
    end

    local function getRaycastAimPoint(rayOrigin, rayDirection, ignoreCharacter, maxDistance)
    	local distance = math.max(1, tonumber(maxDistance) or CURSOR_RAY_DISTANCE)
    	local rayParams = RaycastParams.new()
    	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    	rayParams.FilterDescendantsInstances = ignoreCharacter and { ignoreCharacter } or {}
    
    	local result = Workspace:Raycast(rayOrigin, rayDirection * distance, rayParams)
    	if result then
    		return result.Position
    	end
    
    	return rayOrigin + rayDirection * distance
    end
    
    local function resolveRangedAimData(camera, character, root, weapon)
    	if aimModeEnabled then
    		local lockRoot = findNearestZombieRoot(root.Position, RANGED_AIM_LOCK_DISTANCE)
    		if lockRoot then
    			local targetPosition = lockRoot.Position + Vector3.new(0, 1.2, 0)
    			local toTarget = targetPosition - camera.CFrame.Position
    			local direction = toTarget.Magnitude > 0.001 and toTarget.Unit or camera.CFrame.LookVector
    			return targetPosition, direction, camera.CFrame.Position
    		end
    	end
    
    	local aimDistance = CURSOR_RAY_DISTANCE
    	if weapon and typeof(weapon.Range) == "number" then
    		aimDistance = math.max(weapon.Range, 50)
    	end
    
    	local rayOrigin, rayDirection = getMouseAimRay(camera)
    	local targetPosition = getRaycastAimPoint(rayOrigin, rayDirection, character, aimDistance)
    	return targetPosition, rayDirection, rayOrigin
    end
    
    local function rotateRootTowards(root, targetPosition, deltaTime)
    	local planar = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
    	if planar.Magnitude < 0.001 then
    		return
    	end
    
    	local currentLook = root.CFrame.LookVector
    	local currentPlanar = Vector3.new(currentLook.X, 0, currentLook.Z)
    	if currentPlanar.Magnitude < 0.001 then
    		currentPlanar = planar.Unit
    	else
    		currentPlanar = currentPlanar.Unit
    	end
    
    	local alpha = math.clamp(deltaTime * LOOK_ROTATE_LERP_SPEED, 0, 1)
    	local blended = currentPlanar:Lerp(planar.Unit, alpha)
    	if blended.Magnitude < 0.001 then
    		return
    	end
    
    	local lookDirection = blended.Unit
    	root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDirection)
    end
    
    local function findAimAttachment(part, attachmentName)
    	if not (part and part:IsA("BasePart")) then
    		return nil
    	end
    
    	local attachment = part:FindFirstChild(attachmentName)
    	if not (attachment and attachment:IsA("Attachment")) then
    		return nil
    	end
    
    	local jointRotation = attachment:FindFirstChild("JointRotation")
    	if jointRotation and jointRotation:IsA("Attachment") then
    		return jointRotation
    	end
    
    	return attachment
    end
    
    local function resolveAimRig(character)
    	local cached = aimRigByCharacter[character]
    	if cached then
    		local hasAny = false
    		if cached.neck and cached.neck.Parent then
    			hasAny = true
    		elseif cached.rightShoulder and cached.rightShoulder.Parent then
    			hasAny = true
    		elseif cached.leftShoulder and cached.leftShoulder.Parent then
    			hasAny = true
    		elseif cached.waist and cached.waist.Parent then
    			hasAny = true
    		elseif cached.rightHip and cached.rightHip.Parent then
    			hasAny = true
    		elseif cached.leftHip and cached.leftHip.Parent then
    			hasAny = true
    		elseif cached.neckAttachment and cached.neckAttachment.Parent then
    			hasAny = true
    		elseif cached.rightShoulderAttachment and cached.rightShoulderAttachment.Parent then
    			hasAny = true
    		elseif cached.leftShoulderAttachment and cached.leftShoulderAttachment.Parent then
    			hasAny = true
    		elseif cached.waistAttachment and cached.waistAttachment.Parent then
    			hasAny = true
    		elseif cached.rightHipAttachment and cached.rightHipAttachment.Parent then
    			hasAny = true
    		elseif cached.leftHipAttachment and cached.leftHipAttachment.Parent then
    			hasAny = true
    		end
    		if hasAny then
    			return cached
    		end
    	end
    
    	local rig = {
    		neck = nil,
    		rightShoulder = nil,
    		leftShoulder = nil,
    		waist = nil,
    		rightHip = nil,
    		leftHip = nil,
    		baseC0 = {},
    		neckAttachment = nil,
    		rightShoulderAttachment = nil,
    		leftShoulderAttachment = nil,
    		rightShoulderAttachmentPart1 = nil,
    		leftShoulderAttachmentPart1 = nil,
    		waistAttachment = nil,
    		rightHipAttachment = nil,
    		leftHipAttachment = nil,
    		baseAttachmentCFrame = {},
    	}
    
    	for _, desc in ipairs(character:GetDescendants()) do
    		if desc:IsA("Motor6D") then
    			if desc.Name == "Neck" then
    				rig.neck = rig.neck or desc
    			elseif desc.Name == "RightShoulder" or desc.Name == "Right Shoulder" then
    				rig.rightShoulder = rig.rightShoulder or desc
    			elseif desc.Name == "LeftShoulder" or desc.Name == "Left Shoulder" then
    				rig.leftShoulder = rig.leftShoulder or desc
    			elseif desc.Name == "Waist" then
    				rig.waist = rig.waist or desc
    			elseif desc.Name == "RightHip" or desc.Name == "Right Hip" then
    				rig.rightHip = rig.rightHip or desc
    			elseif desc.Name == "LeftHip" or desc.Name == "Left Hip" then
    				rig.leftHip = rig.leftHip or desc
    			end
    		end
    	end
    
    	if rig.neck then
    		rig.baseC0.neck = rig.neck.C0
    	end
    	if rig.rightShoulder then
    		rig.baseC0.rightShoulder = rig.rightShoulder.C0
    	end
    	if rig.leftShoulder then
    		rig.baseC0.leftShoulder = rig.leftShoulder.C0
    	end
    	if rig.waist then
    		rig.baseC0.waist = rig.waist.C0
    	end
    	if rig.rightHip then
    		rig.baseC0.rightHip = rig.rightHip.C0
    	end
    	if rig.leftHip then
    		rig.baseC0.leftHip = rig.leftHip.C0
    	end
    
    	local upperTorso = character:FindFirstChild("UpperTorso")
    	local lowerTorso = character:FindFirstChild("LowerTorso")
    	local rightUpperArm = character:FindFirstChild("RightUpperArm")
    	local leftUpperArm = character:FindFirstChild("LeftUpperArm")
    	rig.neckAttachment = findAimAttachment(upperTorso, "NeckRigAttachment")
    	rig.rightShoulderAttachment = findAimAttachment(upperTorso, "RightShoulderRigAttachment")
    	rig.leftShoulderAttachment = findAimAttachment(upperTorso, "LeftShoulderRigAttachment")
    	rig.rightShoulderAttachmentPart1 = findAimAttachment(rightUpperArm, "RightShoulderRigAttachment")
    	rig.leftShoulderAttachmentPart1 = findAimAttachment(leftUpperArm, "LeftShoulderRigAttachment")
    	rig.waistAttachment = findAimAttachment(upperTorso, "WaistRigAttachment")
    	rig.rightHipAttachment = findAimAttachment(lowerTorso, "RightHipRigAttachment")
    	rig.leftHipAttachment = findAimAttachment(lowerTorso, "LeftHipRigAttachment")
    
    	if rig.neckAttachment then
    		rig.baseAttachmentCFrame.neck = rig.neckAttachment.CFrame
    	end
    	if rig.rightShoulderAttachment then
    		rig.baseAttachmentCFrame.rightShoulder = rig.rightShoulderAttachment.CFrame
    	end
    	if rig.leftShoulderAttachment then
    		rig.baseAttachmentCFrame.leftShoulder = rig.leftShoulderAttachment.CFrame
    	end
    	if rig.rightShoulderAttachmentPart1 then
    		rig.baseAttachmentCFrame.rightShoulderPart1 = rig.rightShoulderAttachmentPart1.CFrame
    	end
    	if rig.leftShoulderAttachmentPart1 then
    		rig.baseAttachmentCFrame.leftShoulderPart1 = rig.leftShoulderAttachmentPart1.CFrame
    	end
    	if rig.waistAttachment then
    		rig.baseAttachmentCFrame.waist = rig.waistAttachment.CFrame
    	end
    	if rig.rightHipAttachment then
    		rig.baseAttachmentCFrame.rightHip = rig.rightHipAttachment.CFrame
    	end
    	if rig.leftHipAttachment then
    		rig.baseAttachmentCFrame.leftHip = rig.leftHipAttachment.CFrame
    	end
    
    	aimRigByCharacter[character] = rig
    	return rig
    end
    
    local function lerpMotorTransform(motor, targetOffset, alpha)
    	if not motor then
    		return
    	end
    
    	local offset = targetOffset or CFRAME_IDENTITY
    	motor.Transform = motor.Transform:Lerp(offset, alpha)
    end
    
    local function lerpAttachmentCFrame(attachment, baseCFrame, targetOffset, alpha)
    	if not (attachment and baseCFrame) then
    		return
    	end
    
    	local offset = targetOffset or CFRAME_IDENTITY
    	local target = baseCFrame * offset
    	attachment.CFrame = attachment.CFrame:Lerp(target, alpha)
    end
    
    local function resetAimRig(character, deltaTime)
    	local rig = resolveAimRig(character)
    	local alpha = math.clamp(deltaTime * AIM_MOTOR_LERP_SPEED, 0, 1)
    	lerpMotorTransform(rig.neck, CFRAME_IDENTITY, alpha)
    	lerpAttachmentCFrame(rig.neckAttachment, rig.baseAttachmentCFrame.neck, CFRAME_IDENTITY, alpha)
    end
    
    local function updateAimRig(character, root, targetPosition, aimDirection, deltaTime)
    	local rig = resolveAimRig(character)
    	if not rig then
    		return
    	end
    
    	local worldDirection = nil
    	local aimOrigin = root.Position + Vector3.new(0, 1.5, 0)
    	local toTarget = targetPosition - aimOrigin
    	if toTarget.Magnitude > 0.001 then
    		worldDirection = toTarget.Unit
    	elseif typeof(aimDirection) == "Vector3" and aimDirection.Magnitude > 0.001 then
    		worldDirection = aimDirection.Unit
    	end
    
    	if not worldDirection then
    		resetAimRig(character, deltaTime)
    		return
    	end
    
    	local localDirection = root.CFrame:VectorToObjectSpace(worldDirection)
    	local horizontalMag = math.sqrt(localDirection.X * localDirection.X + localDirection.Z * localDirection.Z)
    	if horizontalMag < 0.001 then
    		horizontalMag = 0.001
    	end
    
    	local pitchUp = math.atan2(localDirection.Y, horizontalMag)
    	local yawRight = math.atan2(localDirection.X, -localDirection.Z)
    	local pitch = math.clamp(-pitchUp, -AIM_PITCH_UP_LIMIT, AIM_PITCH_DOWN_LIMIT)
    	local yaw = math.clamp(yawRight, -AIM_YAW_LIMIT, AIM_YAW_LIMIT)
    
    	local headTarget = CFrame.Angles(-pitch * HEAD_PITCH_FACTOR, yaw * HEAD_YAW_FACTOR, 0)
    	local alpha = math.clamp(deltaTime * AIM_MOTOR_LERP_SPEED, 0, 1)
    
    	lerpMotorTransform(rig.neck, headTarget, alpha)
    	lerpAttachmentCFrame(rig.neckAttachment, rig.baseAttachmentCFrame.neck, headTarget, alpha)
    end
    
    local function updateGameplayFacing(deltaTime)
    	if spectatorController:IsEnabled() then
    		local spectatorCharacter = player.Character
    		if spectatorCharacter then
    			updateRightArmAimIK(spectatorCharacter, nil, false)
    		end
    		return
    	end
    
    	local weaponKey, weapon = getCurrentWeapon()
    	local character = player.Character
    	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    	local root = character and character:FindFirstChild("HumanoidRootPart")
    	local camera = Workspace.CurrentCamera
    	local blockingUi = hasBlockingUiOpen()
    	local meleeLockRoot = nil
    
    	if weapon and weapon.Category == "Melee" and root and root:IsA("BasePart") then
    		meleeLockRoot = findNearestZombieRoot(root.Position, MELEE_AUTO_LOCK_DISTANCE)
    	end
    
    	if humanoid then
    		local shouldForceFacing = weapon
    			and (weapon.Category == "Ranged" or (weapon.Category == "Melee" and meleeLockRoot ~= nil))
    			and not blockingUi
    		humanoid.AutoRotate = not shouldForceFacing
    	end
    
    	if blockingUi then
    		if character then
    			updateRightArmAimIK(character, nil, false)
    		end
    		return
    	end
    
    	if not weaponKey or not weapon or not root or not root:IsA("BasePart") then
    		if character then
    			updateRightArmAimIK(character, nil, false)
    		end
    		return
    	end
    
    	if weapon.Category == "Ranged" and not camera then
    		updateRightArmAimIK(character, nil, false)
    		return
    	end
    
    	local targetPosition = nil
    	local aimDirection = nil
    	if weapon.Category == "Ranged" then
    		targetPosition, aimDirection = resolveRangedAimData(camera, character, root, weapon)
    	elseif weapon.Category == "Melee" and meleeLockRoot then
    		targetPosition = meleeLockRoot.Position + Vector3.new(0, 1.2, 0)
    	end
    
    	if targetPosition then
    		rotateRootTowards(root, targetPosition, deltaTime)
    	elseif weapon.Category == "Ranged" and aimDirection then
    		local planarAim = Vector3.new(aimDirection.X, 0, aimDirection.Z)
    		if planarAim.Magnitude > 0.001 then
    			rotateRootTowards(root, root.Position + planarAim.Unit * 20, deltaTime)
    		end
    	end
    
    	if weapon.Category == "Ranged" and targetPosition then
    		updateAimRig(character, root, targetPosition, aimDirection, deltaTime)
    		updateRightArmAimIK(character, targetPosition, true)
    	else
    		resetAimRig(character, deltaTime)
    		updateRightArmAimIK(character, nil, false)
    	end
    end
    
    local function updateGameplayCursorState()
    	updateCrosshairVisibility()
    
    	if crosshairFrame.Visible then
    		local viewportPosition = getMouseViewportPosition()
    		crosshairFrame.Position = UDim2.fromOffset(viewportPosition.X, viewportPosition.Y)
    	end
    
    	hitMarkerFrame.Position = crosshairFrame.Visible and crosshairFrame.Position or UDim2.fromScale(0.5, 0.5)
    
    	if spectatorController:IsEnabled() then
    		return
    	end
    
    	if crosshairFrame.Visible then
    		UserInputService.MouseIconEnabled = false
    		mouse.Icon = ""
    	else
    		UserInputService.MouseIconEnabled = true
    		mouse.Icon = "rbxasset://SystemCursors/Arrow"
    	end
    end

    local function applyShotRecoil(weapon)
    	if spectatorController:IsEnabled() or not weapon or weapon.Category ~= "Ranged" then
    		return
    	end
    
    	-- Keep recoil visually neutral so it doesn't feel like bullet spread.
    	recoilPitch = 0
    	recoilYaw = 0
    end
    
    local function updateRecoil(deltaTime)
    	if spectatorController:IsEnabled() then
    		recoilPitch = 0
    		recoilYaw = 0
    		return
    	end
    
    	local camera = Workspace.CurrentCamera
    	if not camera or camera.CameraType == Enum.CameraType.Scriptable then
    		return
    	end
    
    	if math.abs(recoilPitch) > 0.00005 or math.abs(recoilYaw) > 0.00005 then
    		camera.CFrame = camera.CFrame * CFrame.Angles(0, recoilYaw, 0)
    		local decay = math.exp(-22 * deltaTime)
    		recoilPitch = 0
    		recoilYaw *= decay
    	else
    		recoilPitch = 0
    		recoilYaw = 0
    	end
    end
    local controller = {}

    function controller:SetAimModeEnabled(enabled)
        setAimModeEnabled(enabled)
    end

    function controller:IsAimModeEnabled()
        return aimModeEnabled
    end

    function controller:UpdateCrosshairVisibility()
        updateCrosshairVisibility()
    end

    function controller:FindNearestEnemyRoot(origin, maxDistance)
        return findNearestZombieRoot(origin, maxDistance)
    end

    function controller:ResolveRangedAimData(camera, character, root, weapon)
        return resolveRangedAimData(camera, character, root, weapon)
    end

    function controller:ApplyShotRecoil(weapon)
        applyShotRecoil(weapon)
    end

    function controller:BindCharacter(character)
        setAimModeEnabled(false)
        cleanupRightArmAimIK(character)
        ensureRightArmAimIK(character)
    end

    function controller:UnbindCharacter(character)
        cleanupRightArmAimIK(character)
        setAimModeEnabled(false)
    end

    function controller:Update(deltaTime)
        updateRecoil(deltaTime)
        updateGameplayFacing(deltaTime)
        updateGameplayCursorState()
    end

    function controller:ReconcileRightMouse()
        local rightPressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if not spectatorController:IsEnabled() and aimModeEnabled and not rightPressed then
            setAimModeEnabled(false)
        end
    end

    function controller:ReconcileBlockingUi()
        if hasBlockingUiOpen() and aimModeEnabled then
            setAimModeEnabled(false)
        end
    end

    return controller
end

return AimController
