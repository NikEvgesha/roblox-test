local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("EnemyFactoryTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("EnemyFactoryTestsPassed", ok)
workspace:SetAttribute("EnemyFactoryTestAssertions", ok and result or 0)

if ok then
	print(("[EnemyFactoryTests] Passed %d assertions."):format(result))
else
	warn("[EnemyFactoryTests] FAILED:", result)
end
