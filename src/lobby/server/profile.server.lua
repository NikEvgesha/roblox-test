local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local profileStore = require(sharedFolder:WaitForChild("ProfileStore"))

profileStore.StartAutoSave()

local function onPlayerAdded(player)
	profileStore.Load(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	profileStore.Unload(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		profileStore.Unload(player)
	end
	task.wait(2)
end)
