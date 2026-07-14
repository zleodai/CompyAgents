--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)
local RifleData = require(CompyServerScripts.Data.RifleData)
local Actions = require(CompyServerScripts.GOAP.Actions)
local _Goals = require(CompyServerScripts.GOAP.Goals)
local GOAPPlanner = require(CompyServerScripts.GOAP.Planner)
local VisionSensor = require(CompyServerScripts.Agents.Sensors.VisionSensor)
local DamageSensor = require(CompyServerScripts.Agents.Sensors.DamageSensor)
local PathfindingModule = require(CompyServerScripts.Agents.Modules.PathfindingModule)
local InventoryModule = require(CompyServerScripts.Agents.Modules.InventoryModule)
local Behaviours = require(CompyServerScripts.Agents.Behaviours)
local FindEnemyLocation = require(CompyServerScripts.GOAP.Actions.FindEnemyLocation)
local EngageEnemy = require(CompyServerScripts.GOAP.Actions.EngageEnemy)
local Reload = require(CompyServerScripts.GOAP.Actions.Reload)
local FindObjective = require(CompyServerScripts.GOAP.Actions.FindObjective)
local CaptureObjective = require(CompyServerScripts.GOAP.Actions.CaptureObjective)
local TakeCrouchCover = require(CompyServerScripts.GOAP.Actions.TakeCrouchCover)
local TakeProneCover = require(CompyServerScripts.GOAP.Actions.TakeProneCover)
local StandFromCrouchCover = require(CompyServerScripts.GOAP.Actions.StandFromCrouchCover)
local CrouchFromProneCover = require(CompyServerScripts.GOAP.Actions.CrouchFromProneCover)
local _DefaultCadenceConfig = require(CompySharedScripts.Config.CadenceConfig)
local _DefaultNoobPathConfig = require(CompySharedScripts.Config.NoobPathConfig)

local Agent = {}
Agent.__index = Agent

export type BehaviourState = {
	behaviour: number,
	behaviourParams: {
		targetPosition: Vector3?,
		posture: number?,
	}?,
}

export type PlannerState = {
	plan: typeof(Actions),
	goal: typeof(_Goals[1])?,
	beliefs: { [string]: boolean },
	goapAction: typeof(Actions[1])?,
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
	health: number,
	behaviourState: BehaviourState,
	behaviourRequest: BehaviourState?,
	posture: number,
	movement: number,
	equippedRifle: number,
	rifleAmmo: number,
	needsReplan: boolean,
	heartBeat: RBXScriptConnection?,
	character: Model,
	moveSpeed: number,
	plannerState: PlannerState,
	sensors: {
		visionSensor: { Sense: () -> () },
		damageSensor: { Sense: () -> () },
	},
	cadence: typeof(_DefaultCadenceConfig),
	visionElapsed: number,
	damageElapsed: number,
	plannerElapsed: number,
	ended: boolean,
	pathfinding: PathfindingModule.PathfindingModule,
	inventory: InventoryModule.InventoryModule,
	modules: {
		pathfinding: PathfindingModule.PathfindingModule,
		inventory: InventoryModule.InventoryModule,
	},
	strategies: {
		[number]: {
			Reset: () -> (),
			Progress: (number) -> (),
			Finished: () -> boolean,
		},
	},
	requestChangeBehaviour: (BehaviourState) -> (),
	tryReload: () -> boolean,
	startRuntime: () -> (),
	endRuntime: () -> (),
}

local function createEmptyPlan(): typeof(Actions)
	local plan = table.clone(Actions)
	table.clear(plan)
	return plan
end

local function startGOAPAction(self: AgentData, actionId: string): ()
	local data = self
	if actionId == FindEnemyLocation.id then
		FindEnemyLocation.Start(data)
	elseif actionId == EngageEnemy.id then
		EngageEnemy.Start(data)
	elseif actionId == Reload.id then
		Reload.Start(data)
	elseif actionId == FindObjective.id then
		FindObjective.Start(data)
	elseif actionId == CaptureObjective.id then
		CaptureObjective.Start(data)
	elseif actionId == TakeCrouchCover.id then
		TakeCrouchCover.Start(data)
	elseif actionId == TakeProneCover.id then
		TakeProneCover.Start(data)
	elseif actionId == StandFromCrouchCover.id then
		StandFromCrouchCover.Start(data)
	elseif actionId == CrouchFromProneCover.id then
		CrouchFromProneCover.Start(data)
	else
		Agent.RequestReplan(self, "Unknown GOAPAction")
	end
end

local function updateGOAPAction(self: AgentData, actionId: string, dt: number): ()
	local data = self
	if actionId == FindEnemyLocation.id then
		FindEnemyLocation.Update(data, dt)
	elseif actionId == EngageEnemy.id then
		EngageEnemy.Update(data, dt)
	elseif actionId == Reload.id then
		Reload.Update(data, dt)
	elseif actionId == FindObjective.id then
		FindObjective.Update(data, dt)
	elseif actionId == CaptureObjective.id then
		CaptureObjective.Update(data, dt)
	elseif actionId == TakeCrouchCover.id then
		TakeCrouchCover.Update(data, dt)
	elseif actionId == TakeProneCover.id then
		TakeProneCover.Update(data, dt)
	elseif actionId == StandFromCrouchCover.id then
		StandFromCrouchCover.Update(data, dt)
	elseif actionId == CrouchFromProneCover.id then
		CrouchFromProneCover.Update(data, dt)
	end
end

local function finishedGOAPAction(self: AgentData, actionId: string): boolean
	local data = self
	if actionId == FindEnemyLocation.id then
		return FindEnemyLocation.FinishedCheck(data)
	elseif actionId == EngageEnemy.id then
		return EngageEnemy.FinishedCheck(data)
	elseif actionId == Reload.id then
		return Reload.FinishedCheck(data)
	elseif actionId == FindObjective.id then
		return FindObjective.FinishedCheck(data)
	elseif actionId == CaptureObjective.id then
		return CaptureObjective.FinishedCheck(data)
	elseif actionId == TakeCrouchCover.id then
		return TakeCrouchCover.FinishedCheck(data)
	elseif actionId == TakeProneCover.id then
		return TakeProneCover.FinishedCheck(data)
	elseif actionId == StandFromCrouchCover.id then
		return StandFromCrouchCover.FinishedCheck(data)
	elseif actionId == CrouchFromProneCover.id then
		return CrouchFromProneCover.FinishedCheck(data)
	end
	return false
end

local function endGOAPAction(self: AgentData, actionId: string): ()
	local data = self
	if actionId == FindEnemyLocation.id then
		FindEnemyLocation.End(data)
	elseif actionId == EngageEnemy.id then
		EngageEnemy.End(data)
	elseif actionId == Reload.id then
		Reload.End(data)
	elseif actionId == FindObjective.id then
		FindObjective.End(data)
	elseif actionId == CaptureObjective.id then
		CaptureObjective.End(data)
	elseif actionId == TakeCrouchCover.id then
		TakeCrouchCover.End(data)
	elseif actionId == TakeProneCover.id then
		TakeProneCover.End(data)
	elseif actionId == StandFromCrouchCover.id then
		StandFromCrouchCover.End(data)
	elseif actionId == CrouchFromProneCover.id then
		CrouchFromProneCover.End(data)
	end
end

local function constructBeliefs(self: AgentData): ()
	local standing = self.posture == Enums.Posture.Standing
	local crouched = self.posture == Enums.Posture.Crouching
	local proned = self.posture == Enums.Posture.Proning
	local enemyVisible = #self.sightedEnemyLocs > 0
	local lowHealth = self.health <= 35

	self.plannerState.beliefs = {
		objectiveCaptured = false,
		crouchCoverInRange = #self.sightedCrouchCoverLocs > 0,
		lowHealth = lowHealth,
		hasObjectivePos = #self.sightedObjectiveLocs > 0,
		inCrouchCover = crouched,
		inProneCover = proned,
		proneCoverInRange = #self.sightedProneCoverLocs > 0,
		hasAmmo = self.rifleAmmo > 0,
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
		endGOAPAction(self, previousAction.id)
	end

	local planData = GOAPPlanner.MakePlan(self.plannerState.beliefs)
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
	startGOAPAction(self, firstAction.id)
end

local function handleGOAPAction(self: AgentData, dt: number): ()
	local goapAction = self.plannerState.goapAction
	if not goapAction then
		Agent.RequestReplan(self, "GOAPAction missing")
		return
	end

	if finishedGOAPAction(self, goapAction.id) then
		endGOAPAction(self, goapAction.id)
		self.plannerState.planIndx += 1
		self.plannerState.goapAction = self.plannerState.plan[self.plannerState.planIndx]

		local nextAction = self.plannerState.goapAction
		if nextAction then
			startGOAPAction(self, nextAction.id)
		else
			Agent.RequestReplan(self, "Plan finished")
		end
		return
	end

	updateGOAPAction(self, goapAction.id, dt)
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

function Agent.RequestChangeBehaviour(self: AgentData, request: BehaviourState): ()
	self.behaviourRequest = request
end

function Agent.RequestReplan(self: AgentData, _reason: string): ()
	self.needsReplan = true
end

function Agent.TryReload(self: AgentData): boolean
	if not self.inventory:TryTakeMagazine() then
		return false
	end

	local rifleData = RifleData[self.equippedRifle]
	if not rifleData then
		self.inventory:StoreMagazine()
		return false
	end

	self.rifleAmmo = rifleData.ammoInMagazine
	return true
end

function Agent.HandleBehaviour(self: AgentData, dt: number): ()
	local request = self.behaviourRequest
	if request then
		local previousStrategy = self.strategies[self.behaviourState.behaviour]
		if previousStrategy then
			previousStrategy.Reset()
		end

		self.behaviourState = request
		self.behaviourRequest = nil :: BehaviourState?
		return
	end

	if self.behaviourState.behaviour == Enums.Behaviour.None then
		return
	end

	local strategy = self.strategies[self.behaviourState.behaviour]
	if not strategy then
		self.behaviourState = {
			behaviour = Enums.Behaviour.None,
			behaviourParams = nil,
		}
		Agent.RequestReplan(self, "Behaviour strategy missing")
		return
	end

	if strategy.Finished() then
		strategy.Reset()
		self.behaviourState = {
			behaviour = Enums.Behaviour.None,
			behaviourParams = nil,
		}
		return
	end

	strategy.Progress(dt)
end

function Agent.Update(self: AgentData, dt: number): ()
	self.damageElapsed += dt
	if self.damageElapsed >= self.cadence.DamageInterval then
		self.damageElapsed = 0
		self.sensors.damageSensor.Sense()
	end

	self.visionElapsed += dt
	if self.visionElapsed >= self.cadence.VisionInterval then
		self.visionElapsed = 0
		self.sensors.visionSensor.Sense()
	end

	local humanoid = self.character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = self.health
	end

	if self.health <= 0 then
		Agent.End(self)
		return
	end

	self.plannerElapsed += dt
	if self.plannerElapsed >= self.cadence.PlannerInterval then
		local plannerDelta = self.plannerElapsed
		self.plannerElapsed = 0
		updatePlanner(self, plannerDelta)
	end
	Agent.HandleBehaviour(self, dt)
	self.pathfinding:Update(self.character, self.moveSpeed)
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

	for _, strategy in pairs(self.strategies) do
		strategy.Reset()
	end
	self.pathfinding:Destroy()
end

export type Agent = typeof(setmetatable({} :: AgentData, Agent))

function Agent.new(params: {
	id: number,
	character: Model,
	health: number,
	moveSpeed: number,
	equippedRifle: number,
	rifleAmmo: number,
	magazines: number,
	fovX: number,
	fovY: number,
	visionDistance: number,
	failedPlanCooldown: number?,
	cadence: typeof(_DefaultCadenceConfig),
	noobPath: typeof(_DefaultNoobPathConfig),
	senseWorld: (
		number,
		Model,
		number,
		number,
		number
	) -> {
		enemyLocations: { Vector3 },
		objectiveLocations: { Vector3 },
		crouchCoverLocations: { Vector3 },
		proneCoverLocations: { Vector3 },
	},
	checkDamage: (number) -> number,
	engageEnemy: (number, Model, Vector3, number) -> boolean,
}): Agent
	local pathfinding = PathfindingModule.new(params.character, params.noobPath)
	local inventory = InventoryModule.new(params.magazines)
	local data: AgentData = {
		id = params.id,
		sightedEnemyLocs = {},
		sightedObjectiveLocs = {},
		sightedCrouchCoverLocs = {},
		sightedProneCoverLocs = {},
		health = params.health,
		behaviourState = {
			behaviour = Enums.Behaviour.None,
			behaviourParams = nil,
		},
		behaviourRequest = nil,
		posture = Enums.Posture.Standing,
		movement = Enums.Movement.Idle,
		equippedRifle = params.equippedRifle,
		rifleAmmo = params.rifleAmmo,
		needsReplan = true,
		heartBeat = nil,
		character = params.character,
		moveSpeed = params.moveSpeed,
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
		sensors = {
			visionSensor = {
				Sense = function(): () end,
			},
			damageSensor = {
				Sense = function(): () end,
			},
		},
		cadence = params.cadence,
		visionElapsed = params.cadence.VisionInterval,
		damageElapsed = params.cadence.DamageInterval,
		plannerElapsed = params.cadence.PlannerInterval,
		ended = false,
		pathfinding = pathfinding,
		inventory = inventory,
		modules = {
			pathfinding = pathfinding,
			inventory = inventory,
		},
		strategies = {},
		requestChangeBehaviour = function(_request: BehaviourState): () end,
		tryReload = function(): boolean
			return false
		end,
		startRuntime = function(): () end,
		endRuntime = function(): () end,
	}
	data.requestChangeBehaviour = function(request: BehaviourState): ()
		Agent.RequestChangeBehaviour(data, request)
	end
	data.tryReload = function(): boolean
		return Agent.TryReload(data)
	end
	data.startRuntime = function(): ()
		Agent.Start(data)
	end
	data.endRuntime = function(): ()
		Agent.End(data)
	end

	local visionSensor = VisionSensor.new(
		data,
		data.id,
		data.character,
		params.fovX,
		params.fovY,
		params.visionDistance,
		params.senseWorld
	)
	local damageSensor = DamageSensor.new(data, data.id, params.checkDamage)
	data.sensors.visionSensor = {
		Sense = function(): ()
			visionSensor:Sense()
		end,
	}
	data.sensors.damageSensor = {
		Sense = function(): ()
			damageSensor:Sense()
		end,
	}

	local engagingBehaviour = Behaviours.EngagingBehaviour.new(data, params.engageEnemy)
	local takeCoverBehaviour = Behaviours.TakeCoverBehaviour.new(data, function(target: Vector3?): ()
		data.pathfinding:SetTarget(target)
	end)
	local captureObjectiveBehaviour = Behaviours.CaptureObjectiveBehaviour.new(data, function(target: Vector3?): ()
		data.pathfinding:SetTarget(target)
	end)

	data.strategies[Enums.Behaviour.EngagingEnemy] = {
		Reset = function(): ()
			engagingBehaviour:Reset()
		end,
		Progress = function(dt: number): ()
			engagingBehaviour:Progress(dt)
		end,
		Finished = function(): boolean
			return engagingBehaviour:Finished()
		end,
	}
	data.strategies[Enums.Behaviour.InCover] = {
		Reset = function(): ()
			takeCoverBehaviour:Reset()
		end,
		Progress = function(dt: number): ()
			takeCoverBehaviour:Progress(dt)
		end,
		Finished = function(): boolean
			return takeCoverBehaviour:Finished()
		end,
	}
	data.strategies[Enums.Behaviour.CapturingObjective] = {
		Reset = function(): ()
			captureObjectiveBehaviour:Reset()
		end,
		Progress = function(dt: number): ()
			captureObjectiveBehaviour:Progress(dt)
		end,
		Finished = function(): boolean
			return captureObjectiveBehaviour:Finished()
		end,
	}

	return setmetatable(data, Agent)
end

return Agent
