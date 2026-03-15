local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local OPEN_DIALOG_EVENT_NAME = "OpenNpcDialog"
local DIALOG_CHOICE_EVENT_NAME = "NpcDialogChoice"
local NPC_NAME = "Noob"
local DIALOG_TIMEOUT = 120

local function ensureIntStat(parent, name, defaultValue)
	local stat = parent:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		return stat
	end

	stat = Instance.new("IntValue")
	stat.Name = name
	stat.Value = defaultValue
	stat.Parent = parent
	return stat
end

local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	ensureIntStat(leaderstats, "Money", 0)
	ensureIntStat(leaderstats, "XP", 0)
	ensureIntStat(leaderstats, "Level", 1)
end

local function ensureProgression(player)
	local progression = player:FindFirstChild("Progression")
	if not progression then
		progression = Instance.new("Folder")
		progression.Name = "Progression"
		progression.Parent = player
	end

	ensureIntStat(progression, "SkillPoints", 0)
	ensureIntStat(progression, "SpeedLevel", 0)
	ensureIntStat(progression, "MeleeLevel", 0)
	ensureIntStat(progression, "RangedLevel", 0)
	ensureIntStat(progression, "HealthLevel", 0)
end

local openDialogEvent = ReplicatedStorage:FindFirstChild(OPEN_DIALOG_EVENT_NAME)
if not openDialogEvent then
	openDialogEvent = Instance.new("RemoteEvent")
	openDialogEvent.Name = OPEN_DIALOG_EVENT_NAME
	openDialogEvent.Parent = ReplicatedStorage
end

local dialogChoiceEvent = ReplicatedStorage:FindFirstChild(DIALOG_CHOICE_EVENT_NAME)
if not dialogChoiceEvent then
	dialogChoiceEvent = Instance.new("RemoteEvent")
	dialogChoiceEvent.Name = DIALOG_CHOICE_EVENT_NAME
	dialogChoiceEvent.Parent = ReplicatedStorage
end

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild("Money")
end

local function disableLegacyDialogGuiForPlayer(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local legacyGui = playerGui:FindFirstChild("NpcDialogGui")
	if legacyGui and legacyGui:IsA("ScreenGui") then
		legacyGui.Enabled = false
	end
end

local function disableLegacyDialogGuiTemplate()
	local legacyGui = StarterGui:FindFirstChild("NpcDialogGui")
	if legacyGui and legacyGui:IsA("ScreenGui") then
		legacyGui.Enabled = false

		local legacyClient = legacyGui:FindFirstChild("DialogClient")
		if legacyClient and legacyClient:IsA("LocalScript") then
			legacyClient.Disabled = true
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	ensureLeaderstats(player)
	ensureProgression(player)

	task.defer(function()
		disableLegacyDialogGuiForPlayer(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	ensureLeaderstats(player)
	ensureProgression(player)

	disableLegacyDialogGuiForPlayer(player)
end

disableLegacyDialogGuiTemplate()

local npc = workspace:FindFirstChild(NPC_NAME)
if not npc then
	warn(("[NPC] '%s' not found in Workspace"):format(NPC_NAME))
	return
end

local oldNpcServer = npc:FindFirstChild("NpcServer")
if oldNpcServer and oldNpcServer:IsA("Script") then
	oldNpcServer.Disabled = true
end

local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
if not prompt then
	local promptParent = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
	if not promptParent then
		warn("[NPC] No suitable part for ProximityPrompt")
		return
	end

	prompt = Instance.new("ProximityPrompt")
	prompt.Parent = promptParent
end

prompt.ActionText = "Поговорить"
prompt.ObjectText = "Noob"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12

local activeDialog = {}

prompt.Triggered:Connect(function(player)
	activeDialog[player] = os.clock()

	openDialogEvent:FireClient(player, {
		mode = "open",
		npcName = "Noob",
		text = "Чего ты хочешь?",
		choices = {
			{ id = "want_money", text = "Хочу деньги" },
			{ id = "leave", text = "Уйти" },
		},
	})
end)

dialogChoiceEvent.OnServerEvent:Connect(function(player, choiceId)
	if choiceId == "leave" then
		activeDialog[player] = nil
		openDialogEvent:FireClient(player, {
			mode = "close",
		})
		return
	end

	local startedAt = activeDialog[player]
	if not startedAt then
		return
	end

	if os.clock() - startedAt > DIALOG_TIMEOUT then
		activeDialog[player] = nil
		openDialogEvent:FireClient(player, {
			mode = "close",
		})
		return
	end

	if choiceId == "want_money" then
		local money = getMoneyValue(player)
		if not money then
			return
		end

		money.Value += 100
		activeDialog[player] = nil

		openDialogEvent:FireClient(player, {
			mode = "response",
			npcName = "Noob",
			text = ("Держи 100$. Сейчас у тебя %d$."):format(money.Value),
			choices = {
				{ id = "leave", text = "Уйти" },
			},
		})
		return
	end

end)

Players.PlayerRemoving:Connect(function(player)
	activeDialog[player] = nil
end)
