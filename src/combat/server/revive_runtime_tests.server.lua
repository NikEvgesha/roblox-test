local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("ReviveRuntimeTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("ReviveRuntimeTestsPassed", ok)
workspace:SetAttribute("ReviveRuntimeTestAssertions", ok and result or 0)

if ok then
	print(("[ReviveRuntimeTests] Passed %d assertions."):format(result))
else
	warn("[ReviveRuntimeTests] FAILED:", result)
end
