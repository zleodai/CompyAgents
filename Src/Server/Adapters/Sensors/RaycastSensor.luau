--[=[
	RaycastSensor

	3D perception adapter. It raycasts from humanoid heads when model data exists
	and falls back to the configured abstract eye offset.
]=]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local RaycastSensor = {}
RaycastSensor.__index = RaycastSensor

function RaycastSensor:_getEyePosition(agent: Types.Agent): Vector3
	local agentModelStore = self.agentModelStore
	if agentModelStore then
		local head = agentModelStore:GetHead(agent.id)
		if head then
			return head.Position
		end
	end

	return agent.transform.position + self.config.Sensor.EyeOffset
end

function RaycastSensor:_getSightingPosition(agent: Types.Agent): Vector3
	local agentModelStore = self.agentModelStore
	if agentModelStore then
		local record = agentModelStore:Get(agent.id)
		if record then
			return record.rootPart.Position - Vector3.new(0, record.groundToRootOffset, 0)
		end
	end

	return agent.transform.position
end

function RaycastSensor:_buildRaycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local filter: { Instance } = {}
	local agentModelStore = self.agentModelStore
	if agentModelStore then
		local modelFolder = agentModelStore:GetModelFolder()
		if modelFolder then
			table.insert(filter, modelFolder)
		else
			for _, model in ipairs(agentModelStore:GetModels()) do
				table.insert(filter, model)
			end
		end
	end

	local visualizationFolder = Workspace:FindFirstChild(self.config.Visualization.FolderName)
	if visualizationFolder then
		table.insert(filter, visualizationFolder)
	end

	params.FilterDescendantsInstances = filter
	return params
end

function RaycastSensor:_hasLineOfSight(origin: Vector3, target: Vector3): boolean
	local direction = target - origin
	if direction.Magnitude <= 0.001 then
		return true
	end

	local result = Workspace:Raycast(origin, direction, self:_buildRaycastParams())
	return result == nil
end

function RaycastSensor:Sense(
	agent: Types.Agent,
	_worldQuery: Types.WorldQueryAdapter,
	agentStore: Types.AgentStore,
	blackboard: Types.BlackboardStore,
	now: number
): Types.PerceptionResult
	local visibleEnemies = {}
	local lastSeenEnemies = table.clone(agent.perception.lastSeenEnemies or {})
	local origin = self:_getEyePosition(agent)

	for _, other in ipairs(agentStore:GetAll()) do
		if other.stats.alive and other.teamId ~= agent.teamId then
			local targetEye = self:_getEyePosition(other)
			local offset = targetEye - origin
			if offset.Magnitude <= self.config.Sensor.Range and self:_hasLineOfSight(origin, targetEye) then
				local contact = {
					agentId = other.id,
					teamId = other.teamId,
					position = targetEye,
					confidence = 1,
					lastSeenAt = now,
				}
				local sightingContact = {
					agentId = other.id,
					teamId = other.teamId,
					position = self:_getSightingPosition(other),
					confidence = contact.confidence,
					lastSeenAt = contact.lastSeenAt,
				}

				table.insert(visibleEnemies, contact)
				lastSeenEnemies[other.id] = contact
				blackboard:RecordEnemySighting(sightingContact, now)
			end
		end
	end

	return {
		visibleEnemies = visibleEnemies,
		lastSeenEnemies = lastSeenEnemies,
	}
end

function RaycastSensor.new(config: Types.Config, agentModelStore: Types.AgentModelStore?): Types.RaycastSensorAdapter
	local self = setmetatable({}, RaycastSensor)

	self.config = config
	self.agentModelStore = agentModelStore

	return self
end

return RaycastSensor
