local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local WaveDirector = require(script.Parent:WaitForChild("WaveDirector"))

local WaveDirectorTests = {}

local function expectEqual(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
	end
end

local function expectNear(actual, expected, epsilon, label)
	if math.abs(actual - expected) > epsilon then
		error(("%s: expected %.6f, got %.6f"):format(label, expected, actual), 2)
	end
end

function WaveDirectorTests.Run()
	local director = WaveDirector.new(combatConfig.Zombies)
	local medium = combatConfig.Zombies.Difficulties.Medium
	local hard = combatConfig.Zombies.Difficulties.Hard
	local assertions = 0

	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, epsilon, label)
		expectNear(actual, expected, epsilon, label)
		assertions += 1
	end

	equal(director:GetDifficultyStage(1), 0, "wave one stage")
	equal(director:GetDifficultyStage(10), 9, "wave ten stage")
	equal(director:GetWaveEntry(1).MinWave, 1, "first wave table entry")
	equal(director:GetWaveEntry(10).MinWave, 10, "boss wave table entry")
	equal(director:GetWaveEntry(75).MinWave, 75, "endless wave table entry")
	equal(director:IsBossWave(9), false, "non-boss wave")
	equal(director:IsBossWave(10), true, "boss wave")
	equal(director:GetBossVariantKey(9), nil, "non-boss wave has no boss variant")
	equal(director:GetBossVariantKey(10), "BossStoneTitan", "wave ten stone boss")
	equal(director:GetBossVariantKey(20), "BossStormColossus", "wave twenty storm boss")
	equal(director:GetBossVariantKey(30), "BossFlameWarden", "wave thirty flame boss")
	equal(director:GetBossVariantKey(40), "BossBroodQueen", "wave forty brood boss")
	equal(director:GetBossVariantKey(50), "BossStoneTitan", "final wave starts with stone boss")
	equal(#director:GetBossVariantKeys(40), 1, "regular boss wave has one boss")
	equal(#director:GetBossVariantKeys(50), 4, "final wave has all bosses")
	equal(director:GetBossVariantKeys(50)[4], "BossBroodQueen", "final boss order includes brood queen")

	local waveOneTotal, waveOneBosses = director:ComputeSpawnBudget(1, 1, medium)
	equal(waveOneTotal, 100, "wave one budget")
	equal(waveOneBosses, 0, "wave one boss count")
	local waveTenTotal, waveTenBosses = director:ComputeSpawnBudget(10, 1, medium)
	equal(waveTenTotal, 174, "wave ten budget")
	equal(waveTenBosses, 1, "wave ten boss count")
	local partyTotal = director:ComputeSpawnBudget(1, 6, medium)
	equal(partyTotal, 160, "six-player wave budget")
	local hardTotal = director:ComputeSpawnBudget(1, 1, hard)
	equal(hardTotal, 200, "hard wave budget")
	local finalTotal, finalBosses = director:ComputeSpawnBudget(50, 1, medium)
	equal(finalTotal, 504, "final wave budget includes four bosses")
	equal(finalBosses, 4, "final wave boss count")

	equal(director:GetAliveCap(1, 1, medium), 100, "wave one alive cap")
	equal(director:GetAliveCap(1, 1, hard), 200, "hard alive cap")
	equal(director:GetAliveCap(1, 6, medium), 160, "party alive cap")
	equal(director:GetAliveCap(50, 1, medium), 500, "final wave alive cap")
	equal(director:GetAliveCap(50, 6, medium), 500, "alive cap clamps to tested maximum")
	near(director:GetSpawnInterval(1, 1, medium), 0.29, 0.000001, "wave one spawn interval")
	near(director:GetSpawnInterval(1, 1, hard), 0.145, 0.000001, "hard spawn interval")
	equal(director:GetVariantWeights(1).Runner, 55, "wave one runner weight")
	equal(director:GetVariantWeights(1).Needleling, 10, "wave one first new variant")
	equal(director:GetVariantWeights(2).DustMite, 7, "wave two second variant introduced")
	equal(director:GetVariantWeights(6).LavaCrawler, nil, "wave six has no scheduled introduction")
	equal(director:GetVariantWeights(7).LavaCrawler, 4, "two-wave cadence starts at wave seven")
	equal(director:GetVariantWeights(33).VoidEye, nil, "four-wave cadence waits through wave thirty-three")
	equal(director:GetVariantWeights(34).VoidEye, 4, "four-wave cadence starts at wave thirty-four")
	equal(director:GetVariantWeights(49).StormShard, nil, "final variant waits for final wave")
	equal(director:GetVariantWeights(50).StormShard, 6, "final variant introduced on final wave")
	equal(director:GetVariantWeights(10).Needleling, 10, "introduced variants remain in later waves")

	return assertions
end

return WaveDirectorTests
