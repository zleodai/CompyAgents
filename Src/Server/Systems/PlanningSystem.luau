--[=[
	PlanningSystem

	Finds agents that need new decisions and enqueues bounded GOAP planning jobs.
	Planning is intentionally delayed through a queue so load is applied as agent
	latency instead of frame spikes.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Actions = require(CompyServerScripts.GOAP.Actions)
local Goals = require(CompyServerScripts.GOAP.Goals)
local Planner = require(CompyServerScripts.GOAP.Planner)
local PlanExecutor = require(CompyServerScripts.GOAP.PlanExecutor)

local PlanningSystem = {}
PlanningSystem.__index = PlanningSystem

function PlanningSystem:Scan(now: number): ()
	for _, agent in ipairs(self.agentStore:GetAll()) do
		if
			agent.stats.alive
			and agent.decision.needsPlan
			and not agent.decision.planningQueued
			and agent.decision.nextThinkAt <= now
		then
			agent.decision.planningQueued = true

			self.queue:Enqueue({
				id = "plan:" .. agent.id,
				kind = "Planning",
				agentId = agent.id,
				priority = 20,
				run = function(context: Types.SimulationContext): boolean
					local liveAgent = self.agentStore:Get(agent.id)
					if not liveAgent or not liveAgent.stats.alive then
						return true
					end

					local blackboard = self.blackboards[liveAgent.teamId]
					local facts = Goals.BuildFacts(liveAgent, blackboard)
					local candidateGoals = Goals.BuildCandidateGoals(liveAgent, blackboard, facts)
					local availableActions = Actions.GetAvailableActions(liveAgent, facts, blackboard)

					for _, goal in ipairs(candidateGoals) do
						local result = Planner.Plan(facts, goal.facts, availableActions, self.config.GOAP)
						if result.success then
							PlanExecutor.AssignPlan(liveAgent, goal, result, context.now)
							return true
						end
					end

					liveAgent.decision.needsPlan = false
					liveAgent.decision.planningQueued = false
					liveAgent.decision.nextThinkAt = context.now + self.config.GOAP.FailedPlanCooldown
					liveAgent.decision.lastPlanReason = "planner_failed"
					return true
				end,
			})
		end
	end
end

function PlanningSystem.new(deps: Types.SystemDependencies): Types.PlanningSystem
	local self = setmetatable({}, PlanningSystem)

	self.config = deps.config
	self.agentStore = deps.agentStore
	self.blackboards = deps.blackboards
	self.queue = deps.queues.Planning

	return self
end

return PlanningSystem
