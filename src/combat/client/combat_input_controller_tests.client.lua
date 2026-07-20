local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("CombatInputControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("CombatInputControllerTestsPassed", ok)
workspace:SetAttribute("CombatInputControllerTestAssertions", ok and result or 0)

if ok then
	print(("[CombatInputControllerTests] Passed %d assertions."):format(result))
else
	warn("[CombatInputControllerTests] FAILED:", result)
end
