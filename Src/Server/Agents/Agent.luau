--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Types = require(CompyServerScripts.Core.Types)
local Enums = require(CompyServerScripts.Core.Enums)

local ActionRegistry = require(CompyServerScripts.GOAP.Actions)
local GOAPPlanner = require(CompyServerScripts.GOAP.Planner)

local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local VisionSensor = require(CompyServerScripts.Agents.Sensors.VisionSensor)
local InventoryModule = require(CompyServerScripts.Agents.Modules.InventoryModule)

local _DefaultCadenceConfig = require(CompySharedScripts.Config.CadenceConfig)

local Agent = {}
Agent.__index = Agent

export type PlannerState = {
	plan: ActionRegistry.ActionList,
	goal: GOAPPlanner.Goal?,
	beliefs: { [string]: boolean },
	goapAction: ActionRegistry.Action?,
	planIndx: number,
	planSuccess: boolean,
	lastFailedPlanAt: number,
	failedPlanCooldown: number,
}

type AgentData = {
	id: number,
	sightedEnemyLocs: { Vector3 },
	sightedObjectiveLocs: { Vector3 },
	sightedCrouchCoverLocs: { Vector3 },
	sightedProneCoverLocs: { Vector3 },

	behaviourState: Types.BehaviourState,
	behaviourRequest: Types.BehaviourState?,
	requestChangeBehaviour: (Types.BehaviourState) -> (),
	requestReplan: (string) -> (),

	Actions: ActionRegistry.ActionSet,
	agentActionData: Types.AgentActionData,

	needsReplan: boolean,
	plannerState: PlannerState,

	controller: SPHController.SPHController,
	visionSensor: VisionSensor.VisionSensor,
	inventoryModule: InventoryModule.InventoryModule,

	heartBeat: RBXScriptConnection?,
	cadence: typeof(_DefaultCadenceConfig),
	visionElapsed: number,
	plannerElapsed: number,

	ended: boolean,

	startRuntime: () -> (),
	endRuntime: () -> (),
}

local function createEmptyPlan(): { Types.Action }
	return {}
end

function Agent.RequestChangeBehaviour(self: AgentData, request: Types.BehaviourState): ()
	self.behaviourRequest = request
end

function Agent.RequestReplan(self: AgentData, _reason: string): ()
	self.needsReplan = true
end

local function getActionData(self: AgentData): Types.AgentActionData
	return {
		sightedEnemyLocs = self.sightedEnemyLocs,
		sightedObjectiveLocs = self.sightedObjectiveLocs,
		sightedCrouchCoverLocs = self.sightedCrouchCoverLocs,
		sightedProneCoverLocs = self.sightedProneCoverLocs,
		behaviourState = self.behaviourState,
		RequestChangeBehaviour = self.requestChangeBehaviour,
		RequestReplan = self.requestReplan,
	} :: Types.AgentActionData
end

local function constructBeliefs(self: AgentData): ()
	local stance = self.controller:GetStance()

	local standing = stance == Enums.Posture.Standing
	local crouched = stance == Enums.Posture.Crouching
	local proned = stance == Enums.Posture.Proning
	local enemyVisible = #self.sightedEnemyLocs > 0

	local health = self.controller:GetHumanoid().Health

	local lowHealth = health <= 35

	local ammo, _ = self.controller:GetAmmo()

	self.plannerState.beliefs = {
		objectiveCaptured = false,
		crouchCoverInRange = #self.sightedCrouchCoverLocs > 0,
		lowHealth = lowHealth,
		hasObjectivePos = #self.sightedObjectiveLocs > 0,
		inCrouchCover = crouched,
		inProneCover = proned,
		proneCoverInRange = #self.sightedProneCoverLocs > 0,
		hasAmmo = ammo > 0,
		inDanger = enemyVisible and lowHealth,
		standing = standing,
		crouched = crouched,
		proned = proned,
		hasEnemyPos = enemyVisible,
		enemyEngaged = self.behaviourState.behaviour == Enums.Behaviour.EngagingEnemy,
	}
end

local function makePlan(self: AgentData): ()
	local previousAction = self.plannerState.goapAction
	if previousAction then
		previousAction.End(self.controller, self.agentActionData)
	end

	local planData = GOAPPlanner.MakePlan(self.plannerState.beliefs, self.Actions)
	self.plannerState.planSuccess = planData.success

	if not planData.success or #planData.plan == 0 then
		self.plannerState.plan = createEmptyPlan()
		self.plannerState.goal = nil
		self.plannerState.goapAction = nil
		self.plannerState.lastFailedPlanAt = os.clock()
		return
	end

	self.plannerState.plan = planData.plan
	self.plannerState.planIndx = 1
	self.plannerState.goal = planData.goal
	local firstAction = self.plannerState.plan[1]
	if not firstAction then
		self.plannerState.planSuccess = false
		self.plannerState.lastFailedPlanAt = os.clock()
		return
	end
	self.plannerState.goapAction = firstAction
	firstAction.Start(self.controller, self.agentActionData)
end

local function handleGOAPAction(self: AgentData, dt: number): ()
	local goapAction = self.plannerState.goapAction
	if not goapAction then
		self.requestReplan("GOAPAction missing")
		return
	end

	if goapAction.FinishedCheck(self.controller, self.agentActionData) then
		goapAction.End(self.controller, self.agentActionData)
		self.plannerState.planIndx += 1
		self.plannerState.goapAction = self.plannerState.plan[self.plannerState.planIndx]

		local nextAction = self.plannerState.goapAction
		if nextAction then
			nextAction.Start(self.controller, self.agentActionData)
		else
			self.requestReplan("Plan finished")
		end
		return
	end

	goapAction.Update(self.controller, self.agentActionData, dt)
end

local function updatePlanner(self: AgentData, dt: number): ()
	if not self.needsReplan then
		handleGOAPAction(self, dt)
		return
	end

	if os.clock() - self.plannerState.lastFailedPlanAt < self.plannerState.failedPlanCooldown then
		return
	end

	constructBeliefs(self)
	makePlan(self)
	if self.plannerState.planSuccess then
		self.needsReplan = false
	end
end

function Agent.Update(self: AgentData, dt: number): ()
	self.visionElapsed += dt
	if self.visionElapsed >= self.cadence.VisionInterval then
		self.visionElapsed = 0
		self.visionSensor:Sense()
	end

	local health = self.controller:GetHumanoid().Health
	if health <= 0 then
		Agent.End(self)
		return
	end

	self.agentActionData = getActionData(self) -- Update once

	self.plannerElapsed += dt
	if self.plannerElapsed >= self.cadence.PlannerInterval then
		local plannerDelta = self.plannerElapsed
		self.plannerElapsed = 0
		updatePlanner(self, plannerDelta)
	end
end

function Agent.Start(self: AgentData): ()
	if self.ended or self.heartBeat then
		return
	end

	self.heartBeat = RunService.Heartbeat:Connect(function(dt: number): ()
		Agent.Update(self, dt)
	end)
end

function Agent.End(self: AgentData): ()
	if self.ended then
		return
	end
	self.ended = true
	local heartBeat = self.heartBeat
	self.heartBeat = nil
	if heartBeat then
		heartBeat:Disconnect()
	end

	local goapAction = self.plannerState.goapAction
	if goapAction then
		goapAction.End(self.controller, self.agentActionData)
		self.plannerState.goapAction = nil
	end
end

export type Agent = typeof(setmetatable({} :: AgentData, Agent))

function Agent.new(params: {
	id: number,
	magazines: number,
	fovX: number,
	fovY: number,
	visionDistance: number,
	failedPlanCooldown: number?,
	controller: SPHController.SPHController,
	cadence: typeof(_DefaultCadenceConfig),
}): Agent
	local inventory = InventoryModule.new(params.magazines)
	local data: AgentData = {
		id = params.id,
		sightedEnemyLocs = {},
		sightedObjectiveLocs = {},
		sightedCrouchCoverLocs = {},
		sightedProneCoverLocs = {},

		behaviourState = {
			behaviour = Enums.Behaviour.None,
			behaviourParams = nil,
		},
		behaviourRequest = nil,
		requestChangeBehaviour = function(_request: Types.BehaviourState): () end,
		requestReplan = function(_message: string): () end,

		Actions = {} :: ActionRegistry.ActionSet,
		agentActionData = {} :: Types.AgentActionData,

		needsReplan = true,
		plannerState = {
			plan = createEmptyPlan(),
			goal = nil,
			beliefs = {},
			goapAction = nil,
			planIndx = 1,
			planSuccess = false,
			lastFailedPlanAt = -math.huge,
			failedPlanCooldown = params.failedPlanCooldown or 0.5,
		},

		controller = params.controller,
		visionSensor = VisionSensor.blank(),
		inventoryModule = inventory,

		heartBeat = nil,
		cadence = params.cadence,
		visionElapsed = params.cadence.VisionInterval,
		plannerElapsed = params.cadence.PlannerInterval,

		ended = false,

		startRuntime = function(): () end,
		endRuntime = function(): () end,
	}
	data.requestChangeBehaviour = function(request: Types.BehaviourState): ()
		Agent.RequestChangeBehaviour(data, request)
	end
	data.startRuntime = function(): ()
		Agent.Start(data)
	end
	data.endRuntime = function(): ()
		Agent.End(data)
	end
	data.Actions = ActionRegistry.new()

	data.visionSensor =
		VisionSensor.new(data, data.id, data.controller:GetModel(), params.fovX, params.fovY, params.visionDistance)

	return setmetatable(data, Agent)
end

return Agent
