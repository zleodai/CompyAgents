--[=[
	Config

	Central runtime tuning module for the server-side agent simulation. It keeps
	queue budgets, update cadences, grid settings, combat constants, and adapter
	mode selection in one place.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local cadenceMult = 1
local maxJobsMult = 1
local maxMsMult = 1

local cooldownMult = 1

local Config: Types.Config = {
	SimulationMode = "Grid",

	Debug = {
		Enabled = true,
		ShowAgentLabels = true,
	},

	AgentBootstrap = {
		Enabled = true,
		DemoAgentsPerTeam = 10,
		TargetAgentsPerTeam = 20,
	},

	Cadence = {
		PlanningScanInterval = 0.25 * cadenceMult,
		PathingScanInterval = 0.25 * cadenceMult,
		PerceptionInterval = 0.5 * cadenceMult,
		BlackboardCleanupInterval = 1 * cadenceMult,
		VisualizationInterval = 0.01 * cadenceMult,
		CombatInterval = 0.25 * cadenceMult,
	},

	Queues = {
		Planning = {
			MaxJobsPerFrame = 4 * maxJobsMult,
			MaxMsPerFrame = 2.0 * maxMsMult,
		},
		Pathing = {
			MaxJobsPerFrame = 4 * maxJobsMult,
			MaxMsPerFrame = 1.5 * maxMsMult,
		},
		Perception = {
			MaxJobsPerFrame = 8 * maxJobsMult,
			MaxMsPerFrame = 1.5 * maxMsMult,
		},
		Blackboard = {
			MaxJobsPerFrame = 2 * maxJobsMult,
			MaxMsPerFrame = 0.5 * maxMsMult,
		},
	},

	GOAP = {
		MaxExpansions = 128,
		MaxPlanDepth = 6,
		ReplanCooldown = 0.75 * cooldownMult,
		FailedPlanCooldown = 1.25 * cooldownMult,
	},

	Grid = {
		Width = 30,
		Height = 20,
		CellSize = 6,
		Origin = Vector3.new(0, 0, 0),
	},

	Sensor = {
		Range = 72,
		FieldOfViewDegrees = 140,
	},

	Movement = {
		Speed = 18,
		WaypointTolerance = 0.35,
	},

	Pathing = {
		RepathCooldown = 0.50,
	},

	Combat = {
		Range = 60,
		DamagePerTick = 6,
	},

	Visualization = {
		FolderName = "CompyAgentVisualization",
		AgentSize = Vector3.new(2.5, 2.5, 2.5),
		VerticalOffset = Vector3.new(0, 1.25, 0),
		LerpAlpha = 0.35,
	},

	Teams = {
		Blue = {
			Color = Color3.fromRGB(55, 125, 255),
			SpawnOrigin = Vector3.new(-20, 0, 0),
			SpawnSpacing = 12,
			Forward = Vector3.new(1, 0, 0),
		},
		Red = {
			Color = Color3.fromRGB(235, 70, 70),
			SpawnOrigin = Vector3.new(20, 0, 0),
			SpawnSpacing = 12,
			Forward = Vector3.new(-1, 0, 0),
		},
	},
}

return Config
