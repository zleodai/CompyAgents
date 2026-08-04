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
local SoundSensor = require(CompyServerScripts.Agents.Sensors.SoundSensor)
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

	agentSharedData: Types.AgentSharedData,

	controller: SPHController.SPHController,
	vision: VisionSensor.VisionSensor,
	hearing: SoundSensor.SoundSensor,
	inventory: InventoryModule.Inventory,
	planner: PlannerModule.Planner,

	heartBeat: RBXScriptConnection?,
	sensorElapsed: number,
	plannerElapsed: number,

	alive: boolean,
}

local function requestReplan(self: Agent, reason: string): ()
	self.planner:Replan(reason)
end

local function constructBeliefs(self: Agent): { [string]: boolean }
	local stance = self.controller:GetStance()
	local health = self.controller:GetHumanoid().Health
	local ammo, _ = self.controller:GetAmmo()
	local action = self.planner.action

	return {
		lowHealth = health <= 35,

		objectiveCaptured = false,
		hasObjectivePos = #self.agentSharedData.sightedObjectiveLocs > 0,

		hasAmmo = ammo > 0,

		standing = stance == "Standing",
		crouched = stance == "Crouching",
		proned = stance == "Proning",

		heardEnemyFiring = #self.agentSharedData.heardFireSounds > 0,
		hasEnemyPos = #self.agentSharedData.sightedEnemyLocs > 0,
		enemyEngaged = action ~= nil and action.id == "EngageEnemy",
	}
end

function Agent.Update(self: Agent, dt: number): ()
	if not self.alive then
		return
	end

	self.sensorElapsed += dt
	if self.sensorElapsed >= self.cadenceConfig.SensorInterval then
		self.sensorElapsed = 0
		self.vision:Sense()
		self.hearing:Sense()
	end

	local health = self.controller:GetHumanoid().Health
	if health <= 0 then
		Agent.End(self)
		return
	end

	self.plannerElapsed += dt
	if self.plannerElapsed >= self.cadenceConfig.PlannerInterval then
		local beliefs = constructBeliefs(self)

		local plannerDelta = self.plannerElapsed
		self.plannerElapsed = 0
		self.planner:Update(beliefs, self.agentSharedData, plannerDelta)
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

	self.planner:ForceStop(self.agentSharedData)
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
	local agentData: AgentData = {
		id = id,
		teamId = teamId,

		agentConfig = agentConfig,
		cadenceConfig = cadenceConfig,

		agentSharedData = {
			teamId = teamId,
			head = controller:GetHeadPart(),
			noisyEnemyDirection = Vector3.zero,
			noisyObjectiveDirection = Vector3.zero,
			sightedEnemyLocs = {},
			sightedObjectiveLocs = {},
			sightedCrouchCoverLocs = {},
			sightedProneCoverLocs = {},
			heardFireSounds = {},
			RequestReplan = function(_: string) end,
		} :: Types.AgentSharedData,

		controller = controller,
		vision = VisionSensor.Blank,
		hearing = SoundSensor.Blank,
		inventory = InventoryModule.New(agentConfig.InitialMagazines),
		planner = PlannerModule.new(),

		heartBeat = nil,
		sensorElapsed = cadenceConfig.SensorInterval,
		plannerElapsed = cadenceConfig.PlannerInterval,

		alive = false,
	}

	agentData.vision = VisionSensor.New(agentData.agentSharedData :: Types.AgentSharedData, agentConfig, agentData.id, controller:GetModel(), agentService)

	agentData.hearing = SoundSensor.New(agentData.agentSharedData, agentData.agentConfig)

	local agent = setmetatable(agentData, Agent) :: Agent

	agentData.agentSharedData.RequestReplan = function(reason: string)
		requestReplan(agent, reason)
	end

	return agent
end

return Agent
