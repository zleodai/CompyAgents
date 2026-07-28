--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local AgentConfig = require(ReplicatedStorage.CompyAgent.Config.AgentConfig)

local Goals = require(ServerScriptService.CompyAgent.GOAP.Goals)
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)

local Actions = require(CompyServerScripts.GOAP.Actions)
local GOAPPlanner = require(CompyServerScripts.GOAP.GOAPPlanner)

local PlannerModule = {}
PlannerModule.__index = PlannerModule

type PlannerState = {
	active: boolean,

	actions: { [string]: Types.Action },
	goals: { [string]: Types.Goal },

	controller: SPHController.SPHController?,

	plan: { Types.Action },
	planIndx: number,

	beliefs: { [string]: boolean },
	agentData: Types.AgentSharedData?,

	goal: Types.Goal?,
	action: Types.Action?,

	planSuccess: boolean,
	needsReplan: boolean,
	replanReason: string,

	lastFailedPlanAt: number,
	failedPlanCooldown: number,
}

export type Planner = typeof(setmetatable({} :: PlannerState, PlannerModule))

function PlannerModule.new(): Planner
	return setmetatable({
		active = false,

		actions = {},
		goals = {},

		controller = nil,

		plan = {},
		planIndx = 0,

		beliefs = {},
		agentData = nil,

		goal = nil,
		action = nil,

		planSuccess = false,
		needsReplan = false,
		replanReason = "",

		lastFailedPlanAt = 0,
		failedPlanCooldown = AgentConfig.FailedPlanCooldown,
	}, PlannerModule)
end

local function makePlan(self: Planner, data: Types.AgentSharedData): ()
	if not self.active or not self.controller then
		return
	end

	if self.action and self.action.End then
		self.action.End(self.action.actionData, self.controller, data)
	end
	self.planSuccess = false
	self.plan = {}
	self.planIndx = 0
	self.goal = nil
	self.action = nil

	local planData = GOAPPlanner.MakePlan(self.beliefs, self.actions, self.goals)

	if not planData.success or #planData.plan == 0 then
		self.needsReplan = true
		self.replanReason = "[ makePlan ] MakePlan failed"
		self.lastFailedPlanAt = os.clock()
		return
	end

	local firstAction = planData.plan[1]
	if not firstAction then
		self.needsReplan = true
		self.replanReason = "[ makePlan ] MakePlan returned invalid plan"
		self.lastFailedPlanAt = os.clock()
		return
	end

	self.goal = planData.goal
	self.plan = planData.plan
	self.planIndx = 1
	self.action = firstAction
	self.planSuccess = true
	self.needsReplan = false
	self.replanReason = ""

	if firstAction.Start then
		firstAction.Start(firstAction.actionData, self.controller, data)
	end
end

local function handleAction(self: Planner, data: Types.AgentSharedData, dt: number): ()
	if not self.active or not self.controller then
		return
	end

	if not self.action then
		self.needsReplan = true
		self.replanReason = "[ handleAction ] action is nil"
		return
	end
	local action: Types.Action = self.action

	if action.FinishedCheck(action.actionData, self.controller, data) then
		if action.End then
			action.End(action.actionData, self.controller, data)
		end
		self.planIndx += 1
		local nextAction = self.plan[self.planIndx]
		self.action = nextAction

		if nextAction then
			if nextAction.Start then
				nextAction.Start(nextAction.actionData, self.controller, data)
			end
		else
			self.needsReplan = true
			self.replanReason = "[ handleAction ] plan finished"
		end
		return
	end

	if action.Update then
		action.Update(action.actionData, self.controller, data, dt)
	end
end

function PlannerModule.Awake(self: Planner, controller: SPHController.SPHController): ()
	self.actions = Actions.New()
	self.goals = Goals.All()
	self.controller = controller
	self.active = true
end

function PlannerModule.Update(self: Planner, beliefs: { [string]: boolean }, agentData: Types.AgentSharedData, dt: number): ()
	if not self.active or not self.controller then
		return
	end

	self.beliefs = beliefs
	self.agentData = agentData

	if not self.needsReplan then
		handleAction(self, agentData, dt)
		return
	end

	-- Replan Cooldown Check
	if os.clock() - self.lastFailedPlanAt < self.failedPlanCooldown then
		return
	end

	makePlan(self, agentData)
end

function PlannerModule.ForceStop(self: Planner, data: Types.AgentSharedData): ()
	if not self.active or not self.controller then
		return
	end

	if self.action then
		if self.action.End then
			self.action.End(self.action.actionData, self.controller, data)
		end
		self.action = nil
	end

	self.active = false
end

function PlannerModule.Replan(self: Planner, reason: string): ()
	self.needsReplan = true
	self.replanReason = reason
end

return PlannerModule
