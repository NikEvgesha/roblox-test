local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local tests = require(script.Parent:WaitForChild("WaveDirectorTests"))
local ok, result = pcall(tests.Run)

workspace:SetAttribute("WaveDirectorTestsPassed", ok)
workspace:SetAttribute("WaveDirectorTestAssertions", ok and result or 0)

if ok then
	print(("[WaveDirectorTests] Passed %d assertions."):format(result))
else
	warn("[WaveDirectorTests] FAILED:", result)
end
