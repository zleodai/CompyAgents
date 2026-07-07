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
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
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
local NoobPathMovement = require(CompyServerScripts.Adapters.Movement.NoobPathMovement)
local PathfindingMovement = require(CompyServerScripts.Adapters.Movement.PathfindingMovement)
local GridPathfinder = require(CompyServerScripts.Adapters.Pathing.GridPathfinder)
local NoopPathfinder = require(CompyServerScripts.Adapters.Pathing.NoopPathfinder)
local RobloxPathfinder = require(CompyServerScripts.Adapters.Pathing.RobloxPathfinder)
local GridWorldQuery = require(CompyServerScripts.Adapters.World.GridWorldQuery)
local SpatialWorldQuery = require(CompyServerScripts.Adapters.World.SpatialWorldQuery)
local StudioWorldRegistry = require(CompyServerScripts.Adapters.World.StudioWorldRegistry)

local RemoteEvents = ReplicatedStorage.RemoteEvents
local DebugPlaybackToggled = RemoteEvents.DebugPlaybackToggled
local DebugSpeedDecreased = RemoteEvents.DebugSpeedDecreased
local DebugSpeedIncreased = RemoteEvents.DebugSpeedIncreased
local DebugAverageFrameMS = RemoteEvents.DebugAverageFrameMS

local Simulation = {}
Simulation.__index = Simulation

local TWO_PI = math.pi * 2

local function usesNoobPathSpatialMode(): boolean
	return Config.SimulationMode == "Spatial" and Config.NoobPath.Enabled
end

local function createAdapters(agentModelStore: Types.AgentModelStore): Types.Adapters
	if Config.SimulationMode == "Grid" then
		return {
			sensor = GridSensor.new(Config),
			movementDriver = GridMovement.new(Config),
			pathProvider = GridPathfinder.new(Config),
			worldQuery = GridWorldQuery.new(Config),
		}
	end

	if Config.NoobPath.Enabled then
		return {
			sensor = RaycastSensor.new(Config, agentModelStore),
			movementDriver = NoobPathMovement.new(Config, agentModelStore),
			pathProvider = NoopPathfinder.new(Config),
			worldQuery = SpatialWorldQuery.new(Config),
		}
	end

	return {
		sensor = RaycastSensor.new(Config, agentModelStore),
		movementDriver = PathfindingMovement.new(Config),
		pathProvider = RobloxPathfinder.new(Config),
		worldQuery = SpatialWorldQuery.new(Config),
	}
end

local function resolveStudioSpawnPosition(spawnPoint: Types.StudioSpawnPoint): Vector3
	local spawnRadius = spawnPoint.spawnRadius

	if spawnRadius <= 0 then
		return spawnPoint.position
	end

	local angle = math.random() * TWO_PI
	local distance = math.sqrt(math.random()) * spawnRadius
	local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

	return spawnPoint.position + offset
end

function Simulation.new(): Types.Simulation
	local self = setmetatable({}, Simulation)

	self.config = Config
	self.now = 0
	self.started = false
	self.agentStore = AgentStore.new()
	self.blackboards = {}
	self.studioWorldRegistry = StudioWorldRegistry.new(Config)
	self.agentModelStore = AgentModelStore.new(Config, self.studioWorldRegistry)

	for teamId in pairs(Config.Teams) do
		self.blackboards[teamId] = BlackboardStore.new(teamId)
	end

	self.adapters = createAdapters(self.agentModelStore)
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
		agentModelStore = self.agentModelStore,
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

	if not usesNoobPathSpatialMode() then
		self.scheduler:Every(
			"PathingScan",
			Config.Cadence.PathingScanInterval,
			function(context: Types.SimulationContext): ()
				self.systems.pathing:Scan(context.now)
			end,
			true
		)
	end

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
	if Config.Level.UseStudioLevel then
		local spawnedFromStudio = self:_spawnDemoAgentsFromStudio(count)

		if spawnedFromStudio then
			return
		end

		if not Config.Level.UseConfigSpawnsFallback then
			warn("[CompyAgent:Simulation] No valid Studio spawn points found and config spawn fallback is disabled")
			return
		end

		warn("[CompyAgent:Simulation] No valid Studio spawn points found; using config spawn fallback")
	end

	for teamId, teamConfig in pairs(Config.Teams) do
		for index = 1, count do
			local sideOffset = (index - ((count + 1) / 2)) * teamConfig.SpawnSpacing
			local position = teamConfig.SpawnOrigin + Vector3.new(0, 0, sideOffset)
			local agent = AgentState.create(("%s_%02d"):format(teamId, index), teamId, position, teamConfig.Forward)
			self.agentStore:Add(agent)
			self.agentModelStore:CreateForAgent(agent, CFrame.lookAt(position, position + teamConfig.Forward))
		end
	end
end

function Simulation:_spawnDemoAgentsFromStudio(count: number): boolean
	self.studioWorldRegistry:Refresh()

	local spawnsByTeam: { [Types.TeamId]: { Types.StudioSpawnPoint } } = {}
	local totalAvailable = 0

	for teamId in pairs(Config.Teams) do
		local spawnPoints = self.studioWorldRegistry:GetSpawnPoints(teamId)
		spawnsByTeam[teamId] = spawnPoints
		totalAvailable += #spawnPoints
	end

	if totalAvailable == 0 then
		return false
	end

	for teamId, spawnPoints in pairs(spawnsByTeam) do
		if #spawnPoints == 0 then
			warn(
				("[CompyAgent:Simulation] No Studio spawn points available for team %s; spawning 0 agents"):format(
					teamId
				)
			)
			continue
		end

		for index = 1, count do
			local spawnPointIndex = ((index - 1) % #spawnPoints) + 1
			local spawnPoint = spawnPoints[spawnPointIndex]
			local position = resolveStudioSpawnPosition(spawnPoint)
			local agent = AgentState.create(("%s_%02d"):format(teamId, index), teamId, position, spawnPoint.facing)
			self.agentStore:Add(agent)
			self.agentModelStore:CreateForAgent(agent, CFrame.lookAt(position, position + spawnPoint.facing))
		end
	end

	return true
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
