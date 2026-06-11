local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MAP_RADIUS_STUDS = 180
local MAP_SIZE = 174
local MAP_PADDING = 12
local DOT_SIZE = 6
local MAX_ENEMY_DOTS = 90
local UPDATE_INTERVAL = 0.12

local gui = Instance.new("ScreenGui")
gui.Name = "CombatMinimapGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local rootFrame = Instance.new("Frame")
rootFrame.Name = "Minimap"
rootFrame.AnchorPoint = Vector2.new(1, 0)
rootFrame.Position = UDim2.new(1, -18, 0, 58)
rootFrame.Size = UDim2.fromOffset(MAP_SIZE, MAP_SIZE)
rootFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
rootFrame.BackgroundTransparency = 0.12
rootFrame.BorderSizePixel = 0
rootFrame.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = rootFrame

local rootStroke = Instance.new("UIStroke")
rootStroke.Color = Color3.fromRGB(84, 101, 118)
rootStroke.Transparency = 0.25
rootStroke.Thickness = 1
rootStroke.Parent = rootFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(10, 6)
title.Size = UDim2.new(1, -20, 0, 18)
title.Font = Enum.Font.GothamBold
title.Text = "Map"
title.TextColor3 = Color3.fromRGB(228, 234, 242)
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = rootFrame

local mapArea = Instance.new("Frame")
mapArea.Name = "MapArea"
mapArea.Position = UDim2.fromOffset(MAP_PADDING, 28)
mapArea.Size = UDim2.fromOffset(MAP_SIZE - MAP_PADDING * 2, MAP_SIZE - MAP_PADDING - 34)
mapArea.BackgroundColor3 = Color3.fromRGB(24, 29, 36)
mapArea.BackgroundTransparency = 0.1
mapArea.BorderSizePixel = 0
mapArea.ClipsDescendants = true
mapArea.Parent = rootFrame

local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(1, 0)
mapCorner.Parent = mapArea

local rangeRing = Instance.new("Frame")
rangeRing.Name = "RangeRing"
rangeRing.AnchorPoint = Vector2.new(0.5, 0.5)
rangeRing.Position = UDim2.fromScale(0.5, 0.5)
rangeRing.Size = UDim2.fromScale(0.94, 0.94)
rangeRing.BackgroundTransparency = 1
rangeRing.Parent = mapArea

local rangeStroke = Instance.new("UIStroke")
rangeStroke.Color = Color3.fromRGB(67, 81, 99)
rangeStroke.Transparency = 0.35
rangeStroke.Thickness = 1
rangeStroke.Parent = rangeRing

local playerDot = Instance.new("Frame")
playerDot.Name = "Player"
playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
playerDot.Position = UDim2.fromScale(0.5, 0.5)
playerDot.Size = UDim2.fromOffset(10, 10)
playerDot.BackgroundColor3 = Color3.fromRGB(103, 230, 255)
playerDot.BorderSizePixel = 0
playerDot.ZIndex = 4
playerDot.Parent = mapArea

local playerDotCorner = Instance.new("UICorner")
playerDotCorner.CornerRadius = UDim.new(1, 0)
playerDotCorner.Parent = playerDot

local forwardMarker = Instance.new("Frame")
forwardMarker.Name = "Forward"
forwardMarker.AnchorPoint = Vector2.new(0.5, 0.5)
forwardMarker.Position = UDim2.fromScale(0.5, 0.08)
forwardMarker.Size = UDim2.fromOffset(7, 7)
forwardMarker.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
forwardMarker.BorderSizePixel = 0
forwardMarker.ZIndex = 3
forwardMarker.Parent = mapArea

local forwardCorner = Instance.new("UICorner")
forwardCorner.CornerRadius = UDim.new(1, 0)
forwardCorner.Parent = forwardMarker

local enemyDots = table.create(MAX_ENEMY_DOTS)
for index = 1, MAX_ENEMY_DOTS do
	local dot = Instance.new("Frame")
	dot.Name = ("Enemy_%02d"):format(index)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.BackgroundColor3 = Color3.fromRGB(236, 76, 76)
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.ZIndex = 3
	dot.Parent = mapArea

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	enemyDots[index] = dot
end

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getEnemyRoot(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Head")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function setDotVisibleFrom(index)
	for dotIndex = index, MAX_ENEMY_DOTS do
		enemyDots[dotIndex].Visible = false
	end
end

local function updateMinimap()
	local characterRoot = getCharacterRoot()
	local zombiesFolder = Workspace:FindFirstChild("Zombies")
	if not characterRoot or not zombiesFolder then
		setDotVisibleFrom(1)
		return
	end

	local halfSize = mapArea.AbsoluteSize.X * 0.5
	if halfSize <= 0 then
		return
	end

	local forward = Vector3.new(characterRoot.CFrame.LookVector.X, 0, characterRoot.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local right = Vector3.new(forward.Z, 0, -forward.X)
	local dotIndex = 1

	for _, enemy in ipairs(zombiesFolder:GetChildren()) do
		if dotIndex > MAX_ENEMY_DOTS then
			break
		end

		if enemy:IsA("Model") then
			local enemyRoot = getEnemyRoot(enemy)
			if enemyRoot then
				local isBoss = enemy:GetAttribute("IsBossZombie") == true
				local offset = enemyRoot.Position - characterRoot.Position
				local planar = Vector3.new(offset.X, 0, offset.Z)
				local mapX = planar:Dot(right) / MAP_RADIUS_STUDS
				local mapY = planar:Dot(forward) / MAP_RADIUS_STUDS
				local distance = Vector2.new(mapX, mapY).Magnitude

				if distance > 1 then
					mapX /= distance
					mapY /= distance
				end

				local dot = enemyDots[dotIndex]
				if isBoss then
					dot.Size = UDim2.fromOffset(11, 11)
					dot.BackgroundColor3 = Color3.fromRGB(255, 163, 58)
					dot.ZIndex = 4
				else
					dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
					dot.BackgroundColor3 = Color3.fromRGB(236, 76, 76)
					dot.ZIndex = 3
				end
				dot.Position = UDim2.fromOffset(halfSize + mapX * halfSize * 0.88, halfSize - mapY * halfSize * 0.88)
				dot.BackgroundTransparency = distance > 1 and 0.25 or 0
				dot.Visible = true
				dotIndex += 1
			end
		end
	end

	setDotVisibleFrom(dotIndex)
end

local accumulated = 0
RunService.RenderStepped:Connect(function(deltaTime)
	accumulated += deltaTime
	if accumulated < UPDATE_INTERVAL then
		return
	end
	accumulated = 0
	updateMinimap()
end)
