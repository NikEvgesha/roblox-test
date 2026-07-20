local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("EnemyRuntimeTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("EnemyRuntimeTestsPassed", ok)
workspace:SetAttribute("EnemyRuntimeTestAssertions", ok and result or 0)

if ok then
	print(("[EnemyRuntimeTests] Passed %d assertions."):format(result))
else
	warn("[EnemyRuntimeTests] FAILED:", result)
end
