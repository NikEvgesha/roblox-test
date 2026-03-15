local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))

local COMBAT_ACTION_EVENT_NAME = "CombatAction"
local COMBAT_STATE_EVENT_NAME = "CombatState"

local function ensureRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then
		return event
	end

	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local combatActionEvent = ensureRemoteEvent(COMBAT_ACTION_EVENT_NAME)
local combatStateEvent = ensureRemoteEvent(COMBAT_STATE_EVENT_NAME)

local pickupFolder = Workspace:FindFirstChild("AmmoPickups")
if not pickupFolder then
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "AmmoPickups"
	pickupFolder.Parent = Workspace
end

local stateByPlayer = {}

local function createSound(parent, name, soundId, volume)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	sound.Parent = parent
	return sound
end

local function createPistolTool()
	local tool = Instance.new("Tool")
	tool.Name = combatConfig.Gun.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "ЛКМ: стрелять | R: перезарядить"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 0.8, 2)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(70, 70, 70)
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	createSound(handle, "ShotSound", combatConfig.Sounds.GunShotId, 0.9)
	createSound(handle, "ReloadSound", combatConfig.Sounds.ReloadId, 0.8)
	createSound(handle, "PickupSound", combatConfig.Sounds.PickupId, 0.7)

	return tool
end

local function createSwordTool()
	local tool = Instance.new("Tool")
	tool.Name = combatConfig.Sword.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "ЛКМ: удар мечом"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 1.2, 0.4)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(95, 95, 95)
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.25, 3.2, 0.45)
	blade.Material = Enum.Material.Metal
	blade.Color = Color3.fromRGB(210, 210, 215)
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade

	blade.CFrame = handle.CFrame * CFrame.new(0, 2, 0)

	createSound(handle, "SwingSound", combatConfig.Sounds.SwordSwingId, 0.9)
	createSound(handle, "PickupSound", combatConfig.Sounds.PickupId, 0.7)

	return tool
end

local function ensureTool(container, toolName, constructor)
	if not container then
		return
	end

	if container:FindFirstChild(toolName) then
		return
	end

	local tool = constructor()
	tool.Parent = container
end

local function getEquippedWeapon(player)
	local character = player.Character
	if not character then
		return "None"
	end

	if character:FindFirstChild(combatConfig.Gun.ToolName) then
		return combatConfig.Gun.ToolName
	end

	if character:FindFirstChild(combatConfig.Sword.ToolName) then
		return combatConfig.Sword.ToolName
	end

	return "None"
end

local function sendCombatState(player)
	local state = stateByPlayer[player]
	if not state then
		return
	end

	combatStateEvent:FireClient(player, {
		mag = state.mag,
		reserve = state.reserve,
		reloading = state.reloading,
		equipped = getEquippedWeapon(player),
	})
end

local function ensureLoadout(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	local starterGear = player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear", 5)

	ensureTool(backpack, combatConfig.Gun.ToolName, createPistolTool)
	ensureTool(starterGear, combatConfig.Gun.ToolName, createPistolTool)
	ensureTool(backpack, combatConfig.Sword.ToolName, createSwordTool)
	ensureTool(starterGear, combatConfig.Sword.ToolName, createSwordTool)
end

local function playHandleSound(player, toolName, soundName)
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChild(toolName)
	if not tool then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local sound = handle:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function findHumanoidFromPart(part)
	if not part then
		return nil
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	return model:FindFirstChildOfClass("Humanoid")
end

local function makeTracer(origin, hitPosition)
	local distance = (hitPosition - origin).Magnitude
	if distance <= 0 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 226, 110)
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = Workspace

	Debris:AddItem(tracer, 0.08)
end

local function handleShoot(player, payload)
	local state = stateByPlayer[player]
	if not state then
		return
	end

	if state.reloading then
		return
	end

	if getEquippedWeapon(player) ~= combatConfig.Gun.ToolName then
		return
	end

	if os.clock() - state.lastShot < combatConfig.Gun.FireCooldown then
		return
	end

	if state.mag <= 0 then
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local origin = payload.origin
	local direction = payload.direction
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	if direction.Magnitude < 0.01 then
		return
	end

	state.lastShot = os.clock()
	state.mag -= 1
	sendCombatState(player)
	playHandleSound(player, combatConfig.Gun.ToolName, "ShotSound")

	local unitDirection = direction.Unit
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(origin, unitDirection * combatConfig.Gun.Range, rayParams)
	local hitPosition = origin + unitDirection * combatConfig.Gun.Range

	if result then
		hitPosition = result.Position
		local humanoid = findHumanoidFromPart(result.Instance)
		if humanoid and humanoid.Parent ~= player.Character then
			humanoid:TakeDamage(combatConfig.Gun.Damage)
		end
	end

	makeTracer(origin, hitPosition)
end

local function handleReload(player)
	local state = stateByPlayer[player]
	if not state then
		return
	end

	if state.reloading then
		return
	end

	if getEquippedWeapon(player) ~= combatConfig.Gun.ToolName then
		return
	end

	if state.mag >= combatConfig.Gun.MaxMag then
		return
	end

	if state.reserve <= 0 then
		return
	end

	state.reloading = true
	sendCombatState(player)
	playHandleSound(player, combatConfig.Gun.ToolName, "ReloadSound")

	task.delay(combatConfig.Gun.ReloadTime, function()
		local currentState = stateByPlayer[player]
		if not currentState then
			return
		end

		local need = combatConfig.Gun.MaxMag - currentState.mag
		local amount = math.min(need, currentState.reserve)
		currentState.mag += amount
		currentState.reserve -= amount
		currentState.reloading = false
		sendCombatState(player)
	end)
end

local function handleSwordSwing(player)
	local state = stateByPlayer[player]
	if not state then
		return
	end

	if getEquippedWeapon(player) ~= combatConfig.Sword.ToolName then
		return
	end

	if os.clock() - state.lastSwing < combatConfig.Sword.Cooldown then
		return
	end

	state.lastSwing = os.clock()
	playHandleSound(player, combatConfig.Sword.ToolName, "SwingSound")

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	overlapParams.FilterDescendantsInstances = { character }

	local center = root.Position + root.CFrame.LookVector * 3
	local parts = Workspace:GetPartBoundsInRadius(center, combatConfig.Sword.Range, overlapParams)
	local hitModels = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= character and not hitModels[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot then
				local toTarget = targetRoot.Position - root.Position
				if toTarget.Magnitude > 0 then
					local facingDot = root.CFrame.LookVector:Dot(toTarget.Unit)
					if facingDot > -0.15 then
						humanoid:TakeDamage(combatConfig.Sword.Damage)
						hitModels[model] = true
					end
				end
			end
		end
	end
end

local function countNearbyPickupsForPlayer(player)
	local count = 0
	for _, obj in ipairs(pickupFolder:GetChildren()) do
		if obj:GetAttribute("OwnerUserId") == player.UserId then
			count += 1
		end
	end
	return count
end

local function spawnAmmoPickupForPlayer(player)
	local state = stateByPlayer[player]
	if not state then
		return
	end

	if countNearbyPickupsForPlayer(player) >= combatConfig.Pickups.MaxNearbyPerPlayer then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local angle = math.random() * math.pi * 2
	local radius = combatConfig.Pickups.MinRadius + math.random() * (combatConfig.Pickups.MaxRadius - combatConfig.Pickups.MinRadius)
	local position = root.Position + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)

	local pickup = Instance.new("Part")
	pickup.Name = "AmmoPickup"
	pickup.Size = Vector3.new(1.2, 1.2, 1.2)
	pickup.Shape = Enum.PartType.Ball
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromRGB(255, 219, 88)
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanQuery = true
	pickup.CanTouch = false
	pickup.Position = position
	pickup:SetAttribute("OwnerUserId", player.UserId)
	pickup.Parent = pickupFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Подобрать"
	prompt.ObjectText = "+Патроны"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = pickup

	local pickupSound = createSound(pickup, "PickupSound", combatConfig.Sounds.PickupId, 0.9)
	local picked = false
	prompt.Triggered:Connect(function(triggeringPlayer)
		if picked then
			return
		end
		if triggeringPlayer ~= player then
			return
		end

		local currentState = stateByPlayer[player]
		if not currentState then
			return
		end

		picked = true
		currentState.reserve = math.min(combatConfig.Gun.MaxReserve, currentState.reserve + combatConfig.Pickups.AmmoAmount)
		sendCombatState(player)
		prompt.Enabled = false
		pickup.Transparency = 1
		pickupSound:Play()
		task.delay(0.15, function()
			if pickup.Parent then
				pickup:Destroy()
			end
		end)
	end)

	Debris:AddItem(pickup, combatConfig.Pickups.Lifetime)
end

local function attachCharacterSignals(player, character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			sendCombatState(player)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			sendCombatState(player)
		end
	end)
end

local function setupPlayer(player)
	stateByPlayer[player] = {
		mag = combatConfig.Gun.MaxMag,
		reserve = combatConfig.Gun.StartReserve,
		reloading = false,
		lastShot = 0,
		lastSwing = 0,
	}

	ensureLoadout(player)

	player.CharacterAdded:Connect(function(character)
		ensureLoadout(player)
		attachCharacterSignals(player, character)
		task.delay(0.2, function()
			sendCombatState(player)
		end)
	end)

	if player.Character then
		attachCharacterSignals(player, player.Character)
		task.delay(0.2, function()
			sendCombatState(player)
		end)
	end
end

local function cleanupPlayer(player)
	stateByPlayer[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

combatActionEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "shoot" then
		handleShoot(player, payload)
		return
	end

	if action == "reload" then
		handleReload(player)
		return
	end

	if action == "swing" then
		handleSwordSwing(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(combatConfig.Pickups.SpawnInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			spawnAmmoPickupForPlayer(player)
		end
	end
end)
