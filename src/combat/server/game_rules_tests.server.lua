local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("GameRulesTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("GameRulesTestsPassed", ok)
workspace:SetAttribute("GameRulesTestAssertions", ok and result or 0)

if ok then
	print(("[GameRulesTests] Passed %d assertions."):format(result))
else
	warn("[GameRulesTests] FAILED:", result)
end
