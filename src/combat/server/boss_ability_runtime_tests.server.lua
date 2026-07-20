local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("BossAbilityRuntimeTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("BossAbilityRuntimeTestsPassed", ok)
workspace:SetAttribute("BossAbilityRuntimeTestAssertions", ok and result or 0)

if ok then
	print(("[BossAbilityRuntimeTests] Passed %d assertions."):format(result))
else
	warn("[BossAbilityRuntimeTests] FAILED:", result)
end
