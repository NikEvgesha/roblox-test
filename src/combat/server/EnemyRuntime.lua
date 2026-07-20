local EnemyRuntime = {}
EnemyRuntime.__index = EnemyRuntime

local function defaultRandomIndex(maximum)
	return math.random(1, maximum)
end

function EnemyRuntime.new(options)
	options = type(options) == "table" and options or {}

	local self = setmetatable({}, EnemyRuntime)
	self.folder = assert(options.folder, "EnemyRuntime requires an enemy folder")
	self.spawnPointsFolder = assert(options.spawnPointsFolder, "EnemyRuntime requires a spawn-points folder")
	self.minSpawnDistance = math.max(0, tonumber(options.minSpawnDistance) or 0)
	self.spawnPointAttempts = math.max(1, math.floor(tonumber(options.spawnPointAttempts) or 12))
	self.getPlayers = assert(options.getPlayers, "EnemyRuntime requires getPlayers")
	self.getLiveTarget = assert(options.getLiveTarget, "EnemyRuntime requires getLiveTarget")
	self.cleanupState = options.cleanupState
	self.randomIndex = options.randomIndex or defaultRandomIndex
	self.states = {}
	return self
end

function EnemyRuntime:Register(model, state)
	assert(model ~= nil, "EnemyRuntime:Register requires a model")
	assert(type(state) == "table", "EnemyRuntime:Register requires a state table")
	state.model = model
	self.states[model] = state
	return state
end

function EnemyRuntime:GetState(model)
	return self.states[model]
end

function EnemyRuntime:GetRegisteredCount()
	local count = 0
	for _ in pairs(self.states) do
		count += 1
	end
	return count
end

function EnemyRuntime:IsAlive(model, state)
	state = state or self.states[model]
	if not state or state.dead then
		return false
	end

	local humanoid = state.humanoid
	local root = state.root
	return model.Parent == self.folder
		and humanoid ~= nil
		and humanoid.Parent ~= nil
		and humanoid:IsDescendantOf(model)
		and humanoid.Health > 0
		and root ~= nil
		and root.Parent ~= nil
		and root:IsDescendantOf(model)
end

function EnemyRuntime:Remove(model)
	local state = self.states[model]
	if not state then
		return nil
	end

	self.states[model] = nil
	if self.cleanupState then
		self.cleanupState(state)
	end
	return state
end

function EnemyRuntime:ForEachAlive(callback)
	assert(type(callback) == "function", "EnemyRuntime:ForEachAlive requires a callback")

	for model, state in pairs(self.states) do
		if self:IsAlive(model, state) then
			callback(model, state)
		else
			self:Remove(model)
		end
	end
end

function EnemyRuntime:CountAlive()
	local count = 0
	self:ForEachAlive(function()
		count += 1
	end)
	return count
end

function EnemyRuntime:ClearAll()
	local removed = 0
	for model, state in pairs(self.states) do
		self.states[model] = nil
		if self.cleanupState then
			self.cleanupState(state)
		end
		if model and model.Parent then
			model:Destroy()
		end
		removed += 1
	end

	for _, child in ipairs(self.folder:GetChildren()) do
		child:Destroy()
	end

	return removed
end

function EnemyRuntime:GetNearestTarget(position)
	local nearestPlayer = nil
	local nearestHumanoid = nil
	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, player in ipairs(self.getPlayers()) do
		local humanoid, root = self.getLiveTarget(player)
		if humanoid and root then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
				nearestHumanoid = humanoid
				nearestRoot = root
			end
		end
	end

	return nearestPlayer, nearestHumanoid, nearestRoot, nearestDistance
end

function EnemyRuntime:GetRandomSpawnPoint()
	local points = {}
	for _, child in ipairs(self.spawnPointsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end

	if #points == 0 then
		return nil
	end

	local function choosePoint()
		local rawIndex = math.floor(tonumber(self.randomIndex(#points)) or 1)
		return points[math.clamp(rawIndex, 1, #points)]
	end

	for _ = 1, self.spawnPointAttempts do
		local candidate = choosePoint()
		local _, _, _, distance = self:GetNearestTarget(candidate.Position)
		if distance == math.huge or distance >= self.minSpawnDistance then
			return candidate
		end
	end

	return choosePoint()
end

return EnemyRuntime
