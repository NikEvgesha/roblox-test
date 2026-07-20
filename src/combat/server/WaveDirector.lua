local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameRules = require(sharedFolder:WaitForChild("GameRules"))

local WaveDirector = {}
WaveDirector.__index = WaveDirector

local function normalizeWave(waveNumber)
	return math.max(1, math.floor(tonumber(waveNumber) or 1))
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
	local waveEntry = self:GetWaveEntry(waveNumber)
	if waveEntry and type(waveEntry.Weights) == "table" then
		return waveEntry.Weights
	end

	local progressionStep = math.max(1, tonumber(self.config.DifficultyStepSeconds) or 1)
	local progressionTime = self:GetDifficultyStage(waveNumber) * progressionStep
	local chosenWeights = nil

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

	return chosenWeights or { Walker = 100 }
end

function WaveDirector:ComputeSpawnBudget(waveNumber, partySize, difficulty)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(wave)
	local multipliers = self:GetDifficultyMultipliers(difficulty)

	local baseEnemies = tonumber(waveEntry and waveEntry.BaseEnemiesPerWave)
	if baseEnemies == nil then
		baseEnemies = tonumber(self.config.BaseEnemiesPerWave) or 8
	end

	local perWaveStep = tonumber(waveEntry and waveEntry.EnemiesPerWaveStep)
	if perWaveStep == nil then
		perWaveStep = tonumber(self.config.EnemiesPerWaveStep) or 1
	end

	local growthStartWave = normalizeWave(waveEntry and waveEntry.MinWave or 1)
	local normalCount = baseEnemies + math.max(0, wave - growthStartWave) * perWaveStep

	if self:IsBossWave(wave) then
		local additional = tonumber(waveEntry and waveEntry.BossAdditionalEnemies)
		if additional == nil then
			additional = tonumber(self.config.BossAdditionalEnemies) or 0
		end
		normalCount += additional
	end

	normalCount *= self:GetPartyMultiplier(partySize)
	normalCount *= multipliers.enemyCount
	normalCount = math.max(1, math.floor(normalCount + 0.5))

	local bossCount = self:IsBossWave(wave) and 1 or 0
	return normalCount + bossCount, bossCount
end

function WaveDirector:GetAliveCap(waveNumber, partySize, difficulty)
	local wave = normalizeWave(waveNumber)
	local waveEntry = self:GetWaveEntry(wave)
	local multipliers = self:GetDifficultyMultipliers(difficulty)
	local baseAlive = tonumber(waveEntry and waveEntry.MaxAlive)

	if baseAlive == nil then
		local configBaseAlive = tonumber(self.config.BaseMaxAlive) or 10
		local alivePerStage = tonumber(self.config.MaxAlivePerStage) or 2
		baseAlive = configBaseAlive + self:GetDifficultyStage(wave) * alivePerStage
	end

	local maxAlive = math.max(2, baseAlive)
	maxAlive *= self:GetPartyMultiplier(partySize)
	maxAlive *= multipliers.enemyCount
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
