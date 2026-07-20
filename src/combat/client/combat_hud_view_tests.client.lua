local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("CombatHudViewTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("CombatHudViewTestsPassed", ok)
workspace:SetAttribute("CombatHudViewTestAssertions", ok and result or 0)

if ok then
	print(("[CombatHudViewTests] Passed %d assertions."):format(result))
else
	warn("[CombatHudViewTests] FAILED:", result)
end
