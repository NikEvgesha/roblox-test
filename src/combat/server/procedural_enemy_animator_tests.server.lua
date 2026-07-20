local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("ProceduralEnemyAnimatorTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("ProceduralEnemyAnimatorTestsPassed", ok)
workspace:SetAttribute("ProceduralEnemyAnimatorTestAssertions", ok and result or 0)

if ok then
	print(("[ProceduralEnemyAnimatorTests] Passed %d assertions."):format(result))
else
	warn("[ProceduralEnemyAnimatorTests] FAILED:", result)
end
