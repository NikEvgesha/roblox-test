local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameRules = require(sharedFolder:WaitForChild("GameRules"))

local WaveDirector = {}
WaveDirector.__index = WaveDirector

local function normalizeWave(waveNumber)
	return math.max(1, math.floor(tonumber(waveNumber) or 1))
end

local function evaluateCountCurve(curve, waveNumber)
	if type(curve) ~= "table" then
		return nil
	end
	local startWave = normalizeWave(curve.StartWave)
	local endWave = math.max(startWave, normalizeWave(curve.EndWave))
	local startCount = tonumber(curve.StartCount)
	local endCount = tonumber(curve.EndCount)
	if startCount == nil or endCount == nil then
		return nil
	end
	if endWave == startWave then
		return endCount
	end
	local alpha = math.clamp((normalizeWave(waveNumber) - startWave) / (endWave - startWave), 0, 1)
	return startCount + (endCount - startCount) * alpha
end

function WaveDirector.new(config)
	local self = setmetatable({}, WaveDirector)
	self.config = type(config) == "table" and config or {}
	self.waveTable = self.config.WaveTable or {}
	self.difficultySchedule = self.config.DifficultySchedule or {}
	return self
end

function WaveDirector:GetDifficultyStage(waveNumber)
	return normalizeWave(waveNumber) - 1
end

function WaveDirector:GetWaveEntry(waveNumber)
	local wave = normalizeWave(waveNumber)
	local selected = nil

	for _, entry in ipairs(self.waveTable) do
		if type(entry) == "table" then
			local minWave = normalizeWave(entry.MinWave)
			local maxWaveRaw = entry.MaxWave
			local maxWave = maxWaveRaw == nil and math.huge
				or math.max(minWave, math.floor(tonumber(maxWaveRaw) or minWave))
			if wave >= minWave and wave <= maxWave then
				selected = entry
			end
		end
	end

	return selected
end

function WaveDirector:GetDifficultyMultipliers(difficulty)
	return gameRules.GetDifficultyMultipliers(difficulty)
end

function WaveDirector:GetPartyMultiplier(partySize)
	local bonusPerPlayer = tonumber(self.config.PartyEnemyCountBonusPerPlayer) or 0.1
	return gameRules.GetPartyMultiplier(partySize, bonusPerPlayer)
end

function WaveDirector:IsBossWave(waveNumber)
	local interval = math.max(1, math.floor(tonumber(self.config.BossWaveInterval) or 10))
	return normalizeWave(waveNumber) % interval == 0
end

function WaveDirector:GetVariantWeights(waveNumber)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(waveNumber)
	local chosenWeights = nil
	if waveEntry and type(waveEntry.Weights) == "table" then
		chosenWeights = waveEntry.Weights
	else
		local progressionStep = math.max(1, tonumber(self.config.DifficultyStepSeconds) or 1)
		local progressionTime = self:GetDifficultyStage(waveNumber) * progressionStep

		for _, entry in ipairs(self.difficultySchedule) do
			local minTime = entry.MinTime
			if minTime == nil and entry.MinWave ~= nil then
				minTime = (entry.MinWave - 1) * progressionStep
			end
			minTime = minTime or 0
			if progressionTime >= minTime then
				chosenWeights = entry.Weights
			else
				break
			end
		end
	end

	local mergedWeights = {}
	for variantKey, weight in pairs(chosenWeights or { Walker = 100 }) do
		mergedWeights[variantKey] = weight
	end
	for _, introduction in ipairs(self.config.VariantIntroductions or {}) do
		if wave >= normalizeWave(introduction.MinWave) then
			for variantKey, weight in pairs(introduction.Weights or {}) do
				mergedWeights[variantKey] = (tonumber(mergedWeights[variantKey]) or 0) + (tonumber(weight) or 0)
			end
		end
	end

	return mergedWeights
end

function WaveDirector:GetBossVariantKey(waveNumber)
	local keys = self:GetBossVariantKeys(waveNumber)
	return keys[1]
end

function WaveDirector:GetBossVariantKeys(waveNumber)
	local wave = normalizeWave(waveNumber)
	if not self:IsBossWave(wave) then
		return {}
	end

	local order = self.config.BossVariantOrder
	if type(order) ~= "table" or #order == 0 then
		return self.config.BossVariantKey and { self.config.BossVariantKey } or {}
	end

	local allBossesWave = tonumber(self.config.AllBossesWave)
	if allBossesWave and wave == normalizeWave(allBossesWave) then
		local allBosses = {}
		for _, variantKey in ipairs(order) do
			table.insert(allBosses, variantKey)
		end
		return allBosses
	end

	local interval = math.max(1, math.floor(tonumber(self.config.BossWaveInterval) or 10))
	local bossWaveIndex = math.floor(wave / interval)
	return { order[((bossWaveIndex - 1) % #order) + 1] }
end

function WaveDirector:ComputeSpawnBudget(waveNumber, partySize, difficulty)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(wave)
	local multipliers = self:GetDifficultyMultipliers(difficulty)

	local normalCount = evaluateCountCurve(self.config.WaveEnemyCountCurve, wave)
	if normalCount == nil then
		local baseEnemies = tonumber(waveEntry and waveEntry.BaseEnemiesPerWave)
		if baseEnemies == nil then
			baseEnemies = tonumber(self.config.BaseEnemiesPerWave) or 8
		end

		local perWaveStep = tonumber(waveEntry and waveEntry.EnemiesPerWaveStep)
		if perWaveStep == nil then
			perWaveStep = tonumber(self.config.EnemiesPerWaveStep) or 1
		end

		local growthStartWave = normalizeWave(waveEntry and waveEntry.MinWave or 1)
		normalCount = baseEnemies + math.max(0, wave - growthStartWave) * perWaveStep

		if self:IsBossWave(wave) then
			local additional = tonumber(waveEntry and waveEntry.BossAdditionalEnemies)
			if additional == nil then
				additional = tonumber(self.config.BossAdditionalEnemies) or 0
			end
			normalCount += additional
		end
	end

	normalCount *= self:GetPartyMultiplier(partySize)
	normalCount *= multipliers.enemyCount
	normalCount = math.max(1, math.floor(normalCount + 0.5))

	local bossCount = #self:GetBossVariantKeys(wave)
	return normalCount + bossCount, bossCount
end

function WaveDirector:GetAliveCap(waveNumber, partySize, difficulty)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(wave)
	local multipliers = self:GetDifficultyMultipliers(difficulty)
	local baseAlive = evaluateCountCurve(self.config.AliveCapCurve, wave)
	if baseAlive == nil then
		baseAlive = tonumber(waveEntry and waveEntry.MaxAlive)
	end

	if baseAlive == nil then
		local configBaseAlive = tonumber(self.config.BaseMaxAlive) or 10
		local alivePerStage = tonumber(self.config.MaxAlivePerStage) or 2
		baseAlive = configBaseAlive + self:GetDifficultyStage(wave) * alivePerStage
	end

	local maxAlive = math.max(2, baseAlive)
	maxAlive *= self:GetPartyMultiplier(partySize)
	maxAlive *= multipliers.enemyCount
	local absoluteMaximum = tonumber(self.config.AbsoluteMaxAlive)
	if absoluteMaximum and absoluteMaximum > 0 then
		maxAlive = math.min(maxAlive, absoluteMaximum)
	end
	return math.max(2, math.floor(maxAlive + 0.5))
end

function WaveDirector:GetSpawnInterval(waveNumber, partySize, difficulty)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(wave)
	local multipliers = self:GetDifficultyMultipliers(difficulty)
	local spawnPressure = math.max(1, multipliers.enemyCount * self:GetPartyMultiplier(partySize))
	local interval = tonumber(waveEntry and waveEntry.SpawnInterval)

	if interval == nil then
		local baseInterval = tonumber(self.config.BaseSpawnInterval) or 3.8
		local scalePerStage = tonumber(self.config.SpawnRateScalePerStage) or 0.12
		interval = baseInterval / (1 + self:GetDifficultyStage(wave) * scalePerStage)
	end
	interval /= spawnPressure

	local minimum = tonumber(waveEntry and waveEntry.MinSpawnInterval)
	if minimum == nil then
		minimum = tonumber(self.config.MinSpawnInterval) or 1.1
	end
	local speedMultiplier = math.max(0.01, tonumber(self.config.WaveSpawnSpeedMultiplier) or 1)
	return math.max(minimum, interval) / speedMultiplier
end

return WaveDirector
