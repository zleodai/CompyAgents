--[=[
	PathSystem

	Converts AgentMovement destination requests into queued path requests. The
	system does not inspect GOAP actions; action modules request movement through
	AgentController and this system reacts to the data.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local PathSystem = {}
PathSystem.__index = PathSystem

function PathSystem.Scan(self: Types.PathSystem, now: number): ()
	for _, agent in ipairs(self.agentStore:GetAll()) do
		if
			agent.stats.alive
			and agent.movement.needsPath
			and not agent.movement.pathQueued
			and agent.movement.nextPathAt <= now
		then
			agent.movement.pathQueued = true

			self.queue:Enqueue({
				id = "path:" .. agent.id,
				kind = "Pathing",
				agentId = agent.id,
				priority = 15,
				run = function(context: Types.SimulationContext): boolean
					local liveAgent = self.agentStore:Get(agent.id)
					if not liveAgent or not liveAgent.stats.alive then
						return true
					end

					local destination = liveAgent.movement.destination
					if not destination then
						liveAgent.movement.needsPath = false
						liveAgent.movement.pathQueued = false
						return true
					end

					local result = self.pathProvider:FindPath(liveAgent, destination, self.worldQuery, context.now)
					self.movementDriver:SetPath(liveAgent, result)
					liveAgent.movement.nextPathAt = context.now + self.config.Pathing.RepathCooldown
					liveAgent.movement.needsPath = false
					liveAgent.movement.pathQueued = false
					return true
				end,
			})
		end
	end
end

function PathSystem.new(deps: Types.SystemDependencies): Types.PathSystem
	local self = setmetatable({}, PathSystem)

	self.config = deps.config
	self.agentStore = deps.agentStore
	self.worldQuery = deps.adapters.worldQuery
	self.pathProvider = deps.adapters.pathProvider
	self.movementDriver = deps.adapters.movementDriver
	self.queue = deps.queues.Pathing

	return self
end

return PathSystem
