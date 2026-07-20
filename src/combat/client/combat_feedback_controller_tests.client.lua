local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("CombatFeedbackControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("CombatFeedbackControllerTestsPassed", ok)
workspace:SetAttribute("CombatFeedbackControllerTestAssertions", ok and result or 0)

if ok then
	print(("[CombatFeedbackControllerTests] Passed %d assertions."):format(result))
else
	warn("[CombatFeedbackControllerTests] FAILED:", result)
end
