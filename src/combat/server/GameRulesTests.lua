local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local combatConfig = require(sharedFolder:WaitForChild("CombatConfig"))
local gameRules = require(sharedFolder:WaitForChild("GameRules"))

local GameRulesTests = {}

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

function GameRulesTests.Run()
	local assertions = 0
	local function equal(actual, expected, label)
		expectEqual(actual, expected, label)
		assertions += 1
	end
	local function near(actual, expected, epsilon, label)
		expectNear(actual, expected, epsilon, label)
		assertions += 1
	end

	equal(gameRules.GetPartyMultiplier(1, 0.1), 1, "solo reward multiplier")
	near(gameRules.GetPartyMultiplier(6, 0.1), 1.6, 0.000001, "six-player reward multiplier")
	equal(gameRules.GetPerPlayerReward(60, 6, 0.1), 16, "six-player XP split")
	equal(gameRules.GetPerPlayerReward(6, 6, 0.1), 2, "integer money split rounding")
	equal(gameRules.GetPerPlayerReward(60, 0, 0.1), 0, "empty party reward")

	local progression = combatConfig.Progression
	equal(gameRules.GetXpForLevel(1, progression.BaseXpForLevel, progression.XpGrowthPerLevel), 100, "level one XP")
	equal(gameRules.GetXpForLevel(3, progression.BaseXpForLevel, progression.XpGrowthPerLevel), 170, "level three XP")

	local oneLevel = gameRules.ApplyXp(1, 90, 25, 100, 50)
	equal(oneLevel.level, 2, "single level result")
	equal(oneLevel.xp, 15, "single level remainder")
	equal(oneLevel.levelsGained, 1, "single level count")

	local multipleLevels = gameRules.ApplyXp(1, 0, 350, 100, 20)
	equal(multipleLevels.level, 3, "multiple level result")
	equal(multipleLevels.xp, 130, "multiple level remainder")
	equal(multipleLevels.levelsGained, 2, "multiple level count")

	near(gameRules.GetScaledValue(100, 0.01, 9, 2), 218, 0.000001, "wave stat scaling")
	local hard = gameRules.GetDifficultyMultipliers(combatConfig.Zombies.Difficulties.Hard)
	equal(hard.health, 2, "hard health multiplier")
	equal(hard.damage, 2, "hard damage multiplier")
	equal(hard.enemyCount, 2, "hard enemy count multiplier")
	equal(hard.reward, 2, "hard reward multiplier")
	equal(hard.crystal, 2, "hard crystal multiplier")

	equal(gameRules.GetFreeRespawnSeconds(1, 10, 10), 10, "first free respawn")
	equal(gameRules.GetFreeRespawnSeconds(5, 10, 10), 50, "fifth free respawn")
	equal(gameRules.GetUpgradeCost(5, 5, 3), 20, "meta upgrade cost")

	local allowed = gameRules.GetAbilityUpgradeDecision(2, 5, 1, 1)
	equal(allowed.allowed, true, "ability upgrade allowed")
	equal(allowed.nextRank, 3, "ability next rank")
	local noPoints = gameRules.GetAbilityUpgradeDecision(2, 5, 0, 1)
	equal(noPoints.reason, "not_enough_points", "ability points rejection")
	local maxed = gameRules.GetAbilityUpgradeDecision(5, 5, 100, 1)
	equal(maxed.reason, "maxed", "ability max rank rejection")

	return assertions
end

return GameRulesTests
