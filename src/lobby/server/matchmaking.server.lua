local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local QUEUE_EVENT_NAME = "LobbyQueueEvent"
local QUEUE_PADS_FOLDER_NAME = "QueuePads"
local DEFAULT_DIFFICULTY_ORDER = { "Easy", "Medium", "Hard", "Insane" }

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local profileStore = require(sharedFolder:WaitForChild("ProfileStore"))
local zombieConfig = combatConfig.Zombies or {}
local lobbyConfig = combatConfig.Lobby or {}
local classesConfig = combatConfig.Classes or {}
local classDefinitions = classesConfig.Definitions or {}
local classOrder = classesConfig.Order or { "Assault", "Builder", "Healer", "Melee" }

local COMBAT_PLACE_ID = tonumber(lobbyConfig.CombatPlaceId) or 0
local MAX_PARTY_SIZE = math.max(1, math.floor(tonumber(lobbyConfig.MaxPartySize) or 6))
local DEFAULT_PARTY_SIZE = math.clamp(math.floor(tonumber(lobbyConfig.DefaultPartySize) or 2), 1, MAX_PARTY_SIZE)
local DEFAULT_PAD_COUNT = math.max(1, math.floor(tonumber(lobbyConfig.DefaultPadCount) or 2))
local TOUCH_DEBOUNCE_SECONDS = math.max(0.15, tonumber(lobbyConfig.QueueTouchDebounceSeconds) or 1.0)

local difficultyConfig = zombieConfig.Difficulties or {}
local defaultDifficulty = zombieConfig.DefaultDifficulty or "Medium"

local function resolveDefaultClassKey()
	local requested = classesConfig.DefaultClass
	if type(requested) == "string" and classDefinitions[requested] then
		return requested
	end

	for _, classKey in ipairs(classOrder) do
		if classDefinitions[classKey] then
			return classKey
		end
	end

	for classKey in pairs(classDefinitions) do
		return classKey
	end

	return "Assault"
end

local defaultClassKey = resolveDefaultClassKey()

local function normalizeClassKey(classKey)
	if type(classKey) == "string" and classDefinitions[classKey] then
		return classKey
	end
	return defaultClassKey
end

local function buildClassOrder()
	local order = {}
	local seen = {}

	for _, classKey in ipairs(classOrder) do
		if classDefinitions[classKey] then
			table.insert(order, classKey)
			seen[classKey] = true
		end
	end

	local extras = {}
	for classKey in pairs(classDefinitions) do
		if not seen[classKey] then
			table.insert(extras, classKey)
		end
	end
	table.sort(extras)
	for _, classKey in ipairs(extras) do
		table.insert(order, classKey)
	end

	if #order == 0 then
		table.insert(order, defaultClassKey)
	end

	return order
end

local classKeyOrder = buildClassOrder()

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

local queueEvent = ensureRemoteEvent(QUEUE_EVENT_NAME)

local function ensureFolder(name)
	local folder = Workspace:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local queuePadsFolder = ensureFolder(QUEUE_PADS_FOLDER_NAME)

local function buildDifficultyOrder()
	local order = {}
	local seen = {}

	for _, key in ipairs(DEFAULT_DIFFICULTY_ORDER) do
		if difficultyConfig[key] then
			table.insert(order, key)
			seen[key] = true
		end
	end

	local extras = {}
	for key in pairs(difficultyConfig) do
		if not seen[key] then
			table.insert(extras, key)
		end
	end
	table.sort(extras)

	for _, key in ipairs(extras) do
		table.insert(order, key)
	end

	if #order == 0 then
		table.insert(order, defaultDifficulty)
	end

	if not difficultyConfig[defaultDifficulty] then
		defaultDifficulty = order[1]
	end

	return order
end

local difficultyOrder = buildDifficultyOrder()

local function ensureQueuePadPrompt(pad)
	local prompt = pad:FindFirstChild("QueueJoinPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueueJoinPrompt"
	prompt.ActionText = "Join Queue"
	prompt.ObjectText = pad.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	return prompt
end

local function ensureQueuePadBillboard(pad)
	local billboard = pad:FindFirstChild("QueueBillboard")
	if not (billboard and billboard:IsA("BillboardGui")) then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "QueueBillboard"
		billboard.Size = UDim2.fromOffset(280, 112)
		billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 150
		billboard.Parent = pad
	end

	local label = billboard:FindFirstChild("Label")
	if not (label and label:IsA("TextLabel")) then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.fromRGB(244, 244, 244)
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.Text = ""
		label.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end

	return label
end

local function createDefaultQueuePad(index)
	local pad = Instance.new("Part")
	pad.Name = ("QueuePad_%d"):format(index)
	pad.Size = Vector3.new(12, 1, 12)
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanTouch = true
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(74, 109, 160)
	pad.Position = Vector3.new((index - 1) * 18, 2.5, -24)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = queuePadsFolder

	return pad
end

local function getQueuePads()
	local pads = {}
	for _, child in ipairs(queuePadsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(pads, child)
		end
	end

	if #pads == 0 then
		for index = 1, DEFAULT_PAD_COUNT do
			table.insert(pads, createDefaultQueuePad(index))
		end
	end

	table.sort(pads, function(a, b)
		return a.Name < b.Name
	end)

	return pads
end

local queuePads = getQueuePads()

local queueByPad = {}
local queueByPlayer = {}
local touchDebounceByPlayer = {}

local function countActiveQueues()
	local count = 0
	for _ in pairs(queueByPad) do
		count += 1
	end
	return count
end

local function publishLobbyQueueAttributes()
	Workspace:SetAttribute("LobbyQueueCount", countActiveQueues())
	Workspace:SetAttribute("LobbyQueueMaxParty", MAX_PARTY_SIZE)
	Workspace:SetAttribute("LobbyCombatPlaceId", COMBAT_PLACE_ID)
end

local function ensureStringValue(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)
	if value and value:IsA("StringValue") then
		return value
	end

	value = Instance.new("StringValue")
	value.Name = name
	value.Value = defaultValue
	value.Parent = parent
	return value
end

local function getSelectedClassValueObject(player, createIfMissing)
	local metaProgression = player:FindFirstChild("MetaProgression")
	if not metaProgression and createIfMissing then
		metaProgression = Instance.new("Folder")
		metaProgression.Name = "MetaProgression"
		metaProgression.Parent = player
	end

	if not metaProgression then
		return nil
	end

	local selectedClass = metaProgression:FindFirstChild("SelectedClass")
	if selectedClass and selectedClass:IsA("StringValue") then
		return selectedClass
	end

	if createIfMissing then
		return ensureStringValue(metaProgression, "SelectedClass", defaultClassKey)
	end

	return nil
end

local function getSelectedClassForPlayer(player)
	local value = getSelectedClassValueObject(player, false)
	if value then
		return normalizeClassKey(value.Value)
	end
	return defaultClassKey
end

local function setSelectedClassForPlayer(player, classKey)
	local normalized = normalizeClassKey(classKey)
	local value = getSelectedClassValueObject(player, true)
	if not value then
		return normalized
	end

	if value.Value ~= normalized then
		value.Value = normalized
		profileStore.MarkDirty(player)
	end

	player:SetAttribute("SelectedClass", normalized)
	return normalized
end

local function sendNotice(player, text)
	if not player or player.Parent ~= Players then
		return
	end

	if type(text) ~= "string" or text == "" then
		return
	end

	queueEvent:FireClient(player, {
		type = "notice",
		text = text,
	})
end

local function serializeQueue(queue)
	if not queue then
		return nil
	end

	local members = {}
	for _, member in ipairs(queue.members) do
		if member and member.Parent == Players then
			table.insert(members, {
				userId = member.UserId,
				name = member.Name,
			})
		end
	end

	return {
		padName = queue.pad.Name,
		hostUserId = queue.host and queue.host.UserId or 0,
		hostName = queue.host and queue.host.Name or "",
		difficulty = queue.difficulty,
		targetSize = queue.targetSize,
		memberCount = #members,
		launching = queue.launching == true,
		members = members,
	}
end

local function serializePads()
	local pads = {}
	for _, pad in ipairs(queuePads) do
		local queue = queueByPad[pad]
		local memberCount = 0
		local targetSize = 0
		local difficulty = defaultDifficulty
		local launching = false

		if queue then
			memberCount = #queue.members
			targetSize = queue.targetSize
			difficulty = queue.difficulty
			launching = queue.launching == true
		end

		table.insert(pads, {
			name = pad.Name,
			memberCount = memberCount,
			targetSize = targetSize,
			difficulty = difficulty,
			launching = launching,
		})
	end

	return pads
end

local function sendQueueState(player)
	if not player or player.Parent ~= Players then
		return
	end

	local classDisplayNames = {}
	for _, classKey in ipairs(classKeyOrder) do
		local classDef = classDefinitions[classKey] or {}
		classDisplayNames[classKey] = classDef.DisplayName or classKey
	end

	queueEvent:FireClient(player, {
		type = "state",
		queue = serializeQueue(queueByPlayer[player]),
		pads = serializePads(),
		difficulties = difficultyOrder,
		classes = classKeyOrder,
		classDisplayNames = classDisplayNames,
		selectedClass = getSelectedClassForPlayer(player),
		defaultClass = defaultClassKey,
		defaultDifficulty = defaultDifficulty,
		maxPartySize = MAX_PARTY_SIZE,
		combatPlaceId = COMBAT_PLACE_ID,
	})
end

local function refreshAllQueueStates()
	for _, player in ipairs(Players:GetPlayers()) do
		sendQueueState(player)
	end
end

local function updatePadBillboard(pad)
	local queue = queueByPad[pad]
	local label = ensureQueuePadBillboard(pad)
	if not queue then
		label.Text = ("%s\nStep here or use prompt\nto create a queue"):format(pad.Name)
		pad.Color = Color3.fromRGB(74, 109, 160)
		return
	end

	local status = queue.launching and "Launching" or "Waiting"
	label.Text = (
		"%s\nHost: %s\nPlayers: %d/%d\nDifficulty: %s\nStatus: %s"
	):format(
		pad.Name,
		queue.host and queue.host.Name or "-",
		#queue.members,
		queue.targetSize,
		queue.difficulty,
		status
	)

	if queue.launching then
		pad.Color = Color3.fromRGB(123, 170, 91)
	else
		pad.Color = Color3.fromRGB(74, 109, 160)
	end
end

local function updateAllPadBillboards()
	for _, pad in ipairs(queuePads) do
		updatePadBillboard(pad)
	end
end

local function sanitizeQueue(queue)
	if not queue then
		return
	end

	for index = #queue.members, 1, -1 do
		local member = queue.members[index]
		if not member or member.Parent ~= Players then
			if member then
				queueByPlayer[member] = nil
			end
			table.remove(queue.members, index)
		end
	end

	if queue.host and queue.host.Parent ~= Players then
		queue.host = nil
	end

	if not queue.host then
		queue.host = queue.members[1]
	end

	queue.targetSize = math.clamp(math.floor(tonumber(queue.targetSize) or DEFAULT_PARTY_SIZE), 1, MAX_PARTY_SIZE)
	if queue.targetSize < #queue.members then
		queue.targetSize = #queue.members
	end
end

local function getConnectedMembers(queue)
	sanitizeQueue(queue)
	local connected = {}
	for _, member in ipairs(queue.members) do
		if member and member.Parent == Players then
			table.insert(connected, member)
		end
	end
	return connected
end

local function removePlayerFromQueue(player)
	local queue = queueByPlayer[player]
	if not queue then
		return
	end

	queueByPlayer[player] = nil

	for index = #queue.members, 1, -1 do
		if queue.members[index] == player then
			table.remove(queue.members, index)
			break
		end
	end

	if queue.host == player then
		queue.host = nil
	end

	sanitizeQueue(queue)

	if #queue.members <= 0 then
		queueByPad[queue.pad] = nil
	end

	updatePadBillboard(queue.pad)
	publishLobbyQueueAttributes()
	refreshAllQueueStates()
end

local function createQueueForPad(pad, host)
	local queue = {
		pad = pad,
		host = host,
		members = { host },
		difficulty = defaultDifficulty,
		targetSize = DEFAULT_PARTY_SIZE,
		launching = false,
	}

	sanitizeQueue(queue)
	queueByPad[pad] = queue
	queueByPlayer[host] = queue

	updatePadBillboard(pad)
	publishLobbyQueueAttributes()
	refreshAllQueueStates()
	return queue
end

local function notifyQueueMembers(queue, text)
	for _, member in ipairs(getConnectedMembers(queue)) do
		sendNotice(member, text)
	end
end

local function launchQueue(queue, autoTriggered)
	if not queue or queue.launching then
		return
	end

	local members = getConnectedMembers(queue)
	if #members <= 0 then
		queueByPad[queue.pad] = nil
		updatePadBillboard(queue.pad)
		publishLobbyQueueAttributes()
		refreshAllQueueStates()
		return
	end

	if COMBAT_PLACE_ID <= 0 then
		notifyQueueMembers(queue, "Combat place id is not configured.")
		refreshAllQueueStates()
		return
	end

	for _, member in ipairs(members) do
		if member:GetAttribute("PersistentProfileLoaded") ~= true then
			sendNotice(member, "Profile is still loading. Please wait a moment.")
			refreshAllQueueStates()
			return
		end
	end

	if RunService:IsStudio() then
		if autoTriggered then
			notifyQueueMembers(queue, "Queue is full. Studio mode: teleport skipped.")
		else
			notifyQueueMembers(queue, "Studio mode: teleport skipped.")
		end
		refreshAllQueueStates()
		return
	end

	queue.launching = true
	updatePadBillboard(queue.pad)
	refreshAllQueueStates()

	if autoTriggered then
		notifyQueueMembers(queue, "Queue is full. Launching run...")
	else
		notifyQueueMembers(queue, "Host started run. Teleporting...")
	end

	local selectedClassByUserId = {}
	for _, member in ipairs(members) do
		selectedClassByUserId[tostring(member.UserId)] = getSelectedClassForPlayer(member)
	end

	local teleportData = {
		difficulty = queue.difficulty,
		targetPartySize = queue.targetSize,
		hostUserId = queue.host and queue.host.UserId or 0,
		selectedClassByUserId = selectedClassByUserId,
		source = "LobbyQueue",
	}

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData(teleportData)

	local okReserve, reserveCodeOrError = pcall(function()
		return TeleportService:ReserveServer(COMBAT_PLACE_ID)
	end)
	if okReserve and type(reserveCodeOrError) == "string" and reserveCodeOrError ~= "" then
		teleportOptions.ReservedServerAccessCode = reserveCodeOrError
	else
		warn("[LobbyQueue] ReserveServer failed:", reserveCodeOrError)
	end

	local okTeleport, teleportError = pcall(function()
		TeleportService:TeleportAsync(COMBAT_PLACE_ID, members, teleportOptions)
	end)

	if not okTeleport then
		warn("[LobbyQueue] TeleportAsync failed:", teleportError)
		queue.launching = false
		updatePadBillboard(queue.pad)
		refreshAllQueueStates()
		notifyQueueMembers(queue, "Teleport failed. Please try Start again.")
		return
	end

	task.delay(10, function()
		local current = queueByPad[queue.pad]
		if current ~= queue then
			return
		end

		if #queue.members > 0 then
			queue.launching = false
			updatePadBillboard(queue.pad)
			refreshAllQueueStates()
		end
	end)
end

local function joinQueueViaPad(player, pad)
	if not player or player.Parent ~= Players then
		return
	end

	if not table.find(queuePads, pad) then
		return
	end

	local currentQueue = queueByPlayer[player]
	if currentQueue and currentQueue.pad == pad then
		sendNotice(player, "You are already in this queue.")
		return
	end

	if currentQueue then
		removePlayerFromQueue(player)
	end

	local queue = queueByPad[pad]
	if not queue then
		createQueueForPad(pad, player)
		sendNotice(player, "Queue created. Choose settings and press Start.")
		return
	end

	sanitizeQueue(queue)
	if queue.launching then
		sendNotice(player, "Queue is launching now. Try another pad.")
		refreshAllQueueStates()
		return
	end

	if #queue.members >= queue.targetSize then
		sendNotice(player, "Queue is full.")
		refreshAllQueueStates()
		return
	end

	table.insert(queue.members, player)
	queueByPlayer[player] = queue
	sanitizeQueue(queue)

	updatePadBillboard(queue.pad)
	publishLobbyQueueAttributes()
	refreshAllQueueStates()
	sendNotice(player, ("Joined %s."):format(queue.pad.Name))

	if #queue.members >= queue.targetSize then
		launchQueue(queue, true)
	end
end

local function onQueueAction(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local action = payload.action
	if type(action) ~= "string" then
		return
	end

	if action == "request_state" then
		sendQueueState(player)
		return
	end

	if action == "leave" then
		removePlayerFromQueue(player)
		sendNotice(player, "You left the queue.")
		return
	end

	if action == "set_class" then
		if player:GetAttribute("PersistentProfileLoaded") ~= true then
			sendNotice(player, "Profile is loading. Try again in a moment.")
			return
		end

		local requestedClass = tostring(payload.classKey or "")
		local normalized = setSelectedClassForPlayer(player, requestedClass)
		sendNotice(player, ("Class selected: %s"):format((classDefinitions[normalized] and classDefinitions[normalized].DisplayName) or normalized))
		sendQueueState(player)
		return
	end

	local queue = queueByPlayer[player]
	if not queue then
		sendNotice(player, "Join a queue pad first.")
		return
	end

	if queue.host ~= player then
		sendNotice(player, "Only host can change queue settings.")
		return
	end

	if action == "set_difficulty" then
		local requested = tostring(payload.difficulty or "")
		if requested == "" or not difficultyConfig[requested] then
			sendNotice(player, "Unknown difficulty.")
			return
		end

		queue.difficulty = requested
		updatePadBillboard(queue.pad)
		refreshAllQueueStates()
		notifyQueueMembers(queue, ("Difficulty set to %s."):format(requested))
		return
	end

	if action == "set_party_size" then
		local requested = math.floor(tonumber(payload.partySize) or queue.targetSize)
		local clamped = math.clamp(requested, 1, MAX_PARTY_SIZE)
		if clamped < #queue.members then
			clamped = #queue.members
		end

		queue.targetSize = clamped
		updatePadBillboard(queue.pad)
		refreshAllQueueStates()
		notifyQueueMembers(queue, ("Party size set to %d."):format(clamped))

		if #queue.members >= queue.targetSize then
			launchQueue(queue, true)
		end
		return
	end

	if action == "start" then
		launchQueue(queue, false)
	end
end

for _, pad in ipairs(queuePads) do
	ensureQueuePadPrompt(pad)
	ensureQueuePadBillboard(pad)
	updatePadBillboard(pad)

	pad.Touched:Connect(function(hit)
		local character = hit and hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		local byPad = touchDebounceByPlayer[player]
		if not byPad then
			byPad = {}
			touchDebounceByPlayer[player] = byPad
		end

		local last = byPad[pad]
		if last and (now - last) < TOUCH_DEBOUNCE_SECONDS then
			return
		end

		byPad[pad] = now
		joinQueueViaPad(player, pad)
	end)

	local prompt = ensureQueuePadPrompt(pad)
	prompt.Triggered:Connect(function(player)
		joinQueueViaPad(player, pad)
	end)
end

queueEvent.OnServerEvent:Connect(onQueueAction)

Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("PersistentProfileLoaded"):Connect(function()
		sendQueueState(player)
	end)

	task.defer(function()
		local classKey = setSelectedClassForPlayer(player, getSelectedClassForPlayer(player))
		player:SetAttribute("SelectedClass", classKey)
		sendQueueState(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	touchDebounceByPlayer[player] = nil
	removePlayerFromQueue(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:GetAttributeChangedSignal("PersistentProfileLoaded"):Connect(function()
		sendQueueState(player)
	end)

	task.defer(function()
		local classKey = setSelectedClassForPlayer(player, getSelectedClassForPlayer(player))
		player:SetAttribute("SelectedClass", classKey)
		sendQueueState(player)
	end)
end

publishLobbyQueueAttributes()
updateAllPadBillboards()
Workspace:SetAttribute("LobbyQueueReady", true)
