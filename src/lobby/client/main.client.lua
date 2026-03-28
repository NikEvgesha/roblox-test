local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QUEUE_EVENT_NAME = "LobbyQueueEvent"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local queueEvent = ReplicatedStorage:WaitForChild(QUEUE_EVENT_NAME)

local lobbyState = {
	queue = nil,
	pads = {},
	difficulties = { "Easy", "Medium", "Hard", "Insane" },
	defaultDifficulty = "Medium",
	maxPartySize = 6,
}

local difficultyButtons = {}
local currentNoticeToken = 0

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyQueueGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(1, 0)
root.Position = UDim2.fromScale(0.985, 0.03)
root.Size = UDim2.fromOffset(420, 390)
root.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
root.BackgroundTransparency = 0.16
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 12)
rootCorner.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.Parent = root

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, 0, 0, 28)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(244, 244, 244)
titleLabel.Text = "Lobby Queue"
titleLabel.Parent = root

local queueLabel = Instance.new("TextLabel")
queueLabel.BackgroundTransparency = 1
queueLabel.Position = UDim2.fromOffset(0, 34)
queueLabel.Size = UDim2.new(1, 0, 0, 52)
queueLabel.Font = Enum.Font.Gotham
queueLabel.TextSize = 14
queueLabel.TextXAlignment = Enum.TextXAlignment.Left
queueLabel.TextYAlignment = Enum.TextYAlignment.Top
queueLabel.TextWrapped = true
queueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
queueLabel.Text = "Step on a queue pad to create or join queue."
queueLabel.Parent = root

local membersLabel = Instance.new("TextLabel")
membersLabel.BackgroundTransparency = 1
membersLabel.Position = UDim2.fromOffset(0, 90)
membersLabel.Size = UDim2.new(1, 0, 0, 86)
membersLabel.Font = Enum.Font.Gotham
membersLabel.TextSize = 14
membersLabel.TextXAlignment = Enum.TextXAlignment.Left
membersLabel.TextYAlignment = Enum.TextYAlignment.Top
membersLabel.TextWrapped = true
membersLabel.TextColor3 = Color3.fromRGB(206, 206, 206)
membersLabel.Text = "Members: -"
membersLabel.Parent = root

local difficultyTitle = Instance.new("TextLabel")
difficultyTitle.BackgroundTransparency = 1
difficultyTitle.Position = UDim2.fromOffset(0, 180)
difficultyTitle.Size = UDim2.new(1, 0, 0, 20)
difficultyTitle.Font = Enum.Font.GothamBold
difficultyTitle.TextSize = 14
difficultyTitle.TextXAlignment = Enum.TextXAlignment.Left
difficultyTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
difficultyTitle.Text = "Difficulty"
difficultyTitle.Parent = root

local difficultyFrame = Instance.new("Frame")
difficultyFrame.BackgroundTransparency = 1
difficultyFrame.Position = UDim2.fromOffset(0, 204)
difficultyFrame.Size = UDim2.new(1, 0, 0, 38)
difficultyFrame.Parent = root

local difficultyLayout = Instance.new("UIListLayout")
difficultyLayout.FillDirection = Enum.FillDirection.Horizontal
difficultyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
difficultyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
difficultyLayout.Padding = UDim.new(0, 8)
difficultyLayout.Parent = difficultyFrame

local partyTitle = Instance.new("TextLabel")
partyTitle.BackgroundTransparency = 1
partyTitle.Position = UDim2.fromOffset(0, 246)
partyTitle.Size = UDim2.new(1, 0, 0, 20)
partyTitle.Font = Enum.Font.GothamBold
partyTitle.TextSize = 14
partyTitle.TextXAlignment = Enum.TextXAlignment.Left
partyTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
partyTitle.Text = "Party Size"
partyTitle.Parent = root

local partyRow = Instance.new("Frame")
partyRow.BackgroundTransparency = 1
partyRow.Position = UDim2.fromOffset(0, 268)
partyRow.Size = UDim2.new(1, 0, 0, 36)
partyRow.Parent = root

local minusButton = Instance.new("TextButton")
minusButton.Size = UDim2.fromOffset(36, 32)
minusButton.Position = UDim2.fromOffset(0, 2)
minusButton.BackgroundColor3 = Color3.fromRGB(67, 76, 88)
minusButton.TextColor3 = Color3.fromRGB(245, 245, 245)
minusButton.Font = Enum.Font.GothamBold
minusButton.TextSize = 20
minusButton.Text = "-"
minusButton.Parent = partyRow

local minusCorner = Instance.new("UICorner")
minusCorner.CornerRadius = UDim.new(0, 8)
minusCorner.Parent = minusButton

local partySizeLabel = Instance.new("TextLabel")
partySizeLabel.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
partySizeLabel.Position = UDim2.fromOffset(44, 2)
partySizeLabel.Size = UDim2.fromOffset(86, 32)
partySizeLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
partySizeLabel.Font = Enum.Font.GothamBold
partySizeLabel.TextSize = 16
partySizeLabel.Text = "-"
partySizeLabel.Parent = partyRow

local partyCorner = Instance.new("UICorner")
partyCorner.CornerRadius = UDim.new(0, 8)
partyCorner.Parent = partySizeLabel

local plusButton = Instance.new("TextButton")
plusButton.Size = UDim2.fromOffset(36, 32)
plusButton.Position = UDim2.fromOffset(138, 2)
plusButton.BackgroundColor3 = Color3.fromRGB(67, 76, 88)
plusButton.TextColor3 = Color3.fromRGB(245, 245, 245)
plusButton.Font = Enum.Font.GothamBold
plusButton.TextSize = 20
plusButton.Text = "+"
plusButton.Parent = partyRow

local plusCorner = Instance.new("UICorner")
plusCorner.CornerRadius = UDim.new(0, 8)
plusCorner.Parent = plusButton

local actionRow = Instance.new("Frame")
actionRow.BackgroundTransparency = 1
actionRow.Position = UDim2.fromOffset(0, 312)
actionRow.Size = UDim2.new(1, 0, 0, 36)
actionRow.Parent = root

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.fromOffset(160, 34)
startButton.Position = UDim2.fromOffset(0, 0)
startButton.BackgroundColor3 = Color3.fromRGB(66, 130, 86)
startButton.TextColor3 = Color3.fromRGB(245, 245, 245)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 14
startButton.Text = "Start"
startButton.Parent = actionRow

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 8)
startCorner.Parent = startButton

local leaveButton = Instance.new("TextButton")
leaveButton.Size = UDim2.fromOffset(160, 34)
leaveButton.Position = UDim2.fromOffset(170, 0)
leaveButton.BackgroundColor3 = Color3.fromRGB(128, 72, 72)
leaveButton.TextColor3 = Color3.fromRGB(245, 245, 245)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 14
leaveButton.Text = "Leave Queue"
leaveButton.Parent = actionRow

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 8)
leaveCorner.Parent = leaveButton

local noticeLabel = Instance.new("TextLabel")
noticeLabel.BackgroundTransparency = 1
noticeLabel.Position = UDim2.fromOffset(0, 350)
noticeLabel.Size = UDim2.new(1, 0, 0, 24)
noticeLabel.Font = Enum.Font.Gotham
noticeLabel.TextSize = 13
noticeLabel.TextXAlignment = Enum.TextXAlignment.Left
noticeLabel.TextColor3 = Color3.fromRGB(255, 212, 144)
noticeLabel.Text = ""
noticeLabel.Parent = root

local padsLabel = Instance.new("TextLabel")
padsLabel.BackgroundTransparency = 1
padsLabel.Position = UDim2.fromOffset(230, 246)
padsLabel.Size = UDim2.new(1, -230, 0, 58)
padsLabel.Font = Enum.Font.Gotham
padsLabel.TextSize = 12
padsLabel.TextXAlignment = Enum.TextXAlignment.Left
padsLabel.TextYAlignment = Enum.TextYAlignment.Top
padsLabel.TextWrapped = true
padsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
padsLabel.Text = ""
padsLabel.Parent = root

local function fireQueueAction(payload)
	if typeof(payload) == "table" then
		queueEvent:FireServer(payload)
	end
end

local function setNotice(text)
	currentNoticeToken += 1
	local token = currentNoticeToken
	noticeLabel.Text = type(text) == "string" and text or ""
	if noticeLabel.Text == "" then
		return
	end

	task.delay(5, function()
		if currentNoticeToken == token then
			noticeLabel.Text = ""
		end
	end)
end

local function clearDifficultyButtons()
	for _, button in pairs(difficultyButtons) do
		if button and button.Parent then
			button:Destroy()
		end
	end
	table.clear(difficultyButtons)
end

local function rebuildDifficultyButtons()
	clearDifficultyButtons()

	for _, difficulty in ipairs(lobbyState.difficulties) do
		local button = Instance.new("TextButton")
		button.Name = difficulty
		button.Size = UDim2.fromOffset(92, 34)
		button.BackgroundColor3 = Color3.fromRGB(59, 70, 92)
		button.TextColor3 = Color3.fromRGB(245, 245, 245)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.Text = difficulty
		button.Parent = difficultyFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			fireQueueAction({
				action = "set_difficulty",
				difficulty = difficulty,
			})
		end)

		difficultyButtons[difficulty] = button
	end
end

local function render()
	local queue = lobbyState.queue
	local inQueue = queue ~= nil
	local isHost = inQueue and queue.hostUserId == player.UserId
	local selectedDifficulty = (inQueue and queue.difficulty) or lobbyState.defaultDifficulty

	if inQueue then
		queueLabel.Text = ("Pad: %s | Host: %s\nQueue: %d/%d | Difficulty: %s")
			:format(
				queue.padName or "-",
				queue.hostName or "-",
				tonumber(queue.memberCount) or 0,
				tonumber(queue.targetSize) or 0,
				selectedDifficulty
			)

		local memberLines = {}
		for _, member in ipairs(queue.members or {}) do
			local suffix = member.userId == queue.hostUserId and " (Host)" or ""
			table.insert(memberLines, ("- %s%s"):format(member.name or "Player", suffix))
		end
		membersLabel.Text = "Members:\n" .. (#memberLines > 0 and table.concat(memberLines, "\n") or "-")

		partySizeLabel.Text = tostring(queue.targetSize or "-")
	else
		queueLabel.Text = "Step on a queue pad to create or join queue."
		membersLabel.Text = "Members: -"
		partySizeLabel.Text = "-"
	end

	for difficulty, button in pairs(difficultyButtons) do
		local isSelected = difficulty == selectedDifficulty
		button.BackgroundColor3 = isSelected and Color3.fromRGB(90, 135, 95) or Color3.fromRGB(59, 70, 92)
		button.AutoButtonColor = isHost == true
		button.Active = isHost == true
		button.TextTransparency = isHost and 0 or 0.25
	end

	minusButton.Active = isHost == true
	minusButton.AutoButtonColor = isHost == true
	minusButton.TextTransparency = isHost and 0 or 0.35

	plusButton.Active = isHost == true
	plusButton.AutoButtonColor = isHost == true
	plusButton.TextTransparency = isHost and 0 or 0.35

	startButton.Active = isHost == true
	startButton.AutoButtonColor = isHost == true
	startButton.TextTransparency = isHost and 0 or 0.35

	leaveButton.Active = inQueue
	leaveButton.AutoButtonColor = inQueue
	leaveButton.TextTransparency = inQueue and 0 or 0.35

	local padLines = {}
	for _, pad in ipairs(lobbyState.pads or {}) do
		local memberCount = tonumber(pad.memberCount) or 0
		if memberCount <= 0 then
			table.insert(padLines, ("%s: idle"):format(pad.name or "Pad"))
		else
			local status = pad.launching and "launching" or "waiting"
			table.insert(
				padLines,
				("%s: %d/%d %s (%s)"):format(
					pad.name or "Pad",
					memberCount,
					tonumber(pad.targetSize) or 0,
					pad.difficulty or lobbyState.defaultDifficulty,
					status
				)
			)
		end
	end
	padsLabel.Text = (#padLines > 0 and table.concat(padLines, "\n")) or ""
end

local function applyState(data)
	if typeof(data.queue) == "table" then
		lobbyState.queue = data.queue
	else
		lobbyState.queue = nil
	end

	if typeof(data.pads) == "table" then
		lobbyState.pads = data.pads
	else
		lobbyState.pads = {}
	end

	local difficultiesChanged = false
	if typeof(data.difficulties) == "table" and #data.difficulties > 0 then
		lobbyState.difficulties = data.difficulties
		difficultiesChanged = true
	end

	if type(data.defaultDifficulty) == "string" and data.defaultDifficulty ~= "" then
		lobbyState.defaultDifficulty = data.defaultDifficulty
	end

	if type(data.maxPartySize) == "number" then
		lobbyState.maxPartySize = math.max(1, math.floor(data.maxPartySize))
	end

	if difficultiesChanged then
		rebuildDifficultyButtons()
	end

	render()
end

minusButton.MouseButton1Click:Connect(function()
	local queue = lobbyState.queue
	if not queue then
		return
	end

	if queue.hostUserId ~= player.UserId then
		return
	end

	local current = math.floor(tonumber(queue.targetSize) or 1)
	local nextSize = math.max(1, current - 1)
	fireQueueAction({
		action = "set_party_size",
		partySize = nextSize,
	})
end)

plusButton.MouseButton1Click:Connect(function()
	local queue = lobbyState.queue
	if not queue then
		return
	end

	if queue.hostUserId ~= player.UserId then
		return
	end

	local current = math.floor(tonumber(queue.targetSize) or 1)
	local nextSize = math.min(lobbyState.maxPartySize, current + 1)
	fireQueueAction({
		action = "set_party_size",
		partySize = nextSize,
	})
end)

startButton.MouseButton1Click:Connect(function()
	fireQueueAction({ action = "start" })
end)

leaveButton.MouseButton1Click:Connect(function()
	fireQueueAction({ action = "leave" })
end)

queueEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if data.type == "notice" then
		setNotice(data.text)
		return
	end

	if data.type == "state" then
		applyState(data)
		return
	end
end)

rebuildDifficultyButtons()
render()
fireQueueAction({ action = "request_state" })
