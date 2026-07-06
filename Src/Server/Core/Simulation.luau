--[=[
	Simulation

	Owns the data-first server simulation. It creates agent stores, team
	blackboards, swappable adapters, budget queues, and systems, then advances
	them from a single Step call.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)
local BudgetQueue = require(CompyServerScripts.Core.BudgetQueue)
local Config = require(CompyServerScripts.Core.Config)
local Scheduler = require(CompyServerScripts.Core.Scheduler)

local AgentState = require(CompyServerScripts.Agents.AgentState)
local AgentStore = require(CompyServerScripts.Agents.AgentStore)

local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)

local PlanExecutor = require(CompyServerScripts.GOAP.PlanExecutor)

local PerceptionSystem = require(CompyServerScripts.Systems.PerceptionSystem)
local PlanningSystem = require(CompyServerScripts.Systems.PlanningSystem)
local PathSystem = require(CompyServerScripts.Systems.PathSystem)
local CombatSystem = require(CompyServerScripts.Systems.CombatSystem)
local BlackboardSystem = require(CompyServerScripts.Systems.BlackboardSystem)
local MovementSystem = require(CompyServerScripts.Systems.MovementSystem)
local VisualizationSystem = require(CompyServerScripts.Systems.VisualizationSystem)

local GridSensor = require(CompyServerScripts.Adapters.Sensors.GridSensor)
local RaycastSensor = require(CompyServerScripts.Adapters.Sensors.RaycastSensor)
local GridMovement = require(CompyServerScripts.Adapters.Movement.GridMovement)
local PathfindingMovement = require(CompyServerScripts.Adapters.Movement.PathfindingMovement)
local GridPathfinder = require(CompyServerScripts.Adapters.Pathing.GridPathfinder)
local RobloxPathfinder = require(CompyServerScripts.Adapters.Pathing.RobloxPathfinder)
local GridWorldQuery = require(CompyServerScripts.Adapters.World.GridWorldQuery)
local SpatialWorldQuery = require(CompyServerScripts.Adapters.World.SpatialWorldQuery)

local RemoteEvents = ReplicatedStorage.RemoteEvents
local DebugPlaybackToggled = RemoteEvents.DebugPlaybackToggled
local DebugSpeedDecreased = RemoteEvents.DebugSpeedDecreased
local DebugSpeedIncreased = RemoteEvents.DebugSpeedIncreased
local DebugAverageFrameMS = RemoteEvents.DebugAverageFrameMS

local Simulation = {}
Simulation.__index = Simulation

local function createAdapters(): Types.Adapters
	if Config.SimulationMode == "Grid" then
		return {
			sensor = GridSensor.new(Config),
			movementDriver = GridMovement.new(Config),
			pathProvider = GridPathfinder.new(Config),
			worldQuery = GridWorldQuery.new(Config),
		}
	end

	return {
		sensor = RaycastSensor.new(Config),
		movementDriver = PathfindingMovement.new(Config),
		pathProvider = RobloxPathfinder.new(Config),
		worldQuery = SpatialWorldQuery.new(Config),
	}
end

function Simulation.new(): Types.Simulation
	local self = setmetatable({}, Simulation)

	self.config = Config
	self.now = 0
	self.started = false
	self.agentStore = AgentStore.new()
	self.blackboards = {}

	for teamId in pairs(Config.Teams) do
		self.blackboards[teamId] = BlackboardStore.new(teamId)
	end

	self.adapters = createAdapters()
	self.scheduler = Scheduler.new()
	self.queues = {
		Perception = BudgetQueue.new("Perception", Config.Queues.Perception),
		Planning = BudgetQueue.new("Planning", Config.Queues.Planning),
		Pathing = BudgetQueue.new("Pathing", Config.Queues.Pathing),
		Blackboard = BudgetQueue.new("Blackboard", Config.Queues.Blackboard),
	}

	self.scheduler:RegisterQueue("Perception", self.queues.Perception)
	self.scheduler:RegisterQueue("Planning", self.queues.Planning)
	self.scheduler:RegisterQueue("Pathing", self.queues.Pathing)
	self.scheduler:RegisterQueue("Blackboard", self.queues.Blackboard)

	local deps: Types.SystemDependencies = {
		config = Config,
		agentStore = self.agentStore,
		blackboards = self.blackboards,
		adapters = self.adapters,
		queues = self.queues,
	}
	self.systemDependencies = deps

	self.systems = {
		perception = PerceptionSystem.new(deps),
		planning = PlanningSystem.new(deps),
		pathing = PathSystem.new(deps),
		combat = CombatSystem.new(deps),
		blackboard = BlackboardSystem.new(deps),
		movement = MovementSystem.new(deps),
		visualization = VisualizationSystem.new(deps),
	}

	self:_registerCadence()

	if Config.AgentBootstrap.Enabled then
		self:_spawnDemoAgents(Config.AgentBootstrap.DemoAgentsPerTeam)
	end

	return self
end

function Simulation:_registerCadence(): ()
	self.scheduler:Every(
		"PerceptionScan",
		Config.Cadence.PerceptionInterval,
		function(context: Types.SimulationContext): ()
			self.systems.perception:Scan(context.now)
		end,
		true
	)

	self.scheduler:Every(
		"PlanningScan",
		Config.Cadence.PlanningScanInterval,
		function(context: Types.SimulationContext): ()
			self.systems.planning:Scan(context.now)
		end,
		true
	)

	self.scheduler:Every(
		"PathingScan",
		Config.Cadence.PathingScanInterval,
		function(context: Types.SimulationContext): ()
			self.systems.pathing:Scan(context.now)
		end,
		true
	)

	self.scheduler:Every(
		"BlackboardCleanup",
		Config.Cadence.BlackboardCleanupInterval,
		function(context: Types.SimulationContext): ()
			self.systems.blackboard:EnqueueCleanup(context.now)
		end,
		true
	)
end

function Simulation:_spawnDemoAgents(count: number): ()
	for teamId, teamConfig in pairs(Config.Teams) do
		for index = 1, count do
			local sideOffset = (index - ((count + 1) / 2)) * teamConfig.SpawnSpacing
			local position = teamConfig.SpawnOrigin + Vector3.new(0, 0, sideOffset)
			local agent = AgentState.create(("%s_%02d"):format(teamId, index), teamId, position, teamConfig.Forward)
			self.agentStore:Add(agent)
		end
	end
end

function Simulation:Start(): ()
	self.started = true
	self.systems.visualization:Initialize()
end

local paused = false
local playbackSpeed = 1
local frameTimeMSTotal = 0
local framesPassed = 0

function Simulation:Step(dt: number): ()
	if not self.started then
		return
	end

	if paused then
		return
	end

	frameTimeMSTotal += dt
	framesPassed += 1

	self.now = self.now + dt * playbackSpeed

	local context: Types.SimulationContext = {
		dt = dt,
		now = self.now,
	}

	PlanExecutor.StepAll(self.systemDependencies, dt, self.now)
	self.scheduler:Step(context)
	self.systems.movement:Step(dt, self.now)
	self.systems.combat:Step(dt, self.now)
	self.systems.visualization:Step(dt, self.now)
end

DebugPlaybackToggled.OnServerEvent:Connect(function(_)
	paused = not paused
end)

DebugSpeedDecreased.OnServerEvent:Connect(function(_)
	playbackSpeed *= 0.5

	if playbackSpeed < 0.0625 then
		playbackSpeed = 0.0625
	end
end)

DebugSpeedIncreased.OnServerEvent:Connect(function(_)
	playbackSpeed *= 2

	if playbackSpeed > 16 then
		playbackSpeed = 16
	end
end)

DebugAverageFrameMS.OnServerInvoke = function(_)
	return frameTimeMSTotal / framesPassed * 1000
end

return Simulation
