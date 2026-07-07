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

	Tests = {
		Enabled = false,
		Verbose = true,
		FailFast = false,
	},

	AgentModel = {
		Enabled = true,
		FolderName = "CompyAgentModels",
		RootPartSize = Vector3.new(2, 2, 1),
		HeadSize = Vector3.new(1.2, 1.2, 1.2),
		HeadOffset = Vector3.new(0, 2.5, 0),
		HipHeight = 2,
		WalkSpeed = 18,
		DebugTransparency = 0.35,
	},

	AgentBootstrap = {
		Enabled = true,
		DemoAgentsPerTeam = 10,
		TargetAgentsPerTeam = 20,
	},

	Level = {
		UseStudioLevel = true,
		UseConfigSpawnsFallback = true,
		SpawnTag = "CompySpawn",
		CoverTag = "CompyCover",
		ObjectiveTag = "CompyObjective",
		HumanoidTag = "CompyHumanoid",
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
		EyeOffset = Vector3.new(0, 2.5, 0),
	},

	Movement = {
		Speed = 18,
		WaypointTolerance = 0.35,
		FacingTurnRateRadiansPerSecond = math.rad(360),
	},

	Pathing = {
		RepathCooldown = 0.50,
	},

	NoobPath = {
		Enabled = true,
		Precise = true,
		Timeout = true,
		Visualize = true,
		AgentParams = {
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 4,
			Costs = {},
			PathSettings = {
				SupportPartialPath = true,
			},
		},
	},

	Combat = {
		Range = 60,
		DamagePerTick = 6,
		RequiredAimDot = 0.96,
	},

	Visualization = {
		FolderName = "CompyAgentVisualization",
		AgentSize = Vector3.new(2.5, 2.5, 2.5),
		VerticalOffset = Vector3.new(0, 1.25, 0),
		LerpAlpha = 0.35,
		DestinationMarkerSize = Vector3.new(1.5, 0.35, 1.5),
		DestinationMarkerOffset = Vector3.new(0, 0.2, 0),
		DestinationLineThickness = 0.18,
		DestinationLineColor = Color3.fromRGB(255, 221, 87),
		DestinationLineTransparency = 0.25,
		ShootingLineThickness = 0.28,
		ShootingLineLength = 18,
		ShootingLineColor = Color3.fromRGB(255, 255, 255),
		ShootingLineTransparency = 0,
		ShotFlashDuration = 0.18,
		FacingArrowOffset = Vector3.new(0, 1, 0),
		FacingArrowLength = 2,
		FacingArrowShaftThickness = 1,
		FacingArrowColor = Color3.fromRGB(0, 0, 0),
		FacingArrowTransparency = 0.05,
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
