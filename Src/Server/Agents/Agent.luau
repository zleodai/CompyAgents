--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Types = require(CompyServerScripts.Core.Types)
local Util = require(CompyServerScripts.Core.Util)

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

	controller: SPHController.SPHController,
	vision: VisionSensor.VisionSensor,
	inventory: InventoryModule.Inventory,
	planner: PlannerModule.Planner,

	heartBeat: RBXScriptConnection?,
	visionElapsed: number,
	plannerElapsed: number,

	alive: boolean,
}

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

	local action = self.planner.action

	return {
		lowHealth = lowHealth,
		inDanger = enemyVisible and lowHealth,

		objectiveCaptured = false,
		hasObjectivePos = #self.sightedObjectiveLocs > 0,

		hasAmmo = ammo > 0,

		standing = standing,
		crouched = crouched,
		proned = proned,

		hasEnemyPos = enemyVisible,
		enemyEngaged = action ~= nil and action.id == "EngageEnemy",
	}
end

function Agent.Update(self: Agent, dt: number): ()
	if not self.alive then
		return
	end

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
	if self.alive then
		return
	end
	self.alive = true

	self.planner:Awake(self.controller)

	self.heartBeat = RunService.Heartbeat:Connect(function(dt: number): ()
		Agent.Update(self, dt)
	end)
end

function Agent.End(self: Agent): ()
	if not self.alive then
		return
	end

	self.alive = false

	if self.heartBeat then
		self.heartBeat:Disconnect()
		self.heartBeat = nil
	end

	local model = self.controller:GetHumanoid().Parent

	self.planner:ForceStop(getSharedData(self))
	self.controller:Destroy()

	-- Hide BaseParts
	task.defer(function()
		task.wait(0.75)
		if not model then
			return
		end
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				local bodyPart = child :: BasePart
				bodyPart.CanCollide = false
				bodyPart.CanQuery = false
				bodyPart.CanTouch = false
			end
		end
	end)
end

function Agent.DebugDump(self: Agent): string
	local log = ""

	log = log .. `time: {os.clock()}\n`
	log = log .. `goal: {Util.StringifyTable(self.planner.goal)}\n`
	log = log .. `action: {Util.StringifyTable(self.planner.action)}\n`
	log = log .. `beliefs: {Util.StringifyTable(self.planner.beliefs)}\n`
	log = log .. `agentData: {Util.StringifyTable(self.planner.agentData)}\n`
	log = log .. `planIndx: {Util.StringifyTable(self.planner.planIndx)}\n`
	log = log .. `planSuccess: {Util.StringifyTable(self.planner.planSuccess)}\n`
	log = log .. `needsReplan: {Util.StringifyTable(self.planner.needsReplan)}\n`
	log = log .. `replanReason: {Util.StringifyTable(self.planner.replanReason)}\n`
	log = log .. `lastFailedPlanAt: {Util.StringifyTable(self.planner.lastFailedPlanAt)}\n`
	log = log .. `failedPlanCooldown: {Util.StringifyTable(self.planner.failedPlanCooldown)}\n`
	log = log .. `plan: {Util.StringifyTable(self.planner.plan)}\n`
	log = log .. `controller: {Util.StringifyTable(self.controller)}\n`

	return log
end

export type Agent = typeof(setmetatable({} :: AgentData, Agent))

function Agent.new(
	id: number,
	teamId: Team.Id,
	controller: SPHController.SPHController,
	agentConfig: typeof(_DefaultAgentConfig),
	cadenceConfig: typeof(_DefaultCadenceConfig),
	agentService: any
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

		controller = controller,
		vision = VisionSensor.Blank,
		inventory = InventoryModule.New(agentConfig.InitialMagazines),
		planner = PlannerModule.new(),

		heartBeat = nil,
		visionElapsed = cadenceConfig.VisionInterval,
		plannerElapsed = cadenceConfig.PlannerInterval,

		alive = false,
	}

	agentData.vision = VisionSensor.New(agentData, agentData.id, agentData.controller:GetModel(), agentConfig.VisionDistance, agentService)

	return setmetatable(agentData, Agent)
end

return Agent
