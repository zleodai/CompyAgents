--[=[
	PerceptionSystem

	Scans agents on a low-frequency cadence and enqueues bounded perception jobs.
	The concrete sensor is provided by an adapter, so grid LOS can later be
	replaced with 3D raycasts without changing system logic.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local PerceptionSystem = {}
PerceptionSystem.__index = PerceptionSystem

function PerceptionSystem:Scan(now: number): ()
	for _, agent in ipairs(self.agentStore:GetAll()) do
		if agent.stats.alive and not agent.perception.sensingQueued and agent.perception.nextSenseAt <= now then
			agent.perception.sensingQueued = true
			agent.perception.nextSenseAt = now + self.interval

			self.queue:Enqueue({
				id = "sense:" .. agent.id,
				kind = "Perception",
				agentId = agent.id,
				priority = 10,
				run = function(context: Types.SimulationContext): boolean
					local liveAgent = self.agentStore:Get(agent.id)
					if not liveAgent or not liveAgent.stats.alive then
						return true
					end

					local blackboard = self.blackboards[liveAgent.teamId]
					local result =
						self.sensor:Sense(liveAgent, self.worldQuery, self.agentStore, blackboard, context.now)
					liveAgent.perception.visibleEnemies = result.visibleEnemies
					liveAgent.perception.lastSeenEnemies = result.lastSeenEnemies
					liveAgent.perception.sensingQueued = false
					return true
				end,
			})
		end
	end
end

function PerceptionSystem.new(deps: Types.SystemDependencies): Types.PerceptionSystem
	local self = setmetatable({}, PerceptionSystem)

	self.agentStore = deps.agentStore
	self.blackboards = deps.blackboards
	self.sensor = deps.adapters.sensor
	self.worldQuery = deps.adapters.worldQuery
	self.queue = deps.queues.Perception
	self.interval = deps.config.Cadence.PerceptionInterval

	return self
end

return PerceptionSystem
