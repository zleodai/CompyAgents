--[=[
	GridSensor

	Grid-friendly perception adapter. It reports visible enemies using range and
	world-query line-of-sight checks while writing sightings to the team
	blackboard through the shared perception result shape.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GridSensor = {}
GridSensor.__index = GridSensor

function GridSensor:Sense(
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
			local distance = offset.Magnitude

			if
				distance <= self.config.Sensor.Range
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

function GridSensor.new(config: Types.Config): Types.GridSensorAdapter
	local self = setmetatable({}, GridSensor)

	self.config = config

	return self
end

return GridSensor
