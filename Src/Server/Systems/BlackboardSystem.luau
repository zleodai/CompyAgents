--[=[
	BlackboardSystem

	Queues periodic cleanup work for each team-local blackboard. Cleanup is
	budgeted so large numbers of short-lived claims do not create simulation
	spikes.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local BlackboardSystem = {}
BlackboardSystem.__index = BlackboardSystem

function BlackboardSystem:EnqueueCleanup(_now: number): ()
	for teamId, blackboard in pairs(self.blackboards) do
		self.queue:Enqueue({
			id = "blackboard-cleanup:" .. teamId,
			kind = "BlackboardCleanup",
			priority = 1,
			run = function(context: Types.SimulationContext): boolean
				blackboard:Cleanup(context.now)
				return true
			end,
		})
	end
end

function BlackboardSystem.new(deps: Types.SystemDependencies): Types.BlackboardSystem
	local self = setmetatable({}, BlackboardSystem)

	self.blackboards = deps.blackboards
	self.queue = deps.queues.Blackboard

	return self
end

return BlackboardSystem
