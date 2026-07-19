local GameRules = {}

local function nonNegativeInteger(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

function GameRules.GetPartyMultiplier(playerCount, bonusPerPlayer)
	local count = nonNegativeInteger(playerCount)
	if count <= 1 then
		return 1
	end

	return 1 + math.max(0, tonumber(bonusPerPlayer) or 0) * count
end

function GameRules.GetPerPlayerReward(baseReward, playerCount, bonusPerPlayer)
	local count = nonNegativeInteger(playerCount)
	if count <= 0 then
		return 0
	end

	local reward = math.max(0, tonumber(baseReward) or 0)
	local multiplier = GameRules.GetPartyMultiplier(count, bonusPerPlayer)
	return math.max(0, math.floor(reward * multiplier / count + 0.5))
end

function GameRules.GetXpForLevel(level, baseXpForLevel, xpGrowthPerLevel)
	local normalizedLevel = math.max(1, math.floor(tonumber(level) or 1))
	local baseXp = math.max(1, math.floor(tonumber(baseXpForLevel) or 1))
	local growth = math.max(0, math.floor(tonumber(xpGrowthPerLevel) or 0))
	return baseXp + (normalizedLevel - 1) * growth
end

function GameRules.ApplyXp(level, currentXp, amount, baseXpForLevel, xpGrowthPerLevel)
	local nextLevel = math.max(1, math.floor(tonumber(level) or 1))
	local nextXp = nonNegativeInteger(currentXp)
	local remaining = nonNegativeInteger(amount)
	local levelsGained = 0

	while remaining > 0 do
		local requiredXp = GameRules.GetXpForLevel(nextLevel, baseXpForLevel, xpGrowthPerLevel)
		local needed = requiredXp - nextXp
		if needed <= 0 then
			nextLevel += 1
			levelsGained += 1
			nextXp = 0
		elseif remaining >= needed then
			remaining -= needed
			nextLevel += 1
			levelsGained += 1
			nextXp = 0
		else
			nextXp += remaining
			remaining = 0
		end
	end

	return {
		level = nextLevel,
		xp = nextXp,
		levelsGained = levelsGained,
	}
end

function GameRules.GetFreeRespawnSeconds(deathCount, baseSeconds, incrementSeconds)
	local normalizedDeathCount = math.max(1, math.floor(tonumber(deathCount) or 1))
	local base = math.max(0, tonumber(baseSeconds) or 0)
	local increment = math.max(0, tonumber(incrementSeconds) or 0)
	return base + (normalizedDeathCount - 1) * increment
end

function GameRules.GetScaledValue(baseValue, scalePerStage, stage, multiplier)
	local base = tonumber(baseValue) or 0
	local scale = tonumber(scalePerStage) or 0
	local normalizedStage = math.max(0, tonumber(stage) or 0)
	return base * (1 + scale * normalizedStage) * (tonumber(multiplier) or 1)
end

function GameRules.GetDifficultyMultipliers(difficulty)
	difficulty = type(difficulty) == "table" and difficulty or {}
	return {
		health = tonumber(difficulty.EnemyHealthMultiplier) or 1,
		damage = tonumber(difficulty.EnemyDamageMultiplier) or 1,
		enemyCount = tonumber(difficulty.EnemyCountMultiplier) or 1,
		reward = tonumber(difficulty.RewardMultiplier) or 1,
		crystal = tonumber(difficulty.CrystalMultiplier) or 1,
	}
end

function GameRules.GetUpgradeCost(baseCost, costStep, currentLevel)
	local base = math.max(1, math.floor(tonumber(baseCost) or 1))
	local step = math.max(0, math.floor(tonumber(costStep) or 0))
	local level = nonNegativeInteger(currentLevel)
	return base + level * step
end

function GameRules.GetAbilityUpgradeDecision(currentRank, maxRank, skillPoints, upgradeCost)
	local rank = nonNegativeInteger(currentRank)
	local maximum = math.max(1, math.floor(tonumber(maxRank) or 1))
	local points = nonNegativeInteger(skillPoints)
	local cost = math.max(1, math.floor(tonumber(upgradeCost) or 1))

	if rank >= maximum then
		return { allowed = false, reason = "maxed", rank = rank, cost = cost }
	end

	if points < cost then
		return { allowed = false, reason = "not_enough_points", rank = rank, cost = cost }
	end

	return { allowed = true, reason = "", rank = rank, cost = cost, nextRank = rank + 1 }
end

return GameRules
