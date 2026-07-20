local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("SpectatorControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("SpectatorControllerTestsPassed", ok)
workspace:SetAttribute("SpectatorControllerTestAssertions", ok and result or 0)

if ok then
	print(("[SpectatorControllerTests] Passed %d assertions."):format(result))
else
	warn("[SpectatorControllerTests] FAILED:", result)
end
