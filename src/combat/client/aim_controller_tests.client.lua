local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("AimControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("AimControllerTestsPassed", ok)
workspace:SetAttribute("AimControllerTestAssertions", ok and result or 0)

if ok then
	print(("[AimControllerTests] Passed %d assertions."):format(result))
else
	warn("[AimControllerTests] FAILED:", result)
end
