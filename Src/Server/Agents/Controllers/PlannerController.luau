local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Actions = require(CompyServerScripts.GOAP.Actions)
local Goals = require(CompyServerScripts.GOAP.Goals)
local Planner = require(CompyServerScripts.GOAP.Planner)
local Types = require(CompyServerScripts.Core.Types)

local PlannerController = {}
PlannerController.__index = PlannerController

local PLANNER_OPTIONS = {
	MaxExpansions = 128,
	MaxPlanDepth = 6,
}

function PlannerController:ClearPlan(): ()
	self.state.currentGoal = nil
	self.state.currentActionId = nil
	self.state.currentPlan = nil
	self.state.currentActionIndex = 1
	self.state.actionStarted = false
	self.state.actionStartedAt = 0
	self.state.debugGoal = "None"
	self.state.debugAction = "None"
end

function PlannerController:RequestReplan(reason: string): ()
	self:ClearPlan()
	self.state.needsPlan = true
	self.state.replanReason = reason
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage.Packages.Util)

function PlannerController:Replan(now: number): boolean
	local facts = Goals.BuildFacts(self.state, self.blackboard, self.environment)
	local candidateGoals = Goals.BuildCandidateGoals(self.state, self.blackboard, facts)

	local bestPlan: Types.PlanResult = nil
	local bestPlanPriority = -math.huge
	local bestPlanGoal: Types.GOAPGoal = nil

	if self.runtime.config.Agent.DebugLog then
		self.state.inDepthDebugUIPlanText = "\n\nPlanner Log:\n"
		self.state.inDepthDebugUIPlanText ..= "\nFacts: "
		self.state.inDepthDebugUIPlanText ..= `{Util.StringifyTable(facts)}\n`

		self.state.inDepthDebugUIPlanText ..= "\nCandidate Goals:\n"

		for _, goal in ipairs(candidateGoals) do
			self.state.inDepthDebugUIPlanText ..= `{goal.id}: {goal.priority}\n`
		end
	end

	for _, goal in ipairs(candidateGoals) do
		local result = Planner.Plan(facts, goal.facts, Actions, PLANNER_OPTIONS)
		if result.success then
			if self.runtime.config.Agent.DebugLog then
				self.state.inDepthDebugUIPlanText ..= `\n{goal.id} Plan:\n`
				self.state.inDepthDebugUIPlanText ..= `{Util.StringifyTable(result)}\n`
			end

			if goal.priority > bestPlanPriority then
				bestPlan = result
				bestPlanPriority = goal.priority
				bestPlanGoal = goal
			end
		end
	end

	if bestPlan ~= nil then
		self.state.currentGoal = bestPlanGoal.id
		self.state.currentPlan = bestPlan.actions
		self.state.currentActionIndex = 1
		self.state.actionStarted = false
		self.state.actionStartedAt = now
		self.state.needsPlan = false
		self.state.debugGoal = bestPlanGoal.id
		self.state.debugAction = "None"
		return true
	end

	self.state.needsPlan = false
	self.state.replanReason = "planner_failed"
	return false
end

function PlannerController:GetCurrentAction(): Types.GOAPAction?
	local plan = self.state.currentPlan
	if not plan then
		return nil
	end
	return plan[self.state.currentActionIndex]
end

function PlannerController:Advance(now: number): ()
	self.state.currentActionIndex += 1
	self.state.actionStarted = false
	self.state.actionStartedAt = now
	self.state.arrived = false
	self.state.shotCompleted = false

	if not self.state.currentPlan or self.state.currentActionIndex > #self.state.currentPlan then
		self:RequestReplan("plan_complete")
	end
end

function PlannerController:Tick(dt: number, now: number): ()
	if self.state.needsPlan then
		self:Replan(now)
	end

	local action = self:GetCurrentAction()
	if not action then
		self:RequestReplan("missing_action")
		return
	end

	self.state.currentActionId = action.id
	self.state.debugAction = action.id

	local context = {
		dt = dt,
		now = now,
	}

	if not self.state.actionStarted then
		self.state.actionStarted = true
		self.state.actionStartedAt = now
		if action.start then
			action.start(self.controller, context)
		end
	end

	if action.check and action.check(self.controller, context) then
		if action.finish then
			action.finish(self.controller, context)
		end
		self:Advance(now)
		return
	end

	if action.update then
		action.update(self.controller, context)
	end
end

function PlannerController.new(runtime: Types.AgentRuntime): Types.PlannerController
	local self = setmetatable({}, PlannerController)
	self.runtime = runtime
	self.state = runtime.state
	self.blackboard = runtime.blackboard
	self.environment = runtime.environment
	self.controller = runtime.controller
	return self
end

return PlannerController
