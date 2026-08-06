--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local BraveryModifier = require(ServerScriptService.CompyAgent.Agents.Modifiers.BraveryModifier)
local CoverSensor = require(CompyServerScripts.Agents.Sensors.CoverSensor)
local MemoryModifier = require(CompyServerScripts.Agents.Modifiers.MemoryModifier)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)
local Types = require(CompyServerScripts.Core.Types)
local Util = require(CompyServerScripts.Core.Util)

local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local VisionSensor = require(CompyServerScripts.Agents.Sensors.VisionSensor)
local SoundSensor = require(CompyServerScripts.Agents.Sensors.SoundSensor)
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
	coverSensor: CoverSensor.CoverSensor,

	memory: MemoryModifier.MemoryModifier,
	bravery: BraveryModifier.BraveryModifier,

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
	local ammo, _ = self.controller:GetAmmo()

	return {
		brave = self.agentSharedData.bravery > self.agentConfig.MinimumBraveryForBrave,

		hasAmmo = ammo > 0,

		inCover = self.agentSharedData.inCover,
		coverAvailable = #self.agentSharedData.sightedCoverLocs > 0,
		coverInvalid = self.agentSharedData.cover == nil,

		heardEnemyFiring = next(self.agentSharedData.heardFireSounds) ~= nil,
		knowsEnemyPos = next(self.agentSharedData.rememberedEnemyLocs) ~= nil or #self.agentSharedData.sightedEnemyLocs > 0,
		hasEnemyPos = #self.agentSharedData.sightedEnemyLocs > 0,
	}
end

function Agent.Update(self: Agent, dt: number): ()
	if not self.alive then
		return
	end

	local health = self.controller:GetHumanoid().Health
	if health <= 0 then
		Agent.End(self)
		return
	end
	self.agentSharedData.health = health

	self.sensorElapsed += dt
	if self.sensorElapsed >= self.cadenceConfig.SensorInterval then
		self.sensorElapsed = 0

		self.vision:Sense()
		self.hearing:Sense()
		self.coverSensor:Sense()

		self.memory:Modify()
		self.bravery:Modify()
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

	local model = self.controller:GetModel()

	if self.agentSharedData.cover then
		EnvironmentService:SetCoverTakenStatus(self.agentSharedData.cover, model.Name, false)
	end

	self.planner:ForceStop(self.agentSharedData)
	self.controller:Destroy()

	-- Hide BaseParts
	-- task.defer(function()
	-- 	task.wait(0.75)
	-- 	for _, child in ipairs(model:GetChildren()) do
	-- 		if child:IsA("BasePart") then
	-- 			local bodyPart = child :: BasePart
	-- 			bodyPart.CanCollide = false
	-- 			bodyPart.CanQuery = false
	-- 			bodyPart.CanTouch = false
	-- 		end
	-- 	end
	-- end)
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
			name = controller:GetModel().Name,
			teamId = teamId,
			head = controller:GetHeadPart(),

			health = controller:GetHumanoid().Health,
			bravery = 0,

			noisyEnemyDirection = Vector3.zero,
			noisyObjectiveDirection = Vector3.zero,

			sightedEnemyLocs = {},
			sightedObjectiveLocs = {},
			sightedCoverLocs = {},

			rememberedEnemyLocs = {},

			inCover = false,
			cover = nil,

			heardFireSounds = {},

			RequestReplan = function(_: string) end,
		} :: Types.AgentSharedData,

		controller = controller,

		vision = VisionSensor.Blank,
		hearing = SoundSensor.Blank,
		coverSensor = CoverSensor.Blank,

		memory = MemoryModifier.Blank,
		bravery = BraveryModifier.Blank,

		planner = PlannerModule.new(),

		heartBeat = nil,
		sensorElapsed = cadenceConfig.SensorInterval,
		plannerElapsed = cadenceConfig.PlannerInterval,

		alive = false,
	}

	agentData.vision = VisionSensor.New(agentData.agentSharedData :: Types.AgentSharedData, agentConfig, agentData.id, controller:GetModel(), agentService)
	agentData.hearing = SoundSensor.New(agentData.agentSharedData, agentData.agentConfig)
	agentData.coverSensor = CoverSensor.New(agentData.agentSharedData, agentData.agentConfig)

	agentData.memory = MemoryModifier.New(agentData.agentSharedData, agentData.agentConfig, agentService)
	agentData.bravery = BraveryModifier.New(agentData.agentSharedData, agentData.agentConfig)

	local agent = setmetatable(agentData, Agent) :: Agent

	agentData.agentSharedData.RequestReplan = function(reason: string)
		requestReplan(agent, reason)
	end

	return agent
end

return Agent
