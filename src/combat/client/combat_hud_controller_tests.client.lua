local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("CombatHudControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("CombatHudControllerTestsPassed", ok)
workspace:SetAttribute("CombatHudControllerTestAssertions", ok and result or 0)

if ok then
	print(("[CombatHudControllerTests] Passed %d assertions."):format(result))
else
	warn("[CombatHudControllerTests] FAILED:", result)
end
