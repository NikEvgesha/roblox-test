local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("WeaponAnimationControllerTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("WeaponAnimationControllerTestsPassed", ok)
workspace:SetAttribute("WeaponAnimationControllerTestAssertions", ok and result or 0)

if ok then
	print(("[WeaponAnimationControllerTests] Passed %d assertions."):format(result))
else
	warn("[WeaponAnimationControllerTests] FAILED:", result)
end
