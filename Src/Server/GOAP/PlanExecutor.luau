--[=[
	PlanExecutor

	Owns GOAP action execution. It applies planner results, creates the
	agent-specific AgentController passed to action modules, calls action
	lifecycle hooks, and advances or invalidates plans.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentController = require(CompyServerScripts.Agents.AgentController)

local PlanExecutor = {}

local function resetActionRuntime(agent: Types.Agent): ()
	agent.decision.actionRuntime.actionId = nil
	agent.decision.actionRuntime.started = false
	agent.decision.actionRuntime.startedAt = 0
end

local function resetMovementRequest(agent: Types.Agent): ()
	agent.movement.destination = nil
	agent.movement.path = nil
	agent.movement.pathIndex = 1
	agent.movement.needsPath = false
	agent.movement.pathQueued = false
	agent.movement.arrived = false
	agent.movement.mode = "Idle"
end

local function resetCombatRequest(agent: Types.Agent): ()
	agent.combat.targetId = nil
	agent.combat.shouldFire = false
	agent.combat.shotCompleted = false
end

function PlanExecutor.AssignPlan(agent: Types.Agent, goal: Types.GOAPGoal, planResult: Types.PlanResult, now: number): ()
	agent.decision.currentGoal = goal.id
	agent.decision.currentPlan = planResult.actions
	agent.decision.currentActionIndex = 1
	agent.decision.needsPlan = false
	agent.decision.planningQueued = false
	agent.decision.nextThinkAt = now
	agent.decision.lastPlanReason = "plan_assigned"

	resetActionRuntime(agent)
	resetMovementRequest(agent)
	resetCombatRequest(agent)
end

function PlanExecutor.GetCurrentAction(agent: Types.Agent): Types.GOAPAction?
	local plan = agent.decision.currentPlan
	if not plan then
		return nil
	end

	return plan[agent.decision.currentActionIndex]
end

function PlanExecutor.Advance(agent: Types.Agent, now: number): ()
	agent.decision.currentActionIndex = agent.decision.currentActionIndex + 1
	resetActionRuntime(agent)
	agent.movement.arrived = false
	agent.combat.shotCompleted = false

	if not agent.decision.currentPlan or agent.decision.currentActionIndex > #agent.decision.currentPlan then
		agent.decision.currentPlan = nil
		agent.decision.currentGoal = nil
		agent.decision.currentActionIndex = 1
		agent.decision.needsPlan = true
		agent.decision.nextThinkAt = now
	end
end

function PlanExecutor.Invalidate(agent: Types.Agent, now: number, reason: string?): ()
	agent.decision.currentPlan = nil
	agent.decision.currentGoal = nil
	agent.decision.currentActionIndex = 1
	agent.decision.needsPlan = true
	agent.decision.nextThinkAt = now
	agent.decision.lastPlanReason = reason or "invalidated"

	resetActionRuntime(agent)
	resetMovementRequest(agent)
	resetCombatRequest(agent)
end

function PlanExecutor.StepAgent(agent: Types.Agent, deps: Types.SystemDependencies, dt: number, now: number): ()
	if not agent.stats.alive then
		return
	end

	local action = PlanExecutor.GetCurrentAction(agent)
	if not action then
		agent.decision.needsPlan = true
		return
	end

	local blackboard = deps.blackboards[agent.teamId]
	if not blackboard then
		PlanExecutor.Invalidate(agent, now, "missing_blackboard")
		return
	end

	local controller = AgentController.new(agent, {
		config = deps.config,
		agentStore = deps.agentStore,
		blackboard = blackboard,
		worldQuery = deps.adapters.worldQuery,
	})

	local context: Types.GOAPActionContext = {
		dt = dt,
		now = now,
	}

	local runtime = agent.decision.actionRuntime
	if not runtime.started or runtime.actionId ~= action.id then
		runtime.actionId = action.id
		runtime.started = true
		runtime.startedAt = now
		agent.movement.arrived = false
		agent.combat.shotCompleted = false
		action.onActionStart(controller, context)
	end

	if action.checkAction(controller, context) then
		action.onActionEnd(controller, context)
		PlanExecutor.Advance(agent, now)
		return
	end

	action.onActionUpdate(controller, context)
end

function PlanExecutor.StepAll(deps: Types.SystemDependencies, dt: number, now: number): ()
	for _, agent in ipairs(deps.agentStore:GetAll()) do
		PlanExecutor.StepAgent(agent, deps, dt, now)
	end
end

return PlanExecutor
