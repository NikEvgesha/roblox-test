local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("WeaponControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("WeaponControllerTestsPassed", ok)
workspace:SetAttribute("WeaponControllerTestAssertions", ok and result or 0)

if ok then
	print(("[WeaponControllerTests] Passed %d assertions."):format(result))
else
	warn("[WeaponControllerTests] FAILED:", result)
end
