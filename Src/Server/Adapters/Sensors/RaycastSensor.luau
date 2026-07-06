--[=[
	RaycastSensor

	3D perception adapter shell. It currently uses the same result contract as
	GridSensor, but delegates line-of-sight to a spatial world query that can use
	Workspace raycasts.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local RaycastSensor = {}
RaycastSensor.__index = RaycastSensor

function RaycastSensor:Sense(
	agent: Types.Agent,
	worldQuery: Types.WorldQueryAdapter,
	agentStore: Types.AgentStore,
	blackboard: Types.BlackboardStore,
	now: number
): Types.PerceptionResult
	local visibleEnemies = {}
	local lastSeenEnemies = table.clone(agent.perception.lastSeenEnemies or {})

	for _, other in ipairs(agentStore:GetAll()) do
		if other.stats.alive and other.teamId ~= agent.teamId then
			local offset = other.transform.position - agent.transform.position
			if
				offset.Magnitude <= self.config.Sensor.Range
				and worldQuery:HasLineOfSight(agent.transform.position, other.transform.position)
			then
				local contact = {
					agentId = other.id,
					teamId = other.teamId,
					position = other.transform.position,
					confidence = 1,
					lastSeenAt = now,
				}

				table.insert(visibleEnemies, contact)
				lastSeenEnemies[other.id] = contact
				blackboard:RecordEnemySighting(contact, now)
			end
		end
	end

	return {
		visibleEnemies = visibleEnemies,
		lastSeenEnemies = lastSeenEnemies,
	}
end

function RaycastSensor.new(config: Types.Config): Types.RaycastSensorAdapter
	local self = setmetatable({}, RaycastSensor)

	self.config = config

	return self
end

return RaycastSensor
