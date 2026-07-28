--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local VisionSensor = require(CompyServerScripts.Agents.Sensors.VisionSensor)
local InventoryModule = require(CompyServerScripts.Agents.Modules.InventoryModule)
local PlannerModule = require(CompyServerScripts.Agents.Modules.PlannerModule)
local Team = require(CompySharedScripts.Team)

local _DefaultAgentConfig = require(CompySharedScripts.Config.AgentConfig)
local _DefaultCadenceConfig = require(CompySharedScripts.Config.CadenceConfig)

local Agent = {}
Agent.__index = Agent

type AgentData = {
	id: number,
	teamId: Team.Id,

	agentConfig: typeof(_DefaultAgentConfig),
	cadenceConfig: typeof(_DefaultCadenceConfig),

	noisyEnemyDirection: Vector3,
	noisyObjectiveDirection: Vector3,
	sightedEnemyLocs: { BasePart },
	sightedObjectiveLocs: { Vector3 },
	sightedCrouchCoverLocs: { Vector3 },
	sightedProneCoverLocs: { Vector3 },

	behaviourState: Types.BehaviourState,
	behaviourRequest: Types.BehaviourState?,

	controller: SPHController.SPHController,
	vision: VisionSensor.VisionSensor,
	inventory: InventoryModule.Inventory,
	planner: PlannerModule.Planner,

	heartBeat: RBXScriptConnection?,
	visionElapsed: number,
	plannerElapsed: number,

	active: boolean,
	ended: boolean,
}

local function requestChangeBehaviour(self: Agent, request: Types.BehaviourState): ()
	self.behaviourRequest = request
end

local function requestReplan(self: Agent, reason: string): ()
	self.planner:Replan(reason)
end

local function requestMagazine(self: Agent): boolean
	return self.inventory:TryTakeMagazine()
end

local function getSharedData(self: Agent): Types.AgentSharedData
	return {
		teamId = self.teamId,
		noisyEnemyDirection = self.noisyEnemyDirection,
		noisyObjectiveDirection = self.noisyObjectiveDirection,
		sightedEnemyLocs = self.sightedEnemyLocs,
		sightedObjectiveLocs = self.sightedObjectiveLocs,
		sightedCrouchCoverLocs = self.sightedCrouchCoverLocs,
		sightedProneCoverLocs = self.sightedProneCoverLocs,
		behaviourState = self.behaviourState,
		RequestChangeBehaviour = function(request: Types.BehaviourState)
			requestChangeBehaviour(self, request)
		end,
		RequestReplan = function(reason: string)
			requestReplan(self, reason)
		end,
		RequestMagazine = function(): boolean
			return requestMagazine(self)
		end,
	} :: Types.AgentSharedData
end

local function constructBeliefs(self: Agent): { [string]: boolean }
	local stance = self.controller:GetStance()

	local standing = stance == "Standing"
	local crouched = stance == "Crouching"
	local proned = stance == "Proning"
	local enemyVisible = #self.sightedEnemyLocs > 0

	local health = self.controller:GetHumanoid().Health

	local lowHealth = health <= 35

	local ammo, _ = self.controller:GetAmmo()

	return {
		objectiveCaptured = false,
		crouchCoverInRange = #self.sightedCrouchCoverLocs > 0,
		lowHealth = lowHealth,
		hasObjectivePos = #self.sightedObjectiveLocs > 0,
		inCrouchCover = false,
		inProneCover = false,
		proneCoverInRange = #self.sightedProneCoverLocs > 0,
		hasAmmo = ammo > 0,
		inDanger = enemyVisible and lowHealth,
		standing = standing,
		crouched = crouched,
		proned = proned,
		hasEnemyPos = enemyVisible,
		enemyEngaged = self.behaviourState.behaviour == "EngagingEnemy",
	}
end

function Agent.Update(self: Agent, dt: number): ()
	self.visionElapsed += dt
	if self.visionElapsed >= self.cadenceConfig.VisionInterval then
		self.visionElapsed = 0
		self.vision:Sense()
	end

	local health = self.controller:GetHumanoid().Health
	if health <= 0 then
		Agent.End(self)
		return
	end

	self.plannerElapsed += dt
	if self.plannerElapsed >= self.cadenceConfig.PlannerInterval then
		local agentSharedData = getSharedData(self)
		local beliefs = constructBeliefs(self)

		local plannerDelta = self.plannerElapsed
		self.plannerElapsed = 0
		self.planner:Update(beliefs, agentSharedData, plannerDelta)
	end
end

function Agent.Start(self: Agent): ()
	if self.active or self.ended then
		return
	end
	self.active = true

	self.planner:Awake(self.controller)
	self.vision:Awake()

	self.heartBeat = RunService.Heartbeat:Connect(function(dt: number): ()
		Agent.Update(self, dt)
	end)
end

function Agent.End(self: Agent): ()
	if self.ended then
		return
	end

	self.active = false
	self.ended = true

	if self.heartBeat then
		self.heartBeat:Disconnect()
		self.heartBeat = nil
	end

	self.planner:ForceStop(getSharedData(self))
	self.controller:Destroy()
end

export type Agent = typeof(setmetatable({} :: AgentData, Agent))

function Agent.new(
	id: number,
	teamId: Team.Id,
	controller: SPHController.SPHController,
	agentConfig: typeof(_DefaultAgentConfig),
	cadenceConfig: typeof(_DefaultCadenceConfig),
	visionDependencies: VisionSensor.Dependencies
): Agent
	assert(teamId ~= "", "Agent teamId must not be empty")
	assert(controller:GetTeamId() == teamId, "Agent teamId must match its SPHController teamId")
	local agentData: AgentData = {
		id = id,
		teamId = teamId,

		agentConfig = agentConfig,
		cadenceConfig = cadenceConfig,

		noisyEnemyDirection = Vector3.zero,
		noisyObjectiveDirection = Vector3.zero,
		sightedEnemyLocs = {},
		sightedObjectiveLocs = {},
		sightedCrouchCoverLocs = {},
		sightedProneCoverLocs = {},

		behaviourState = {
			behaviour = "None",
			behaviourParams = nil,
		} :: Types.BehaviourState,
		behaviourRequest = nil,

		controller = controller,
		vision = VisionSensor.Blank,
		inventory = InventoryModule.New(agentConfig.InitialMagazines),
		planner = PlannerModule.new(),

		heartBeat = nil,
		visionElapsed = cadenceConfig.VisionInterval,
		plannerElapsed = cadenceConfig.PlannerInterval,

		active = false,
		ended = false,
	}

	agentData.vision = VisionSensor.New(
		agentData,
		agentData.id,
		agentData.controller:GetModel(),
		agentConfig.VisionDistance,
		visionDependencies
	)

	return setmetatable(agentData, Agent)
end

return Agent
